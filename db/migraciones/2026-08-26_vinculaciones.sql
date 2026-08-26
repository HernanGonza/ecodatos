-- =============================================================================
-- Migración: Vinculación de registros entre módulos/áreas
-- Fecha: 2026-08-26
--
-- QUÉ HACE: agrega la capacidad de vincular (muchos a muchos) un registro de
-- cualquier tabla dinámica del sistema con un registro de cualquier otra tabla
-- dinámica (por ejemplo, un registro de "atropellamiento_fauna_silvestre" con
-- uno de "actuaciones_control_guardaparques").
--
-- ES 100% ADITIVO:
--   - No hace ALTER de ninguna tabla existente.
--   - No reemplaza ni borra ninguna función/policy existente.
--   - Solo CREA objetos nuevos: 1 tabla, 3 funciones, 1 trigger, 4 policies.
--   - Reutiliza (sin tocar) las funciones existentes public.check_is_admin()
--     y public.check_user_in_area(uuid), y las tablas existentes
--     public.formularios / public.areas.
--
-- CÓMO CORRERLA:
--   Recomendado: hacer un pg_dump de resguardo antes (aunque es aditiva).
--   Pegar y ejecutar este archivo completo en el SQL Editor de Supabase Studio,
--   o vía psql contra la base. Está envuelto en BEGIN/COMMIT: si algo falla,
--   no queda nada a medio aplicar.
--
-- CÓMO DESHACERLA (si hiciera falta):
--   BEGIN;
--   DROP TABLE IF EXISTS public.vinculaciones CASCADE;
--   DROP FUNCTION IF EXISTS public.listar_vinculaciones(text, uuid);
--   DROP FUNCTION IF EXISTS public.usuario_puede_ver_tabla(text);
--   DROP FUNCTION IF EXISTS public.area_de_tabla(text);
--   DROP FUNCTION IF EXISTS public.validar_vinculacion();
--   COMMIT;
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. Funciones de soporte (nuevas, no colisionan con nada existente)
-- -----------------------------------------------------------------------------

-- Resuelve el área a la que pertenece un módulo, a partir de su slug.
CREATE FUNCTION public.area_de_tabla(p_slug text) RETURNS uuid
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
  SELECT area_id FROM public.formularios WHERE slug = p_slug LIMIT 1;
$$;

-- "¿Puede este usuario ver (al menos en modo lectura) este módulo?"
-- Reutiliza check_is_admin() y check_user_in_area() ya existentes.
CREATE FUNCTION public.usuario_puede_ver_tabla(p_slug text) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
  SELECT public.check_is_admin() OR public.check_user_in_area(public.area_de_tabla(p_slug));
$$;

-- -----------------------------------------------------------------------------
-- 2. Tabla puente de vinculaciones
-- -----------------------------------------------------------------------------

CREATE TABLE public.vinculaciones (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tabla_origen text NOT NULL,
    registro_origen_id uuid NOT NULL,
    tabla_destino text NOT NULL,
    registro_destino_id uuid NOT NULL,
    tipo_relacion text,
    nota text,
    created_by uuid NOT NULL REFERENCES auth.users(id) DEFAULT auth.uid(),
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT vinculaciones_unicas UNIQUE (tabla_origen, registro_origen_id, tabla_destino, registro_destino_id)
);

COMMENT ON TABLE public.vinculaciones IS 'Vínculos manuales muchos-a-muchos entre registros de distintos módulos/áreas.';

CREATE INDEX vinculaciones_origen_idx ON public.vinculaciones (tabla_origen, registro_origen_id);
CREATE INDEX vinculaciones_destino_idx ON public.vinculaciones (tabla_destino, registro_destino_id);

ALTER TABLE public.vinculaciones ENABLE ROW LEVEL SECURITY;

-- -----------------------------------------------------------------------------
-- 3. Trigger de validación (antes de insertar)
-- -----------------------------------------------------------------------------

CREATE FUNCTION public.validar_vinculacion() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_existe_inversa boolean;
BEGIN
  IF NEW.tabla_origen = NEW.tabla_destino AND NEW.registro_origen_id = NEW.registro_destino_id THEN
    RAISE EXCEPTION 'No se puede vincular un registro consigo mismo';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.formularios WHERE slug = NEW.tabla_origen AND activo = true) THEN
    RAISE EXCEPTION 'La tabla de origen "%" no es un módulo válido', NEW.tabla_origen;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.formularios WHERE slug = NEW.tabla_destino AND activo = true) THEN
    RAISE EXCEPTION 'La tabla de destino "%" no es un módulo válido', NEW.tabla_destino;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.vinculaciones
    WHERE tabla_origen = NEW.tabla_destino
      AND registro_origen_id = NEW.registro_destino_id
      AND tabla_destino = NEW.tabla_origen
      AND registro_destino_id = NEW.registro_origen_id
  ) INTO v_existe_inversa;

  IF v_existe_inversa THEN
    RAISE EXCEPTION 'Ya existe un vínculo entre estos dos registros';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validar_vinculacion
    BEFORE INSERT ON public.vinculaciones
    FOR EACH ROW EXECUTE FUNCTION public.validar_vinculacion();

