import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "npm:@supabase/supabase-js"
import { enqueue } from "../_shared/nats.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const authHeader = req.headers.get('Authorization');
    const { data: { user }, error: authError } = await supabaseAdmin.auth.getUser(authHeader?.replace("Bearer ", "")!);
    if (authError || !user) throw new Error("No autorizado");

    const { t, id, ids, data } = await req.json();
    const targetIds = ids || [id];

    // 1. Obtener Rol (desde usuarios_rol)
    const { data: roleData } = await supabaseAdmin
      .from("usuarios_rol")
      .select(`roles!rol_id ( key )`)
      .eq("user_id", user.id)
      .maybeSingle();

    const userRole = (roleData as any)?.roles?.key?.toLowerCase() || "usuario";
    const isSuperAdmin = userRole === "superadmin" || userRole === "admin";

    // 2. Verificación de Seguridad
    if (!isSuperAdmin) {
      // 2a. Obtener Áreas vinculadas al usuario (desde la tabla usuarios_areas)
      const { data: areasVinculadas } = await supabaseAdmin
        .from("usuarios_areas")
        .select("area_id")
        .eq("user_id", user.id)
        .eq("activo", true);

      if (!areasVinculadas || areasVinculadas.length === 0) {
        throw new Error("Tu usuario no tiene áreas asignadas.");
      }

      // Creamos un Set de IDs de área para búsqueda rápida
      const userAreaIds = new Set(areasVinculadas.map(a => a.area_id));

      // 2b. Traer registros con el área de su formulario padre
      const { data: registros, error: fetchErr } = await supabaseAdmin
        .from(t)
        .select(`id, formularios!formulario_id ( area_id )`)
        .in("id", targetIds);

      if (fetchErr) throw fetchErr;

      for (const reg of registros || []) {
        const recordAreaId = (reg.formularios as any)?.area_id;

        // Validamos si el área del registro está entre las áreas del usuario
        if (!userAreaIds.has(recordAreaId)) {
          console.error(`PERMISO DENEGADO: El registro ${reg.id} pertenece al área ${recordAreaId}, pero tú tienes acceso a:`, Array.from(userAreaIds));
          throw new Error("Permiso denegado: El registro pertenece a un área fuera de tu jurisdicción.");
        }
      }
    }

    // 3. Encolar en NATS
    for (const targetId of targetIds) {
      // Inyectamos el user.id de quien opera en el registro que se va a guardar
      const updatedRecord = {
        ...data,
        user_id: user.id // Forzamos que el user_id sea el del editor actual
      };
      await enqueue(`crud.update.${t}`, {
        id: targetId,
        record: updatedRecord,
        metadata: {
          updated_by: user.id,
          updated_at: new Date().toISOString(),
          role_used: userRole
        }
      });
    }

    // Despertar worker
    fetch("http://kong:8000/functions/v1/queue", {
        method: 'GET',
        headers: { 'Authorization': `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}` }
    }).catch(() => {});

    return new Response(JSON.stringify({ ok: true }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 202,
    });

  } catch (error) {
    console.error("ERROR EN UPDATE:", error.message);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    });
  }
})