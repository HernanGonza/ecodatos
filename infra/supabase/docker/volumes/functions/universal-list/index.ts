import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "npm:@supabase/supabase-js"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const url = new URL(req.url);
    const tabla = url.searchParams.get('t'); 
    if (!tabla) throw new Error("Falta el parámetro 't' (tabla)");

    const isOrphans = url.searchParams.get('orphans') === 'true';

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    // ================================================================
    // SELECT DINÁMICO CON JOINS
    // ================================================================
    let selectFields = '*';

    // Siempre intentamos traer los nombres (ya que todas tus tablas los tienen)
    selectFields += `,municipio_id:municipios(nombre)`;
    selectFields += `,departamento_id:departamentos(nombre)`;
    
    // 🔧 JOIN CONDICIONAL PARA ACTIVIDAD SEGÚN LA TABLA
    if (tabla === 'actuaciones_control_guardaparques') {
      selectFields += `,actividad_id:tipo_actividad_guardaparques(nombre)`;
    } else if (tabla === 'expedientes_impacto_ambiental') {
      selectFields += `,tipo_actividad_id:tipo_actividad_impacto_ambiental(nombre)`;
    }

    let query = supabase
      .schema('public')
      .from(tabla)
      .select(selectFields)
      .eq('activo', true);

    if (isOrphans) {
      query = query.is('user_id', null);
    }

    const { data, error } = await query.order('created_at', { ascending: false });

    if (error) {
      console.error(`❌ Error en tabla [${tabla}]: ${error.message}`);
      return new Response(JSON.stringify([]), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      });
    }

    // ================================================================
    // FLATTENING MEJORADO + ELIMINACIÓN DE OBJETOS ANIDADOS
    // ================================================================
    const flattenedData = (data || []).map(row => {
      const newRow = { ...row };

      // --- Municipio ---
      if (row.municipio_id && typeof row.municipio_id === 'object' && row.municipio_id !== null) {
        newRow.municipio_nombre = row.municipio_id.nombre || null;
        delete newRow.municipio_id;
      } else {
        newRow.municipio_nombre = null;
      }

      // --- Departamento ---
      if (row.departamento_id && typeof row.departamento_id === 'object' && row.departamento_id !== null) {
        newRow.departamento_nombre = row.departamento_id.nombre || null;
        delete newRow.departamento_id;
      } else {
        newRow.departamento_nombre = null;
      }

      // 🔧 FLATTENING PARA ACTIVIDAD (actuaciones_control_guardaparques)
      if (row.actividad_id && typeof row.actividad_id === 'object' && row.actividad_id !== null) {
        newRow.actividad_nombre = row.actividad_id.nombre || null;
        delete newRow.actividad_id;
      }

      // 🔧 FLATTENING PARA TIPO_ACTIVIDAD (expedientes_impacto_ambiental)
      if (row.tipo_actividad_id && typeof row.tipo_actividad_id === 'object' && row.tipo_actividad_id !== null) {
        newRow.tipo_actividad_nombre = row.tipo_actividad_id.nombre || null;
        delete newRow.tipo_actividad_id;
      }

      return newRow;
    });

    return new Response(JSON.stringify(flattenedData), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (error) {
    console.error('Error en universal-list:', error);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    });
  }
})
