import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from 'npm:@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
)

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  // CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const url = new URL(req.url)
    const slug = url.searchParams.get("slug")

    if (!slug) {
      return new Response(
        JSON.stringify({ error: "Missing slug" }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 1. Verificar que el formulario existe
    const { data: formulario, error: formError } = await supabase
      .from('formularios')
      .select('*')
      .eq('slug', slug)
      .single()

    if (formError || !formulario) {
      return new Response(
        JSON.stringify({ error: "Formulario no encontrado" }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 2. Obtener metadatos de las columnas usando RPC
    const { data: columns, error: colError } = await supabase
  .rpc('get_table_metadata', { p_table_name: slug })

      console.log("DEBUG - Columnas desde DB:", JSON.stringify(columns, null, 2));

    if (colError) {
      console.error('Error RPC:', colError)
      return new Response(
        JSON.stringify({ error: "Error obteniendo metadatos", details: colError.message }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (!columns || columns.length === 0) {
      return new Response(
        JSON.stringify({ error: `La tabla '${slug}' no tiene columnas` }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

   // 3. Formatear campos
const fields = columns.map((col: any) => {
  return {
    campo: col.column_name,
    tipo: col.data_type,
    requerido: col.is_nullable === 'NO',
    // Genera un label bonito, ej: "departamento_id" -> "Departamento"
    label: col.column_name
             .replace(/_id$/g, '') // Quita el _id del final para el label
             .replace(/_/g, ' ')
             .replace(/\b\w/g, (l: string) => l.toUpperCase()),
    foreign_table: col.foreign_table, 
    is_fk: !!col.foreign_table // Se convierte a booleano real
  };
});

    return new Response(
      JSON.stringify({ ok: true, formulario, fields }
      ),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error general:', error)
    return new Response(
      JSON.stringify({ error: "Error interno del servidor", details: (error as Error).message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
});
