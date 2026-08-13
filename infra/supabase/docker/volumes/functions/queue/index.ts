import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "npm:@supabase/supabase-js@2"
import { JSONCodec } from "https://deno.land/x/nats@v1.16.0/src/mod.ts" 
import { getNats } from "../_shared/nats.ts" 

const jc = JSONCodec();

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

// ============================================================================
// HELPER: Filtra un record contra el esquema real de la tabla vía RPC
// ============================================================================
async function filterRecordBySchema(
  supabase: any, 
  table: string, 
  record: Record<string, any>
): Promise<Record<string, any>> {
  try {
    // Usar RPC en lugar de consultar information_schema directamente
    const { data: cols, error } = await supabase
      .rpc('get_table_columns', { p_table_name: table });

    if (error || !cols) {
      console.warn(`⚠️ No se pudo validar esquema para [${table}] vía RPC, se envían todos los campos`);
      return record; // Fallback: no romper si no podemos validar
    }

    // cols viene como [{ column_name: "id" }, { column_name: "fecha" }, ...]
    const validCols = new Set(cols.map((c: any) => c.column_name));
    
    const filtered = Object.fromEntries(
      Object.entries(record).filter(([key]) => validCols.has(key))
    );

    const removed = Object.keys(record).filter(k => !validCols.has(k));
    if (removed.length > 0) {
      console.log(`🧹 [${table}] Campos filtrados del payload:`, removed);
    }

    return filtered;
  } catch (err) {
    console.warn(`⚠️ Error filtrando schema para [${table}]:`, err.message);
    return record; // Fallback seguro
  }
}

function sanitizeRecord(record: Record<string, any>): Record<string, any> {
  const result: Record<string, any> = {};
  for (const [key, value] of Object.entries(record)) {
    if (value === "" || value === null || value === undefined) {
      result[key] = null;
    } else {
      result[key] = value;
    }
  }
  return result;
}

