import { createClient } from "npm:@supabase/supabase-js@2"
import { enqueue } from "../_shared/nats.ts"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders })

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    )
    
    const { id, nombre_completo, rol_id, areas, formularios } = await req.json()

    if (!id) throw new Error("ID de usuario es requerido");

    // 1. Actualizar Auth
    const { error: authError } = await supabase.auth.admin.updateUserById(id, {
      user_metadata: { full_name: nombre_completo },
    })
    if (authError) throw authError;

    // 2. Actualizar Rol
    const { error: roleError } = await supabase
      .from("usuarios_rol")
      .upsert({ user_id: id, rol_id }, { onConflict: "user_id" })
    if (roleError) throw roleError;

    // 3. Sincronizar Áreas
    // Primero borramos lo que existe
    await supabase.from("usuarios_areas").delete().eq("user_id", id)
    
    if (Array.isArray(areas) && areas.length > 0) {
      const areasInserts = areas.map((a: any) => {
        // Normalizamos la entrada: aceptamos string o {id, es_editor}
        const isObject = typeof a === 'object' && a !== null;
        return {
          user_id: id,
          area_id: isObject ? a.id : a,
          es_editor: isObject ? (a.es_editor ?? true) : true
        }
      })
      const { error: areaInsError } = await supabase.from("usuarios_areas").insert(areasInserts)
      if (areaInsError) throw areaInsError;
    }

    // 4. Sincronizar Formularios
    // Primero borramos lo que existe
    await supabase.from("usuarios_formularios").delete().eq("user_id", id)
    
    if (Array.isArray(formularios) && formularios.length > 0) {
      const formInserts = formularios.map((f: any) => {
        // Normalizamos la entrada
        const isObject = typeof f === 'object' && f !== null;
        return {
          user_id: id,
          formulario_id: isObject ? f.id : f,
          es_editor: isObject ? (f.es_editor ?? true) : true
        }
      })
      const { error: formInsError } = await supabase.from("usuarios_formularios").insert(formInserts)
      if (formInsError) throw formInsError;
    }

    // NATS Queue para procesos en segundo plano
    try {
      await enqueue("jobs.users.update", { user_id: id, at: new Date().toISOString() })
    } catch (natsErr) {
      console.error("NATS ERROR (No crítico):", natsErr.message)
    }

    return new Response(JSON.stringify({ ok: true }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })

  } catch (e) {
    console.error("USERS-UPDATE ERROR:", e.message)
    return new Response(JSON.stringify({ error: e.message }), { 
      status: 400, 
      headers: { ...corsHeaders, "Content-Type": "application/json" } 
    })
  }
})