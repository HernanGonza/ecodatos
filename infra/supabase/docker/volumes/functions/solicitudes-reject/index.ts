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
    const { solicitud_id, accion, motivo } = await req.json()
    if (!solicitud_id) throw new Error('Falta solicitud_id')
    if (!['rechazada', 'revision'].includes(accion)) throw new Error('Acción inválida — debe ser rechazada o revision')

    const { data: sol, error: solError } = await supabaseAdmin
      .from('solicitudes')
      .select('*')
      .eq('id', solicitud_id)
      .single()

    if (solError || !sol) throw new Error('Solicitud no encontrada')
    if (sol.creado) throw new Error('No se puede rechazar una solicitud ya aprobada')

    // Actualizar estado
    const { error: updateError } = await supabaseAdmin
      .from('solicitudes')
      .update({ estado: accion })
      .eq('id', solicitud_id)
    if (updateError) throw updateError

    console.log(`📋 [REJECT] Solicitud ${solicitud_id} marcada como: ${accion}`)

    // Notificar al solicitante
    if (sol.solicitante_email) {
      const appUrl = Deno.env.get('APP_URL') ?? 'https://formularios.localhost'
      const senderName = Deno.env.get('SMTP_SENDER_NAME') ?? 'Eco Datos SOT'
      const mailerUrl = 'http://supabase-mailer:3001/send'

      const esRechazo = accion === 'rechazada'

      const htmlSolicitante = `
<div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;">
  <div style="background:${esRechazo ? '#dc2626' : '#d97706'};padding:24px;border-radius:8px 8px 0 0;">
    <h1 style="color:white;margin:0;font-size:20px;">
      ${esRechazo ? '❌ Solicitud Rechazada' : '🔄 Solicitud Devuelta para Revisión'}
    </h1>
    <p style="color:${esRechazo ? '#fee2e2' : '#fef3c7'};margin:8px 0 0 0;font-size:14px;">${senderName}</p>
  </div>
  <div style="background:#f9fafb;padding:24px;border-radius:0 0 8px 8px;border:1px solid #e5e7eb;">
    <p style="margin:0 0 16px 0;">Hola <strong>${sol.solicitante_nombre}</strong>,</p>
    <p style="margin:0 0 16px 0;">
      Tu solicitud para el usuario <strong>${sol.nombre_completo}</strong> (${sol.email}) fue
      <strong style="color:${esRechazo ? '#dc2626' : '#d97706'};">
        ${esRechazo ? 'rechazada' : 'devuelta para revisión'}
      </strong>.
    </p>
    ${motivo ? `
    <div style="background:#f3f4f6;border-left:4px solid ${esRechazo ? '#dc2626' : '#d97706'};padding:16px;margin:0 0 16px 0;border-radius:0 8px 8px 0;">
      <p style="margin:0;font-size:14px;"><strong>Motivo:</strong> ${motivo}</p>
    </div>
    ` : ''}
    ${!esRechazo ? `
    <p style="margin:0 0 16px 0;">
      Podés ingresar al sistema, revisar tu solicitud y reenviarla con las correcciones indicadas.
    </p>
    <a href="${appUrl}" style="display:inline-block;background:#d97706;color:white;padding:12px 24px;border-radius:8px;text-decoration:none;font-weight:700;margin-bottom:16px;">
      REVISAR SOLICITUD
    </a>
    ` : ''}
    <hr style="border:none;border-top:1px solid #e5e7eb;margin:20px 0;" />
    <p style="color:#9ca3af;font-size:12px;margin:0;">Envío automático — Observatorio Ambiental.</p>
  </div>
</div>`

      fetch(mailerUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          to: sol.solicitante_email,
          subject: esRechazo
            ? `❌ Solicitud rechazada: ${sol.nombre_completo}`
            : `🔄 Solicitud devuelta para revisión: ${sol.nombre_completo}`,
          html: htmlSolicitante,
          text: `Tu solicitud para ${sol.nombre_completo} fue ${esRechazo ? 'rechazada' : 'devuelta para revisión'}.${motivo ? ` Motivo: ${motivo}` : ''}`,
        }),
      }).catch(err => console.error('Mail solicitante error:', err))
    }

    return new Response(JSON.stringify({ ok: true, estado: accion }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200
    })

  } catch (e) {
    console.error("💥 ERROR EN SOLICITUDES-REJECT:", (e as Error).message)
    return new Response(JSON.stringify({ error: (e as Error).message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400
    })
  }
})