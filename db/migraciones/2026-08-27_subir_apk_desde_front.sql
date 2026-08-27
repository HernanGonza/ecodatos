-- =============================================================================
-- Migración: Subida del APK de la app móvil desde el front (solo superadmin)
-- Fecha: 2026-08-27
--
-- QUÉ HACE: habilita que el superadmin suba una nueva versión del APK
-- directamente desde la tarjeta "APP MÓVIL" del panel, sin pasar por Supabase
-- Studio ni por curl. Para eso:
--   1. Asegura el bucket de Storage `apks`: público (para getPublicUrl),
--      con límite de 200MB y aceptando el mime-type de un .apk.
--   2. Crea policies en storage.objects para el bucket `apks`:
--      - lectura: cualquiera (bucket público).
--      - insert / update / delete: SOLO superadmin (public.check_is_superadmin()).
--   3. Activa RLS en public.mobile_apps (hoy no tiene) con:
--      - lectura: anon + authenticated (la tarjeta la lee sin sesión de admin).
--      - escritura (insert/update/delete): SOLO superadmin.
--
-- ES ADITIVO salvo por un punto: activa RLS en public.mobile_apps. Como se crea
-- al mismo tiempo una policy de SELECT permisiva para anon/authenticated, la
-- tarjeta del front sigue funcionando igual. No hace ALTER de columnas ni borra
-- datos.
--
-- REUTILIZA (sin tocar) la función existente public.check_is_superadmin().
--
-- CÓMO CORRERLA:
--   Recomendado: pg_dump de resguardo antes.
--   Pegar y ejecutar este archivo completo en el SQL Editor de Supabase Studio
--   (por el túnel SSH) o vía psql contra la base. Va envuelto en BEGIN/COMMIT.
--
-- CÓMO DESHACERLA:
--   BEGIN;
--   ALTER TABLE public.mobile_apps DISABLE ROW LEVEL SECURITY;
--   DROP POLICY IF EXISTS mobile_apps_lectura_publica       ON public.mobile_apps;
--   DROP POLICY IF EXISTS mobile_apps_escritura_superadmin  ON public.mobile_apps;
--   DROP POLICY IF EXISTS apks_lectura_publica       ON storage.objects;
--   DROP POLICY IF EXISTS apks_insert_superadmin     ON storage.objects;
--   DROP POLICY IF EXISTS apks_update_superadmin     ON storage.objects;
--   DROP POLICY IF EXISTS apks_delete_superadmin     ON storage.objects;
--   COMMIT;
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Bucket `apks`
-- ---------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'apks',
  'apks',
  true,
  209715200,  -- 200 MB, igual que FILE_SIZE_LIMIT del contenedor de storage y client_max_body_size de nginx
  ARRAY['application/vnd.android.package-archive', 'application/octet-stream']
)
ON CONFLICT (id) DO UPDATE
SET public             = EXCLUDED.public,
    file_size_limit    = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- ---------------------------------------------------------------------------
-- 2. Policies de storage.objects para el bucket `apks`
--    (storage.objects ya tiene RLS activada por defecto en Supabase)
-- ---------------------------------------------------------------------------

-- Lectura: cualquiera. El bucket es público igual, esto cubre el acceso vía API.
DROP POLICY IF EXISTS apks_lectura_publica ON storage.objects;
CREATE POLICY apks_lectura_publica ON storage.objects
  FOR SELECT
  TO public
  USING (bucket_id = 'apks');

-- Alta de un APK nuevo: solo superadmin.
DROP POLICY IF EXISTS apks_insert_superadmin ON storage.objects;
CREATE POLICY apks_insert_superadmin ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'apks' AND public.check_is_superadmin());

-- Sobrescribir un APK existente (upsert): solo superadmin.
DROP POLICY IF EXISTS apks_update_superadmin ON storage.objects;
CREATE POLICY apks_update_superadmin ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (bucket_id = 'apks' AND public.check_is_superadmin())
  WITH CHECK (bucket_id = 'apks' AND public.check_is_superadmin());

-- Borrar un APK: solo superadmin.
DROP POLICY IF EXISTS apks_delete_superadmin ON storage.objects;
CREATE POLICY apks_delete_superadmin ON storage.objects
  FOR DELETE
  TO authenticated
  USING (bucket_id = 'apks' AND public.check_is_superadmin());

-- ---------------------------------------------------------------------------
-- 3. RLS en public.mobile_apps
-- ---------------------------------------------------------------------------
ALTER TABLE public.mobile_apps ENABLE ROW LEVEL SECURITY;

-- Lectura: anon + authenticated. La tarjeta "APP MÓVIL" del panel la consulta
-- con la anon key (filtra activo = true del lado del cliente).
DROP POLICY IF EXISTS mobile_apps_lectura_publica ON public.mobile_apps;
CREATE POLICY mobile_apps_lectura_publica ON public.mobile_apps
  FOR SELECT
  TO anon, authenticated
  USING (true);

-- Escritura (insert / update / delete): solo superadmin.
DROP POLICY IF EXISTS mobile_apps_escritura_superadmin ON public.mobile_apps;
CREATE POLICY mobile_apps_escritura_superadmin ON public.mobile_apps
  FOR ALL
  TO authenticated
  USING (public.check_is_superadmin())
  WITH CHECK (public.check_is_superadmin());

COMMIT;

-- =============================================================================
-- VERIFICACIÓN (correr después, fuera de la transacción):
--
--   select id, name, public, file_size_limit, allowed_mime_types
--   from storage.buckets where id = 'apks';
--
--   select schemaname, tablename, policyname, cmd, roles
--   from pg_policies
--   where (schemaname = 'storage'  and tablename = 'objects' and policyname like 'apks_%')
--      or (schemaname = 'public'   and tablename = 'mobile_apps');
--
--   -- Desde el front, logueado como superadmin, la subida debería funcionar.
--   -- Logueado como cualquier otro rol, storage.upload() debe devolver 403.
-- =============================================================================
