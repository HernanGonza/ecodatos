-- =============================================================================
-- Migración: "tipo_de_acta" pasa de texto libre a tabla relacionada (select)
-- Fecha: 2026-08-27
--
-- QUÉ HACE:
--   1. Crea la tabla de catálogo public.tipo_acta_actuaciones (id, nombre, activo)
--      con los 3 tipos iniciales.
--   2. En public.actuaciones_control_guardaparques reemplaza la columna de texto
--      `tipo_de_acta` por `tipo_de_acta_id uuid` con FOREIGN KEY a la tabla nueva.
--      - Se llama `tipo_de_acta_id` (con sufijo _id) igual que el `actividad_id`
--        que ya existe en esta misma tabla. El formulario dinámico detecta la FK
--        por la constraint (get_table_metadata) y renderiza un <Select>; el label
--        se genera quitando el "_id" -> "Tipo De Acta".
--   3. Migra los datos existentes (si hubiera): matchea el texto contra el
--      catálogo; cualquier texto que no matchee se agrega como tipo nuevo para
--      no perder información. Después borra la columna de texto.
--
--   Reutiliza el mismo patrón que public.tipo_actividad_guardaparques /
--   actuaciones_control_guardaparques.actividad_id (mismas GRANT, sin RLS, igual
--   que el resto de las tablas de catálogo del sistema).
--
-- CÓMO CORRERLA:
--   Resguardo antes (pg_dump). Pegar y ejecutar completo en el SQL Editor de
--   Studio o vía psql. Va envuelto en BEGIN/COMMIT.
--
-- CÓMO DESHACERLA:
--   BEGIN;
--   ALTER TABLE public.actuaciones_control_guardaparques ADD COLUMN tipo_de_acta text;
--   UPDATE public.actuaciones_control_guardaparques a
--     SET tipo_de_acta = t.nombre
--     FROM public.tipo_acta_actuaciones t
--     WHERE a.tipo_de_acta_id = t.id;
--   ALTER TABLE public.actuaciones_control_guardaparques
--     DROP CONSTRAINT actuaciones_control_guardaparques_tipo_de_acta_id_fkey;
--   ALTER TABLE public.actuaciones_control_guardaparques DROP COLUMN tipo_de_acta_id;
--   DROP TABLE public.tipo_acta_actuaciones;
--   COMMIT;
--   NOTIFY pgrst, 'reload schema';
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Tabla de catálogo
-- ---------------------------------------------------------------------------
CREATE TABLE public.tipo_acta_actuaciones (
    id     uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre text NOT NULL,
    activo boolean DEFAULT true,
    CONSTRAINT tipo_acta_actuaciones_pkey PRIMARY KEY (id)
);

GRANT ALL ON TABLE public.tipo_acta_actuaciones TO anon;
GRANT ALL ON TABLE public.tipo_acta_actuaciones TO authenticated;
GRANT ALL ON TABLE public.tipo_acta_actuaciones TO service_role;

INSERT INTO public.tipo_acta_actuaciones (nombre) VALUES
  ('Infracción'),
  ('Inspección / Constatación'),
  ('Constatación');

-- ---------------------------------------------------------------------------
-- 2. Columna FK nueva
-- ---------------------------------------------------------------------------
ALTER TABLE public.actuaciones_control_guardaparques
  ADD COLUMN tipo_de_acta_id uuid;

-- ---------------------------------------------------------------------------
-- 3. Migración de datos existentes (no-op si la tabla está vacía)
-- ---------------------------------------------------------------------------

-- 3a. Match directo contra el catálogo (case/espacios-insensible).
UPDATE public.actuaciones_control_guardaparques a
SET tipo_de_acta_id = t.id
FROM public.tipo_acta_actuaciones t
WHERE a.tipo_de_acta IS NOT NULL
  AND lower(btrim(a.tipo_de_acta)) = lower(btrim(t.nombre));

-- 3b. Textos que no matchearon: se agregan como tipos nuevos (no perder datos).
INSERT INTO public.tipo_acta_actuaciones (nombre)
SELECT DISTINCT btrim(a.tipo_de_acta)
FROM public.actuaciones_control_guardaparques a
WHERE a.tipo_de_acta_id IS NULL
  AND a.tipo_de_acta IS NOT NULL
  AND btrim(a.tipo_de_acta) <> ''
  AND NOT EXISTS (
    SELECT 1 FROM public.tipo_acta_actuaciones t
    WHERE lower(btrim(t.nombre)) = lower(btrim(a.tipo_de_acta))
  );

-- 3c. Segundo match para vincular los recién creados.
UPDATE public.actuaciones_control_guardaparques a
SET tipo_de_acta_id = t.id
FROM public.tipo_acta_actuaciones t
WHERE a.tipo_de_acta_id IS NULL
  AND a.tipo_de_acta IS NOT NULL
  AND lower(btrim(a.tipo_de_acta)) = lower(btrim(t.nombre));

-- ---------------------------------------------------------------------------
-- 4. FOREIGN KEY + baja de la columna de texto
-- ---------------------------------------------------------------------------
ALTER TABLE public.actuaciones_control_guardaparques
  ADD CONSTRAINT actuaciones_control_guardaparques_tipo_de_acta_id_fkey
  FOREIGN KEY (tipo_de_acta_id)
  REFERENCES public.tipo_acta_actuaciones(id)
  ON DELETE SET NULL;

ALTER TABLE public.actuaciones_control_guardaparques
  DROP COLUMN tipo_de_acta;

COMMIT;

-- ---------------------------------------------------------------------------
-- 5. Refrescar el cache de PostgREST para que la API exponga ya la tabla
--    nueva y la nueva relación (correr fuera de la transacción).
--    Si por lo que sea no toma, reiniciar el contenedor `rest`.
-- ---------------------------------------------------------------------------
NOTIFY pgrst, 'reload schema';

-- =============================================================================
-- VERIFICACIÓN:
--   select * from public.tipo_acta_actuaciones order by nombre;
--   select column_name, data_type from information_schema.columns
--     where table_name = 'actuaciones_control_guardaparques'
--       and column_name like 'tipo_de_acta%';
--   -- get_table_metadata debe devolver foreign_table para tipo_de_acta_id:
--   select * from public.get_table_metadata('actuaciones_control_guardaparques')
--     where column_name = 'tipo_de_acta_id';
-- =============================================================================
