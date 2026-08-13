import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { to, replyTo, subject, mensajePersonalizado, storageKey, filename, titulo, periodo } = await req.json();

    if (!to || !storageKey) {
      return new Response(
        JSON.stringify({ error: "Faltan campos: to, storageKey" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const senderName = Deno.env.get("SMTP_SENDER_NAME") ?? "Eco Datos SOT";

    const bloquesMensaje = mensajePersonalizado ? `
      <div style="background:#f0f9ff;border-left:4px solid #0891b2;padding:16px;margin:0 0 16px 0;border-radius:0 8px 8px 0;">
        <p style="margin:0 0 6px 0;font-size:12px;color:#0891b2;font-weight:600;text-transform:uppercase;">Mensaje del remitente</p>
        <p style="margin:0;color:#1e293b;white-space:pre-wrap;">${mensajePersonalizado}</p>
      </div>` : "";

    const htmlBody = `
<div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;">
  <div style="background:#0891b2;padding:24px;border-radius:8px 8px 0 0;">
    <h1 style="color:white;margin:0;font-size:20px;">📊 Reporte de Estadísticas</h1>
    <p style="color:#e0f7fa;margin:8px 0 0 0;font-size:14px;">${senderName}</p>
  </div>
  <div style="background:#f9fafb;padding:24px;border-radius:0 0 8px 8px;border:1px solid #e5e7eb;">
    ${bloquesMensaje}
    ${titulo ? `<p style="margin:0 0 8px 0;"><strong>Reporte:</strong> ${titulo}</p>` : ""}
    ${periodo ? `<p style="margin:0 0 16px 0;"><strong>Período:</strong> ${periodo}</p>` : ""}
    <p style="color:#6b7280;margin:0;">Se adjunta el reporte en formato PDF.</p>
    ${replyTo ? `<p style="color:#6b7280;margin:8px 0 0 0;font-size:12px;">Para responder, escribí a <a href="mailto:${replyTo}" style="color:#0891b2;">${replyTo}</a></p>` : ""}
    <hr style="border:none;border-top:1px solid #e5e7eb;margin:20px 0;" />
    <p style="color:#9ca3af;font-size:12px;margin:0;">Envío automático — Observatorio Ambiental.</p>
  </div>
</div>`;

    const textBody = [
      mensajePersonalizado ? `Mensaje: ${mensajePersonalizado}\n` : "",
      `Reporte: ${titulo || "Estadísticas"}`,
      `Período: ${periodo || "No especificado"}`,
      "PDF adjunto.",
    ].filter(Boolean).join("\n");

    // Fire and forget — respondemos de inmediato sin esperar al mailer
    fetch("http://supabase-mailer:3001/send", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        to,
        replyTo: replyTo ?? undefined,
        subject: subject ?? `Reporte - ${new Date().toLocaleDateString("es-AR")}`,
        html: htmlBody,
        text: textBody,
        filename: filename ?? `Reporte_${new Date().toISOString().slice(0, 10)}.pdf`,
        storageKey,
        titulo,
        periodo,
        mensajePersonalizado: mensajePersonalizado ?? null,
      }),
    }).catch(err => console.error("Mailer fetch error:", err));

    console.log(`📤 Enviado a mailer en background: ${to}`);
    return new Response(
      JSON.stringify({ ok: true, message: `Reporte en cola de envío para ${to}` }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("Error send-report:", error);
    return new Response(
      JSON.stringify({ error: "Error al enviar el email", details: (error as Error).message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});