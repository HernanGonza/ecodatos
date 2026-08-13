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
    const { email, password, nombre_completo, rol_id, areas, formularios } = await req.json()

    // 1. Crear usuario en Auth con metadata de control
    const { data: authUser, error: authError } = await supabaseAdmin.auth.admin.createUser({
      email,
      password: password || '12345678', // Password por defecto
      user_metadata: { 
        full_name: nombre_completo,
        // ESTA ES LA CLAVE: Forzamos el estado inicial del modal
        password_changed: false,
        needs_password_update: true 
      },
      email_confirm: true
    })

    if (authError) throw authError
    const userId = authUser.user.id

    // 2. Asignar ROL
    if (rol_id) {
      const { error: roleError } = await supabaseAdmin
        .from('usuarios_rol')
        .insert({ user_id: userId, rol_id })
      if (roleError) console.error("Error rol:", roleError)
    }

    // 3. Asignar ÁREAS
    if (areas && areas.length > 0) {
      const areasToInsert = areas.map((a: any) => ({
        user_id: userId,
        area_id: a.id,
        es_editor: a.es_editor
      }))
      const { error: areaError } = await supabaseAdmin.from('usuarios_areas').insert(areasToInsert)
      if (areaError) console.error("Error areas:", areaError)
    }

    // 4. Asignar FORMULARIOS
    if (formularios && formularios.length > 0) {
      const formsToInsert = formularios.map((f: any) => ({
        user_id: userId,
        formulario_id: f.id,
        es_editor: f.es_editor
      }))
      const { error: formError } = await supabaseAdmin.from('usuarios_formularios').insert(formsToInsert)
      if (formError) console.error("Error forms:", formError)
    }

    return new Response(JSON.stringify({ message: "Usuario creado con éxito", id: userId }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200
    })

  } catch (e) {
    return new Response(JSON.stringify({ error: e.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400
    })
  }
})