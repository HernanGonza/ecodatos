const http = require('http');
const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST || 'smtp.gmail.com',
  port: parseInt(process.env.SMTP_PORT || '587'),
  secure: false,
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
  },
});

const SUPABASE_URL     = process.env.SUPABASE_URL || 'http://kong:8000';
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

async function downloadPdf(storageKey) {
  const url = `${SUPABASE_URL}/storage/v1/object/reportes/${storageKey}`;
  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${SERVICE_ROLE_KEY}` },
  });
  if (!res.ok) throw new Error(`Storage error ${res.status}: ${await res.text()}`);
  return Buffer.from(await res.arrayBuffer());
}

const server = http.createServer(async (req, res) => {
  // Manejo de CORS
  if (req.method === 'OPTIONS') {
    res.writeHead(200, { 
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'content-type, authorization' 
    });
    res.end();
    return;
  }

  if (req.method !== 'POST' || req.url !== '/send') {
    res.writeHead(404);
    res.end(JSON.stringify({ error: 'Not found' }));
    return;
  }

  let body = '';
  req.on('data', chunk => body += chunk);
  req.on('end', async () => {
    const timestamp = new Date().toISOString();
    try {
      const payload = JSON.parse(body);
      const { 
        to, 
        replyTo, 
        subject, 
        mensajePersonalizado, 
        filename, 
        storageKey, 
        titulo, 
        periodo,
        html, 
        text 
      } = payload;

      console.log(`\n🚀 [${timestamp}] NUEVA SOLICITUD RECIBIDA`);
      console.log(`   Destinatario: ${to}`);
      console.log(`   Asunto: ${subject}`);
      console.log(`   Adjunto (storageKey): ${storageKey || 'Ninguno'}`);

      if (!to) {
        console.error(`   ❌ ERROR: No se especificó destinatario (to)`);
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Falta campo obligatorio: to' }));
        return;
      }

      const t0 = Date.now();
      let attachments = [];

      // Lógica de Adjunto
      if (storageKey) {
        console.log(`   📥 Descargando PDF desde Storage: ${storageKey}...`);
        try {
          const pdfBuffer = await downloadPdf(storageKey);
          attachments.push({
            filename: filename || 'reporte.pdf',
            content: pdfBuffer,
            contentType: 'application/pdf',
          });
          console.log(`   ✅ PDF descargado con éxito (${pdfBuffer.length} bytes)`);
        } catch (downloadErr) {
          console.error(`   ❌ ERROR descargando PDF: ${downloadErr.message}`);
          throw downloadErr;
        }
      }

      const senderName = process.env.SMTP_SENDER_NAME || 'Eco Datos SOT';

      // Lógica de Cuerpo (HTML)
      let finalHtml = html;
      let finalText = text;

      if (!finalHtml) {
        console.log(`   📝 Generando HTML automático para reporte...`);
        const bloquesMensaje = mensajePersonalizado ? `
          <div style="background:#f0f9ff;border-left:4px solid #0891b2;padding:16px;margin:0 0 16px 0;border-radius:0 8px 8px 0;">
            <p style="margin:0 0 6px 0;font-size:12px;color:#0891b2;font-weight:600;text-transform:uppercase;">Mensaje del remitente</p>
            <p style="margin:0;color:#1e293b;white-space:pre-wrap;">${mensajePersonalizado}</p>
          </div>` : '';

        finalHtml = `
          <div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;">
            <div style="background:#0891b2;padding:24px;border-radius:8px 8px 0 0;">
              <h1 style="color:white;margin:0;font-size:20px;">📊 Reporte de Estadísticas</h1>
              <p style="color:#e0f7fa;margin:8px 0 0 0;font-size:14px;">${senderName}</p>
            </div>
            <div style="background:#f9fafb;padding:24px;border-radius:0 0 8px 8px;border:1px solid #e5e7eb;">
              ${bloquesMensaje}
              ${titulo ? `<p style="margin:0 0 8px 0;"><strong>Reporte:</strong> ${titulo}</p>` : ''}
              ${periodo ? `<p style="margin:0 0 16px 0;"><strong>Período:</strong> ${periodo}</p>` : ''}
              <p style="color:#6b7280;margin:0;">Se adjunta el reporte en formato PDF.</p>
              ${replyTo ? `<p style="color:#6b7280;margin:8px 0 0 0;font-size:12px;">Para responder, escribí a <a href="mailto:${replyTo}" style="color:#0891b2;">${replyTo}</a></p>` : ''}
              <hr style="border:none;border-top:1px solid #e5e7eb;margin:20px 0;" />
              <p style="color:#9ca3af;font-size:12px;margin:0;">Envío automático — Observatorio Ambiental.</p>
            </div>
          </div>`;
      } else {
        console.log(`   🛠️ Usando HTML pre-armado (Aprobación de acceso / externo)`);
      }

      if (!finalText) {
        finalText = [
          mensajePersonalizado ? `Mensaje: ${mensajePersonalizado}\n` : '',
          `Reporte: ${titulo || 'Estadísticas'}`,
          `Período: ${periodo || 'No especificado'}`,
          storageKey ? 'PDF adjunto.' : '',
        ].filter(Boolean).join('\n');
      }

      // Envío SMTP
      const t1 = Date.now();
      console.log(`   📨 Conectando con servidor SMTP...`);
      
      await transporter.sendMail({
        from: `"${senderName}" <${process.env.SMTP_USER}>`,
        to,
        replyTo: replyTo || undefined,
        subject: subject || 'Notificación del Sistema',
        text: finalText,
        html: finalHtml,
        attachments: attachments,
      });

      const totalTime = Date.now() - t0;
      console.log(`   ✅ EMAIL ENVIADO CON ÉXITO a ${to}`);
      console.log(`   ⏱️  Tiempo de procesamiento: ${totalTime}ms`);
      console.log(`--------------------------------------------------`);

      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ ok: true }));

    } catch (err) {
      console.error(`   ❌ ERROR CRÍTICO: ${err.message}`);
      console.log(`--------------------------------------------------`);
      res.writeHead(500, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: err.message }));
    }
  });
});

server.listen(3001, '0.0.0.0', () => {
  console.log('📬 [SYSTEM] Mailer service iniciado en puerto 3001');
  console.log('📬 [SYSTEM] Esperando solicitudes de envío...');
});