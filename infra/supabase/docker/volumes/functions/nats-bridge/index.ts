import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { publishEvent } from "../main/common/nats.ts"

serve(async (req) => {
  try {
    const payload = await req.json()
    
    // El payload de un webhook de Supabase suele traer:
    // type (INSERT/UPDATE/DELETE), table, schema, record (datos nuevos)
    const { type, table, record, old_record } = payload
    
    // Definimos el subject basado en el slug (nombre de la tabla)
    // Ejemplo: forms.events.caza_furtiva
    const subject = `forms.events.${table}`
    
    const eventData = {
      action: type,
      data: type === 'DELETE' ? old_record : record,
      timestamp: new Date().toISOString()
    }

    await publishEvent(subject, eventData)

    return new Response(JSON.stringify({ ok: true }), { 
      headers: { "Content-Type": "application/json" } 
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }
})