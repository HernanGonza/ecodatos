import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  const authHeader = req.headers.get('Authorization')!
  const supabaseAdmin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )
  const supabaseUser = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } }
  )

  try {
    // 1. Verificar sesión
    const { data: { user } } = await supabaseUser.auth.getUser()
    if (!user) throw new Error('No autenticado')

    // 2. Verificar que es admin o adminArea
    const { data: rolData } = await supabaseAdmin
      .from('usuarios_rol')
      .select('roles!rol_id(key)')
      .eq('user_id', user.id)
      .single()

    const rolKey = (rolData?.roles as any)?.key
    if (!['admin', 'adminArea'].includes(rolKey)) {
      throw new Error('Sin permisos para enviar solicitudes')
    }

    // 3. Guardar o actualizar solicitud
    const { nombre_completo, email, rol_id, areas, formularios, tipo, user_id, solicitud_id } = await req.json()

    if (solicitud_id) {
      // Actualizar solicitud existente (corrección de revisión)
      console.log(`✏️ [CREATE] Actualizando solicitud en revisión: ${solicitud_id}`)

      const { data: existing } = await supabaseAdmin
        .from('solicitudes')
        .select('estado, solicitante_id')
        .eq('id', solicitud_id)
        .single()

      if (!existing) throw new Error('Solicitud no encontrada')
      if (existing.estado !== 'revision') throw new Error('Solo se pueden editar solicitudes en estado de revisión')
      if (existing.solicitante_id !== user.id) throw new Error('No podés editar una solicitud que no es tuya')

      const { error } = await supabaseAdmin
        .from('solicitudes')
        .update({
          nombre_completo,
          email,
          rol_id,
          areas,
          formularios,
          tipo: tipo || 'registro',
          user_id: user_id || null,
          estado: 'pendiente', // Vuelve a pendiente para que el superadmin la revise
          creado: false,
        })
        .eq('id', solicitud_id)

      if (error) throw error
      console.log(`✅ [CREATE] Solicitud ${solicitud_id} corregida y vuelta a pendiente`)

    } else {
      // Insertar nueva solicitud
      console.log(`🆕 [CREATE] Nueva solicitud para: ${email}`)

      const { error } = await supabaseAdmin
        .from('solicitudes')
        .insert({
          solicitante_id: user.id,
          solicitante_email: user.email,
          solicitante_nombre: user.user_metadata?.full_name || user.email,
          nombre_completo,
          email,
          rol_id,
          areas,
          formularios,
          tipo: tipo || 'registro',
          user_id: user_id || null,
          creado: false,
          estado: 'pendiente',
        })

      if (error) throw error
    }

    return new Response(JSON.stringify({ ok: true }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200
    })
  } catch (e) {
    console.error('💥 ERROR EN SOLICITUDES-CREATE:', (e as Error).message)
    return new Response(JSON.stringify({ error: (e as Error).message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400
    })
  }
})