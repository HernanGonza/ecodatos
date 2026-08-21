import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  const supabaseAdmin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  )

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) throw new Error("No hay header de autorizacion");

    const jwt = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await supabaseAdmin.auth.getUser(jwt);
    if (authError || !user) throw new Error("Token invalido");

    const { data: roleData } = await supabaseAdmin
      .from("usuarios_rol")
      .select("roles(key)")
      .eq("user_id", user.id)
      .single();

    if (roleData?.roles?.key !== "superadmin") throw new Error("Forbidden");

    const { data: { users }, error: listError } = await supabaseAdmin.auth.admin.listUsers();
    if (listError) throw listError;

    // Traemos áreas y formularios con su estado de 'es_editor'
    const [resAreas, resForms, resRoles] = await Promise.all([
      supabaseAdmin.from("usuarios_areas").select("user_id, area_id, es_editor"),
      supabaseAdmin.from("usuarios_formularios").select("user_id, formulario_id, es_editor"),
      supabaseAdmin.from("usuarios_rol").select("user_id, rol_id, roles(nombre, key)")
    ]);

    const usersMap = users.map(u => {
      const userRole = resRoles.data?.find(r => r.user_id === u.id);
      
      return {
        id: u.id,
        email: u.email,
        nombre_completo: u.user_metadata?.full_name || "Sin nombre",
        rol: userRole?.roles?.nombre || "Sin rol",
        rol_id: userRole?.rol_id,
        rol_key: userRole?.roles?.key,
        // Devolvemos objetos completos para que el Front gestione Lector/Editor
        areas: resAreas.data?.filter(a => a.user_id === u.id).map(a => ({
          id: a.area_id,
          es_editor: a.es_editor
        })) || [],
        formularios: resForms.data?.filter(f => f.user_id === u.id).map(f => ({
          id: f.formulario_id,
          es_editor: f.es_editor
        })) || []
      };
    });

    return new Response(JSON.stringify(usersMap), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200
    });

  } catch (e) {
    return new Response(JSON.stringify({ error: e.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: e.message === "Forbidden" ? 403 : 401
    });
  }
})