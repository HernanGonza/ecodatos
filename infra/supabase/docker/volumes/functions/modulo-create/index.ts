import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "npm:@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const sanitizarNombreSql = (nombre: string) => {
  return nombre
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/\s+/g, '_')
    .replace(/[^\w]+/g, '');
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  console.log(">>> [INICIO] Petición recibida en modulo-create");

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const body = await req.json();
    const { 
      nombre_tabla, 
      descripcion, 
      area_id, 
      nuevo_nombre_area, 
      campos_adicionales 
    } = body;

    let finalAreaId = area_id;

    // 1. Manejo de Área
    if (nuevo_nombre_area && !finalAreaId) {
      const derivedKey = sanitizarNombreSql(nuevo_nombre_area);
      const { data: nuevaArea, error: areaError } = await supabase
        .from('areas')
        .insert([{ 
          nombre: nuevo_nombre_area, 
          key: derivedKey,
          activo: true 
        }])
        .select('id')
        .single();

      if (areaError) throw new Error(`Error al crear área: ${areaError.message}`);
      finalAreaId = nuevaArea.id;
    }

    // 2. Crear registro en formularios
    const { data: formulario, error: formError } = await supabase
      .from('formularios')
      .insert([
        { 
          nombre: descripcion || nombre_tabla, 
          slug: sanitizarNombreSql(nombre_tabla), 
          area_id: finalAreaId, 
          activo: true 
        }
      ])
      .select('id')
      .single();

    if (formError) throw new Error(`Error en tabla formularios: ${formError.message}`);
    const nuevoFormularioId = formulario.id;

    // 3. Preparar SQL - MEJORADO: numeric para todo lo numérico
    const sqlCamposDinamicos = (campos_adicionales || [])
      .filter((c: any) => c.nombre && c.nombre.trim() !== "")
      .map((c: any) => {
        const nombreLimpio = sanitizarNombreSql(c.nombre);
        // Si el tipo es 'integer' o 'numeric', forzamos 'numeric' para evitar líos con NATS
        const tipoValido = ["numeric", "integer"].includes(c.tipo) 
          ? "numeric" 
          : ["date", "boolean", "timestamp"].includes(c.tipo) 
            ? c.tipo 
            : "text";
        return `"${nombreLimpio}" ${tipoValido}`;
      })
      .join(',\n        ');

    // 4. Query Final con Policy Híbrida (Admin/Superadmin + Area)
    const sqlQuery = `
      CREATE TABLE IF NOT EXISTS public."${nombre_tabla}" (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        created_at timestamptz DEFAULT now(),
        updated_at timestamptz DEFAULT now(),
        created_by uuid REFERENCES auth.users(id) DEFAULT auth.uid(),
        user_id uuid REFERENCES auth.users(id) DEFAULT auth.uid(),
        formulario_id uuid REFERENCES public.formularios(id) DEFAULT '${nuevoFormularioId}',
        activo boolean DEFAULT true,

        departamento_id uuid REFERENCES public.departamentos(id),
        municipio_id uuid REFERENCES public.municipios(id), 
        
        latitud_decimal numeric,
        longitud_decimal numeric,
        latitud_gms text,
        longitud_gms text,
        geom geometry(Point, 4326),

        ${sqlCamposDinamicos ? sqlCamposDinamicos : '-- sin campos extras'}
      );

      ALTER TABLE public."${nombre_tabla}" ENABLE ROW LEVEL SECURITY;

      DROP POLICY IF EXISTS "policy_area_access_${nombre_tabla}" ON public."${nombre_tabla}";
      
      CREATE POLICY "policy_area_access_${nombre_tabla}" ON public."${nombre_tabla}"
      FOR ALL TO authenticated
      USING (
        -- Condición 1: Si es Admin o Superadmin entra directo
        EXISTS (
          SELECT 1 FROM public.usuarios_rol ur
          JOIN public.roles r ON ur.rol_id = r.id
          WHERE ur.user_id = auth.uid() 
            AND r.key IN ('admin', 'superadmin')
            AND ur.activo = true
        )
        OR 
        -- Condición 2: Si es usuario común, chequeamos el área del formulario
        public.check_user_in_area('${finalAreaId}')
      );

      -- Grants para asegurar acceso
      GRANT ALL ON public."${nombre_tabla}" TO service_role;
      GRANT SELECT, INSERT, UPDATE, DELETE ON public."${nombre_tabla}" TO authenticated;
    `;

    const { error: sqlError } = await supabase.rpc('exec_sql', { sql_query: sqlQuery });

    if (sqlError) {
      await supabase.from('formularios').delete().eq('id', nuevoFormularioId);
      throw new Error(`Error de SQL: ${sqlError.message}`);
    }

    return new Response(JSON.stringify({ success: true, tabla: nombre_tabla }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    });
  }
});
