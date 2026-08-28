import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "npm:@supabase/supabase-js"
import { getNats } from "../_shared/nats.ts"
import { StringCodec } from "https://deno.land/x/nats@v1.16.0/src/mod.ts";

const sc = StringCodec();
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const body = await req.json();
    const { t: tabla, data: record } = body;

    if (!tabla || !record) {
      throw new Error("Faltan datos: tabla o registro");
    }

    // --- AUTORIZACIÓN: sesión + permiso de edición sobre el formulario ---
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const authHeader = req.headers.get('Authorization');
    const { data: { user }, error: authError } = await supabaseAdmin.auth.getUser(authHeader?.replace("Bearer ", "")!);
    if (authError || !user) throw new Error("No autorizado");

    const { data: roleData } = await supabaseAdmin
      .from("usuarios_rol")
      .select(`roles!rol_id ( key )`)
      .eq("user_id", user.id)
      .maybeSingle();

    const userRole = (roleData as any)?.roles?.key?.toLowerCase() || "usuario";
    const isSuperAdmin = userRole === "superadmin" || userRole === "admin";

    if (!isSuperAdmin) {
      const { data: form } = await supabaseAdmin
        .from("formularios")
        .select("id")
        .eq("slug", tabla)
        .maybeSingle();

      if (!form) {
        throw new Error("No se encontró el formulario para esta tabla.");
      }

      const { data: permiso } = await supabaseAdmin
        .from("usuarios_formularios")
        .select("es_editor")
        .eq("user_id", user.id)
        .eq("formulario_id", form.id)
        .maybeSingle();

      if (!permiso || permiso.es_editor !== true) {
        throw new Error("Permiso denegado: no tenés acceso de edición sobre este formulario.");
      }
    }
    // --- FIN AUTORIZACIÓN ---

    console.log(`[CREATE] Intentando publicar en NATS para tabla: ${tabla}`);

    const nc = await getNats();
    const js = nc.jetstream();
    const subject = `crud.create.${tabla}`;
    
    // 1. Publicar con await total
    const pa = await js.publish(subject, sc.encode(JSON.stringify({ record })), { 
      msgID: crypto.randomUUID() 
    });
    
    // 2. IMPORTANTE: Forzar el vaciado del buffer de NATS
    await nc.flush();
    
    console.log(`🚀 [CREATE] Confirmado por NATS en subject: ${subject} (Secuencia: ${pa.seq})`);

    // --- DESPERTADOR ---
    const WORKER_URL = "http://kong:8000/functions/v1/queue"; 
    const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

    // No esperamos al despertador, lo lanzamos al aire
    fetch(WORKER_URL, {
        method: 'GET',
        headers: { 'Authorization': `Bearer ${SERVICE_ROLE}` }
    }).catch(() => {});

    return new Response(JSON.stringify({ ok: true, message: "Operación en cola" }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 202,
    });

  } catch (error) {
    console.error("🔥 [CREATE] Error:", error.message);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
})