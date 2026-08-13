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

    // 1. Obtener la solicitud
    const { data: sol, error: solError } = await supabaseAdmin
      .from('solicitudes')
      .select('*')
      .eq('id', solicitud_id)
      .single()

    if (solError || !sol) throw new Error('Solicitud no encontrada')
    if (sol.creado) throw new Error('Esta solicitud ya fue aprobada previamente')
    if (sol.tipo === 'update') throw new Error('Esta edge solo procesa solicitudes de tipo registro — usá solicitudes-update')

    const parseData = (val: any) => {
      if (!val) return [];
      if (typeof val === 'string') {
        try { return JSON.parse(val); } catch { return []; }
      }
      return Array.isArray(val) ? val : [];
    };

    const areas = parseData(sol.areas);
    const formularios = parseData(sol.formularios);

    // 2. Crear usuario en Auth
    console.log(`🆕 [APPROVE] Creando nuevo usuario: ${sol.email}`)

    const { data: authUser, error: authError } = await supabaseAdmin.auth.admin.createUser({
      email: sol.email,
      password: '12345678',
      user_metadata: {
        full_name: sol.nombre_completo,
        password_changed: false,
        needs_password_update: true
      },
      email_confirm: true
    })

    if (authError) throw authError
    const userId = authUser.user.id

    // 3. Insertar rol
    if (sol.rol_id) {
      const { error } = await supabaseAdmin
        .from('usuarios_rol')
        .insert({ user_id: userId, rol_id: sol.rol_id })
      if (error) throw error
    }

    // 4. Insertar áreas
    if (areas.length > 0) {
      const { error } = await supabaseAdmin
        .from('usuarios_areas')
        .insert(areas.map((a: any) => ({ user_id: userId, area_id: a.id, es_editor: !!a.es_editor })))
      if (error) throw error
    }

    // 5. Insertar formularios
    if (formularios.length > 0) {
      const { error } = await supabaseAdmin
        .from('usuarios_formularios')
        .insert(formularios.map((f: any) => ({ user_id: userId, formulario_id: f.id, es_editor: !!f.es_editor })))
      if (error) throw error
    }

    // 6. Marcar solicitud como procesada
    const { error: updateError } = await supabaseAdmin
      .from('solicitudes')
      .update({ creado: true, user_id: userId, estado: 'aprobada' })
      .eq('id', solicitud_id)
    if (updateError) throw updateError

    // 7. Notificaciones — fire and forget
    const appUrl = Deno.env.get('APP_URL') ?? 'https://formularios.localhost'
    const senderName = Deno.env.get('SMTP_SENDER_NAME') ?? 'Eco Datos SOT'
    const mailerUrl = 'http://supabase-mailer:3001/send'

    // Mail al usuario nuevo con credenciales
    const htmlUsuario = `
<div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;">
  <div style="background:#0891b2;padding:24px;border-radius:8px 8px 0 0;">
    <h1 style="color:white;margin:0;font-size:20px;">👋 Bienvenido al Sistema</h1>
    <p style="color:#e0f7fa;margin:8px 0 0 0;font-size:14px;">${senderName}</p>
  </div>
  <div style="background:#f9fafb;padding:24px;border-radius:0 0 8px 8px;border:1px solid #e5e7eb;">
    <p style="margin:0 0 16px 0;">Hola <strong>${sol.nombre_completo}</strong>,</p>
    <p style="margin:0 0 16px 0;">Tu cuenta fue creada. Podés ingresar con las siguientes credenciales:</p>
    <div style="background:#f0f9ff;border-left:4px solid #0891b2;padding:16px;margin:0 0 16px 0;border-radius:0 8px 8px 0;">
      <p style="margin:0 0 8px 0;"><strong>Usuario:</strong> ${sol.email}</p>
      <p style="margin:0;"><strong>Contraseña provisoria:</strong> 12345678</p>
    </div>
    <p style="margin:0 0 16px 0;">Al ingresar por primera vez se te pedirá que cambies tu contraseña.</p>
    <a href="${appUrl}" style="display:inline-block;background:#0891b2;color:white;padding:12px 24px;border-radius:8px;text-decoration:none;font-weight:700;margin-bottom:16px;">
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
        subject: `👋 Bienvenido al sistema — tus credenciales de acceso`,
        html: htmlUsuario,
        text: `Hola ${sol.nombre_completo}, tu cuenta fue creada. Usuario: ${sol.email} / Contraseña provisoria: 12345678. Ingresá en: ${appUrl}`,
      }),
    }).catch(err => console.error('Mail usuario error:', err))

    // Mail al solicitante
    if (sol.solicitante_email) {
      const htmlSolicitante = `
<div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;">
  <div style="background:#0891b2;padding:24px;border-radius:8px 8px 0 0;">
    <h1 style="color:white;margin:0;font-size:20px;">✅ Solicitud Aprobada</h1>
    <p style="color:#e0f7fa;margin:8px 0 0 0;font-size:14px;">${senderName}</p>
  </div>
  <div style="background:#f9fafb;padding:24px;border-radius:0 0 8px 8px;border:1px solid #e5e7eb;">
    <p style="margin:0 0 16px 0;">Hola <strong>${sol.solicitante_nombre}</strong>,</p>
    <p style="margin:0 0 16px 0;">
      Tu solicitud de acceso para <strong>${sol.nombre_completo}</strong> (${sol.email}) fue
      <strong style="color:#059669;">aprobada y creada</strong> correctamente.
    </p>
    <p style="margin:0 0 8px 0;">El usuario ya puede ingresar al sistema con la contraseña provisoria y se le pedirá que la cambie en el primer acceso.</p>
    <hr style="border:none;border-top:1px solid #e5e7eb;margin:20px 0;" />
    <p style="color:#9ca3af;font-size:12px;margin:0;">Envío automático — Observatorio Ambiental.</p>
  </div>
</div>`

      fetch(mailerUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          to: sol.solicitante_email,
          subject: `✅ Solicitud aprobada: ${sol.nombre_completo}`,
          html: htmlSolicitante,
          text: `Tu solicitud para ${sol.nombre_completo} (${sol.email}) fue aprobada. El usuario ya puede ingresar al sistema.`,
        }),
      }).catch(err => console.error('Mail solicitante error:', err))
    }

    console.log(`✅ Usuario ${userId} creado desde solicitud ${solicitud_id}`)

    return new Response(JSON.stringify({ ok: true, userId }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200
    })

  } catch (e) {
    console.error("💥 ERROR EN SOLICITUDES-APPROVE:", (e as Error).message)
    return new Response(JSON.stringify({ error: (e as Error).message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400
    })
  }
})