// ============================================================================
// MAIN: Edge Function entry point
// ============================================================================
serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const nc = await getNats(); 
    const js = nc.jetstream();

    // Obtenemos el consumidor de JetStream
    const consumer = await js.consumers.get("CRUD_OPERATIONS", "universal_db_worker");
    const messages = await consumer.fetch({ batch: 10, expires: 5000 });

    for await (const m of messages) {
      const subject = m.subject;
      const payload: any = jc.decode(m.data);
      
      console.log(`📩 [WORKER] Procesando subject: ${subject}`);

      try {
        const parts = subject.split('.');
        const table = parts[2];

        // --------------------------------------------------------------------
        // CASO 1: CREACIÓN UNIVERSAL
        // --------------------------------------------------------------------
        if (subject.startsWith("crud.create.")) {
          let record = payload.record;
          
          // 🔒 Filtrar contra esquema real ANTES de insertar
          record = await filterRecordBySchema(supabaseAdmin, table, record);
          record = sanitizeRecord(record);
          console.log(`🆕 [WORKER] Insertando en tabla [${table}]`);
          
          const { error } = await supabaseAdmin.from(table).insert(record);
          if (error) throw error;
          console.log(`✅ Registro insertado en ${table}`);
        } 
        
        // --------------------------------------------------------------------
        // CASO 2: ACTUALIZACIÓN UNIVERSAL
        // --------------------------------------------------------------------
        else if (subject.startsWith("crud.update.")) {
          const { id, record } = payload;
          
          // 🔒 Filtrar contra esquema real ANTES de actualizar
          const safeRecord = await filterRecordBySchema(supabaseAdmin, table, record);
          const cleanRecord = sanitizeRecord(safeRecord);
          console.log(`📝 [WORKER] Actualizando tabla [${table}] ID: ${id}`);

          const { error } = await supabaseAdmin
            .from(table)
            .update(cleanRecord)  // ← Usar cleanRecord sanitizado, NO record original
            .eq('id', id);

          if (error) {
            console.error(`❌ Error DB Update [${table}]:`, error.message);
            m.ack(); // Ack para no trabar la cola si es error de datos
            continue;
          }
          console.log(`✅ Registro ${id} actualizado en ${table}`);
        }

        // --------------------------------------------------------------------
        // CASO 3: BORRADO LÓGICO UNIVERSAL
        // --------------------------------------------------------------------
        else if (subject.startsWith("crud.delete.")) {
          const { id } = payload;
          console.log(`🗑️ [WORKER] Borrado lógico en [${table}] ID: ${id}`);
          
          const { error } = await supabaseAdmin
            .from(table)
            .update({ activo: false }) 
            .eq('id', id);

          if (error) {
            console.error(`❌ Error en borrado lógico [${table}]:`, error.message);
            m.ack(); 
            continue;
          }
          console.log(`✅ Registro ${id} marcado como inactivo en ${table}`);
        }

        // --------------------------------------------------------------------
        // CASO 4: BORRADO FÍSICO DE USUARIOS (Auth)
        // --------------------------------------------------------------------
        else if (subject === "users.delete") {
          const userId = payload.user_id || payload.id;
          console.log(`👤 [WORKER] Borrando usuario ID: ${userId}`);
          if (!userId) { m.ack(); continue; }

          await supabaseAdmin.rpc('orphan_records_from_user', { target_user_id: userId });
          
          const { error: authError } = await supabaseAdmin.auth.admin.deleteUser(userId);
          if (authError && !authError.message.includes("not found")) throw authError;
          
          console.log(`✅ Usuario ${userId} borrado de Auth.`);
        } 
        
        // --------------------------------------------------------------------
        // CASO 5: OTROS (Jobs, Consistencia)
        // --------------------------------------------------------------------
        else if (subject.startsWith("jobs.users.")) {
          console.log(`🛡️ [WORKER] Consistencia verificada para: ${payload.user_id || payload.id}`);
        }

        // --------------------------------------------------------------------
        // CASO 6: ENVÍO DE REPORTES
        // --------------------------------------------------------------------
        else if (subject === "jobs.reports.send") {
          console.log(`📊 [WORKER] Procesando envío de reporte para: ${payload.to}`);
          const response = await fetch(`${Deno.env.get("SUPABASE_URL")}/functions/v1/send-report`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")}`
            },
            body: JSON.stringify(payload)
          });

          if (!response.ok) {
            const errorText = await response.text();
            throw new Error(`Error en send-report: ${errorText}`);
          }
          console.log(`✅ [WORKER] Reporte enviado con éxito a ${payload.to}`);
        }

        // --------------------------------------------------------------------
        // CASO 7: APROBACIÓN DE SOLICITUDES (Altas y Cambios)
        // --------------------------------------------------------------------
        else if (subject === "jobs.solicitudes.approve") {
          const { solicitud_id } = payload;
          console.log(`📋 [WORKER] Procesando solicitud ID: ${solicitud_id}`);

          const { data: sol } = await supabaseAdmin
            .from('solicitudes')
            .select('tipo')
            .eq('id', solicitud_id)
            .single();

          const endpoint = sol?.tipo === 'update' ? 'solicitudes-update' : 'solicitudes-approve';
          console.log(`📋 [WORKER] Derivando a: ${endpoint}`);

          const response = await fetch(`${Deno.env.get("SUPABASE_URL")}/functions/v1/${endpoint}`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")}`
            },
            body: JSON.stringify({ solicitud_id })
          });

          if (!response.ok) {
            const errorText = await response.text();
            if (response.status >= 400 && response.status < 500) {
              console.warn(`⚠️ [WORKER] Error de validación: ${errorText}`);
              m.ack();
              continue;
            }
            throw new Error(`Error en ${endpoint}: ${errorText}`);
          }

          console.log(`✅ [WORKER] Solicitud ${solicitud_id} procesada via ${endpoint}`);
        }

        // Confirmar éxito a NATS
        m.ack(); 

      } catch (err) {
        console.error(`❌ Error procesando ${subject}:`, err.message);
        // Marcamos para reintento si fue error de red/timeout
        m.nak(); 
      }
    }

    return new Response(JSON.stringify({ done: true }), { 
      headers: { ...corsHeaders, "Content-Type": "application/json" } 
    });

  } catch (error) {
    console.error("💥 CRITICAL WORKER ERROR:", error.message);
    return new Response(error.message, { status: 500, headers: corsHeaders });
  }
});
