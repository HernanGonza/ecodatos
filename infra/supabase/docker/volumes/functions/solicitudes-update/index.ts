import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  const supabaseAdmin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  try {
    const { solicitud_id } = await req.json()
    if (!solicitud_id) throw new Error('Falta solicitud_id')

    console.log(`📋 [UPDATE] Iniciando procesamiento de solicitud: ${solicitud_id}`)

    // 1. Obtener la solicitud
    const { data: sol, error: solError } = await supabaseAdmin
      .from('solicitudes')
      .select('*')
      .eq('id', solicitud_id)
      .single()

    if (solError || !sol) throw new Error('Solicitud no encontrada')
    if (sol.creado) throw new Error('Esta solicitud ya fue procesada previamente')
    if (sol.tipo !== 'update') throw new Error('Esta edge solo procesa solicitudes de tipo update')
    if (!sol.user_id) throw new Error('Solicitud de update sin user_id — no se puede procesar')

    console.log(`📋 [UPDATE] Datos de solicitud:`, JSON.stringify({
      id: sol.id,
      tipo: sol.tipo,
      user_id: sol.user_id,
      email: sol.email,
      creado: sol.creado,
      rol_id: sol.rol_id,
      areas: sol.areas,
      formularios: sol.formularios
    }))

    const userId = sol.user_id

    const parseData = (val: any) => {
      if (!val) return [];
      if (typeof val === 'string') {
        try { return JSON.parse(val); } catch { return []; }
      }
      return Array.isArray(val) ? val : [];
    };

    const areas = parseData(sol.areas);
    const formularios = parseData(sol.formularios);

    console.log(`🔄 [UPDATE] Actualizando usuario: ${sol.email} (ID: ${userId})`)
    console.log(`🔄 [UPDATE] Areas a sincronizar: ${areas.length}`, JSON.stringify(areas))
    console.log(`🔄 [UPDATE] Formularios a sincronizar: ${formularios.length}`, JSON.stringify(formularios))

    // 2. Actualizar metadata en Auth
    const { error: authError } = await supabaseAdmin.auth.admin.updateUserById(userId, {
      user_metadata: { full_name: sol.nombre_completo },
    })
    if (authError) throw authError
    console.log(`✅ [UPDATE] Auth metadata actualizado`)

    // 3. Actualizar rol
    if (sol.rol_id) {
      const { error } = await supabaseAdmin
        .from('usuarios_rol')
        .upsert({ user_id: userId, rol_id: sol.rol_id }, { onConflict: 'user_id' })
      if (error) throw error
      console.log(`✅ [UPDATE] Rol actualizado: ${sol.rol_id}`)
    } else {
      console.log(`⚠️ [UPDATE] Sin rol_id, saltando actualización de rol`)
    }

    // 4. Sincronizar áreas — borrar y reinsertar
    const { error: delAreasError } = await supabaseAdmin
      .from('usuarios_areas')
      .delete()
      .eq('user_id', userId)
    if (delAreasError) throw delAreasError
    console.log(`✅ [UPDATE] Áreas anteriores eliminadas, reinsertando ${areas.length}`)

    if (areas.length > 0) {
      const { error } = await supabaseAdmin
        .from('usuarios_areas')
        .insert(areas.map((a: any) => ({ user_id: userId, area_id: a.id, es_editor: !!a.es_editor })))
      if (error) throw error
      console.log(`✅ [UPDATE] Áreas reinsertadas correctamente`)
    }

    // 5. Sincronizar formularios — borrar y reinsertar
    const { error: delFormsError } = await supabaseAdmin
      .from('usuarios_formularios')
      .delete()
      .eq('user_id', userId)
    if (delFormsError) throw delFormsError
    console.log(`✅ [UPDATE] Formularios anteriores eliminados, reinsertando ${formularios.length}`)

    if (formularios.length > 0) {
      const { error } = await supabaseAdmin
        .from('usuarios_formularios')
        .insert(formularios.map((f: any) => ({ user_id: userId, formulario_id: f.id, es_editor: !!f.es_editor })))
      if (error) throw error
      console.log(`✅ [UPDATE] Formularios reinsertados correctamente`)
    }

    // 6. Marcar solicitud como procesada
    const { error: updateError } = await supabaseAdmin
      .from('solicitudes')
      .update({ creado: true, estado: 'aprobada' })
      .eq('id', solicitud_id)
    if (updateError) throw updateError
    console.log(`✅ [UPDATE] Solicitud marcada como procesada`)

    // 7. Notificaciones — fire and forget
    const appUrl = Deno.env.get('APP_URL') ?? 'https://formularios.localhost'
    const senderName = Deno.env.get('SMTP_SENDER_NAME') ?? 'Eco Datos SOT'
    const mailerUrl = 'http://supabase-mailer:3001/send'

    const htmlUsuario = `
<div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;">
  <div style="background:#3b82f6;padding:24px;border-radius:8px 8px 0 0;">
    <h1 style="color:white;margin:0;font-size:20px;">🔐 Permisos Actualizados</h1>
    <p style="color:#dbeafe;margin:8px 0 0 0;font-size:14px;">${senderName}</p>
  </div>
  <div style="background:#f9fafb;padding:24px;border-radius:0 0 8px 8px;border:1px solid #e5e7eb;">
    <p style="margin:0 0 16px 0;">Hola <strong>${sol.nombre_completo}</strong>,</p>
    <p style="margin:0 0 16px 0;">
      Un administrador ha actualizado tus permisos de acceso en el sistema.
      Los nuevos permisos ya están activos.
    </p>
    <a href="${appUrl}" style="display:inline-block;background:#3b82f6;color:white;padding:12px 24px;border-radius:8px;text-decoration:none;font-weight:700;margin-bottom:16px;">
      INGRESAR AL SISTEMA
    </a>
    <hr style="border:none;border-top:1px solid #e5e7eb;margin:20px 0;" />
    <p style="color:#9ca3af;font-size:12px;margin:0;">Envío automático — Observatorio Ambiental.</p>
  </div>
</div>`

    fetch(mailerUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        to: sol.email,
        subject: `🔐 Tus permisos fueron actualizados — ${senderName}`,
        html: htmlUsuario,
        text: `Hola ${sol.nombre_completo}, tus permisos fueron actualizados. Ingresá en: ${appUrl}`,
      }),
    }).catch(err => console.error('Mail usuario error:', err))

    if (sol.solicitante_email) {
      const htmlSolicitante = `
<div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;">
  <div style="background:#0891b2;padding:24px;border-radius:8px 8px 0 0;">
    <h1 style="color:white;margin:0;font-size:20px;">✅ Solicitud Procesada</h1>
    <p style="color:#e0f7fa;margin:8px 0 0 0;font-size:14px;">${senderName}</p>
  </div>
  <div style="background:#f9fafb;padding:24px;border-radius:0 0 8px 8px;border:1px solid #e5e7eb;">
    <p style="margin:0 0 16px 0;">Hola <strong>${sol.solicitante_nombre}</strong>,</p>
    <p style="margin:0 0 16px 0;">
      Tu solicitud de cambio de permisos para <strong>${sol.nombre_completo}</strong> 
      (${sol.email}) fue <strong style="color:#059669;">procesada</strong> correctamente.
    </p>
    <p style="margin:0 0 8px 0;">Los nuevos permisos ya están activos.</p>
    <hr style="border:none;border-top:1px solid #e5e7eb;margin:20px 0;" />
    <p style="color:#9ca3af;font-size:12px;margin:0;">Envío automático — Observatorio Ambiental.</p>
  </div>
</div>`

      fetch(mailerUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          to: sol.solicitante_email,
          subject: `✅ Cambio de permisos procesado: ${sol.nombre_completo}`,
          html: htmlSolicitante,
          text: `Tu solicitud de cambio de permisos para ${sol.nombre_completo} (${sol.email}) fue procesada correctamente.`,
        }),
      }).catch(err => console.error('Mail solicitante error:', err))
    }

    console.log(`✅ [UPDATE] Proceso completo para usuario ${userId} desde solicitud ${solicitud_id}`)

    return new Response(JSON.stringify({ ok: true, userId }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200
    })

  } catch (e) {
    console.error("💥 ERROR EN SOLICITUDES-UPDATE:", (e as Error).message)
    return new Response(JSON.stringify({ error: (e as Error).message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400
    })
  }
})