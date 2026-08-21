import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "npm:@supabase/supabase-js"
import { getNats } from "../_shared/nats.ts"
import { JSONCodec } from "https://deno.land/x/nats@v1.16.0/src/mod.ts";

const jc = JSONCodec();
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders })

  try {
    const { id, ids } = await req.json()
    const targetIds = ids && Array.isArray(ids) ? ids : (id ? [id] : []);
    
    const authHeader = req.headers.get("Authorization")
    if (targetIds.length === 0 || !authHeader) throw new Error("IDs de usuario no proporcionados")

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    )

    // 1. Validar permisos de Admin
    const { data: { user: adminUser }, error: userError } = await supabaseAdmin.auth.getUser(authHeader.replace("Bearer ", ""))
    if (userError || !adminUser) throw new Error("No autorizado")

    const { data: roleData } = await supabaseAdmin
      .from("usuarios_rol")
      .select(`roles!rol_id ( key )`)
      .eq("user_id", adminUser.id)
      .maybeSingle()

    const userRole = (roleData as any)?.roles?.key?.toLowerCase() || ""
    if (userRole !== "superadmin" && userRole !== "admin") throw new Error("Permisos insuficientes")

    // 2. ENCOLAR EN NATS
    const nc = await getNats();
    const js = nc.jetstream();
    
    console.log(`[USERS-DELETE] Encolando borrado de ${targetIds.length} usuarios`);

    for (const userId of targetIds) {
      // Evitar que el admin se borre a sí mismo por error
      if (userId === adminUser.id) continue;

      await js.publish(`users.delete`, jc.encode({ user_id: userId, deleted_by: adminUser.id }), { 
        msgID: crypto.randomUUID() 
      });
    }

    await nc.flush();

    // 3. Despertar al worker
    fetch("http://kong:8000/functions/v1/queue", {
        headers: { 'Authorization': `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}` }
    }).catch(() => {});

    return new Response(JSON.stringify({ ok: true, message: "Proceso de eliminación iniciado" }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 202
    })
  } catch (e) {
    return new Response(JSON.stringify({ error: e.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400
    })
  }
})