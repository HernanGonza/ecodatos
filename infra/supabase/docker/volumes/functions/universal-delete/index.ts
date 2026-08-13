import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "npm:@supabase/supabase-js"
import { getNats } from "../_shared/nats.ts"
import { StringCodec } from "https://deno.land/x/nats@v1.16.0/src/mod.ts";

const sc = StringCodec();
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders })

  try {
    const body = await req.json();
    const { id, ids, tabla } = body;
    
    // Normalizamos: si viene 'id' lo metemos en un array, si viene 'ids' usamos ese.
    const targetIds = ids && Array.isArray(ids) ? ids : (id ? [id] : []);
    
    const authHeader = req.headers.get("Authorization");
    if (targetIds.length === 0 || !tabla || !authHeader) {
      throw new Error("Faltan parámetros: se requiere id o ids, y el nombre de la tabla.");
    }

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // 1. Validar sesión del usuario
    const { data: { user }, error: userError } = await supabaseAdmin.auth.getUser(authHeader.replace("Bearer ", ""));
    if (userError || !user) throw new Error("No autenticado");

    // 2. PUBLICAR EN NATS
    const nc = await getNats();
    const js = nc.jetstream();
    const subject = `crud.delete.${tabla}`;
    
    console.log(`[DELETE] Encolando ${targetIds.length} registros para la tabla ${tabla}`);

    for (const targetId of targetIds) {
      const payload = { id: targetId, deleted_by: user.id };
      await js.publish(subject, sc.encode(JSON.stringify(payload)), { 
        msgID: crypto.randomUUID() // Evita duplicados en NATS
      });
    }
    
    await nc.flush();

    // 3. DESPERTAR AL WORKER (Marcapasos)
    const WORKER_URL = "http://kong:8000/functions/v1/queue"; 
    fetch(WORKER_URL, {
        method: 'GET',
        headers: { 'Authorization': `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}` }
    }).catch(() => {});

    return new Response(JSON.stringify({ 
      ok: true, 
      message: targetIds.length > 1 ? "Eliminación masiva en cola" : "Eliminación en cola" 
    }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 202,
    });

  } catch (error) {
    console.error("🔥 [DELETE ERROR]:", error.message);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 500,
    });
  }
})