-- -----------------------------------------------------------------------------
-- 4. Policies de seguridad (RLS)
-- -----------------------------------------------------------------------------

-- Ver un vínculo: alcanza con poder ver uno de los dos lados (origen o destino).
CREATE POLICY vinculaciones_select ON public.vinculaciones
    FOR SELECT TO authenticated
    USING (
      public.check_is_admin()
      OR public.usuario_puede_ver_tabla(tabla_origen)
      OR public.usuario_puede_ver_tabla(tabla_destino)
    );

-- Crear un vínculo: hace falta poder ver (al menos lectura) tanto el origen
-- como el destino, y el vínculo queda registrado a nombre de quien lo crea.
CREATE POLICY vinculaciones_insert ON public.vinculaciones
    FOR INSERT TO authenticated
    WITH CHECK (
      created_by = auth.uid()
      AND (
        public.check_is_admin()
        OR (public.usuario_puede_ver_tabla(tabla_origen) AND public.usuario_puede_ver_tabla(tabla_destino))
      )
    );

-- Editar/borrar un vínculo: solo quien lo creó, o un admin.
CREATE POLICY vinculaciones_update ON public.vinculaciones
    FOR UPDATE TO authenticated
    USING (created_by = auth.uid() OR public.check_is_admin())
    WITH CHECK (created_by = auth.uid() OR public.check_is_admin());

CREATE POLICY vinculaciones_delete ON public.vinculaciones
    FOR DELETE TO authenticated
    USING (created_by = auth.uid() OR public.check_is_admin());

GRANT SELECT, INSERT, UPDATE, DELETE ON public.vinculaciones TO authenticated;
GRANT ALL ON public.vinculaciones TO service_role;

GRANT EXECUTE ON FUNCTION public.area_de_tabla(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.usuario_puede_ver_tabla(text) TO authenticated;

-- -----------------------------------------------------------------------------
-- 5. RPC de lectura: trae todos los vínculos de un registro, con un resumen
--    de solo lectura del registro relacionado aunque pertenezca a un área a
--    la que el usuario no tiene acceso (SECURITY DEFINER controlado: primero
--    valida permiso sobre la tabla ancla, recién después lee el resumen).
-- -----------------------------------------------------------------------------

CREATE FUNCTION public.listar_vinculaciones(p_tabla text, p_id uuid)
RETURNS TABLE (
    vinculacion_id uuid,
    tipo_relacion text,
    nota text,
    created_at timestamptz,
    created_by uuid,
    tabla_relacionada text,
    id_relacionado uuid,
    area_nombre text,
    formulario_nombre text,
    resumen jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  rec record;
  v_resumen jsonb;
  v_area_nombre text;
  v_formulario_nombre text;
BEGIN
  IF NOT public.usuario_puede_ver_tabla(p_tabla) THEN
    RAISE EXCEPTION 'No autorizado para ver vínculos de %', p_tabla;
  END IF;

  FOR rec IN
    SELECT
      v.id AS vinculacion_id,
      v.tipo_relacion,
      v.nota,
      v.created_at,
      v.created_by,
      CASE WHEN v.tabla_origen = p_tabla AND v.registro_origen_id = p_id
           THEN v.tabla_destino ELSE v.tabla_origen END AS tabla_relacionada,
      CASE WHEN v.tabla_origen = p_tabla AND v.registro_origen_id = p_id
           THEN v.registro_destino_id ELSE v.registro_origen_id END AS id_relacionado
    FROM public.vinculaciones v
    WHERE (v.tabla_origen = p_tabla AND v.registro_origen_id = p_id)
       OR (v.tabla_destino = p_tabla AND v.registro_destino_id = p_id)
    ORDER BY v.created_at DESC
  LOOP
    v_resumen := NULL;
    BEGIN
      EXECUTE format(
        'SELECT to_jsonb(t) - ''geom'' - ''fotos'' - ''audios'' FROM public.%I t WHERE t.id = $1',
        rec.tabla_relacionada
      ) INTO v_resumen USING rec.id_relacionado;
    EXCEPTION WHEN OTHERS THEN
      v_resumen := NULL;
    END;

    v_area_nombre := NULL;
    v_formulario_nombre := NULL;
    SELECT f.nombre, a.nombre
      INTO v_formulario_nombre, v_area_nombre
    FROM public.formularios f
    JOIN public.areas a ON a.id = f.area_id
    WHERE f.slug = rec.tabla_relacionada;

    vinculacion_id := rec.vinculacion_id;
    tipo_relacion := rec.tipo_relacion;
    nota := rec.nota;
    created_at := rec.created_at;
    created_by := rec.created_by;
    tabla_relacionada := rec.tabla_relacionada;
    id_relacionado := rec.id_relacionado;
    area_nombre := v_area_nombre;
    formulario_nombre := v_formulario_nombre;
    resumen := v_resumen;
    RETURN NEXT;
  END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION public.listar_vinculaciones(text, uuid) TO authenticated;

COMMIT;
