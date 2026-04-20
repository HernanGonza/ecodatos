--
-- PostgreSQL database dump
--

-- Dumped from database version 15.8
-- Dumped by pg_dump version 15.8

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: _realtime; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA _realtime;


--
-- Name: auth; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA auth;


--
-- Name: pg_cron; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION pg_cron; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_cron IS 'Job scheduler for PostgreSQL';


--
-- Name: extensions; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA extensions;


--
-- Name: graphql; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA graphql;


--
-- Name: graphql_public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA graphql_public;


--
-- Name: pgbouncer; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA pgbouncer;


--
-- Name: realtime; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA realtime;


--
-- Name: storage; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA storage;


--
-- Name: supabase_functions; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA supabase_functions;


--
-- Name: vault; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA vault;


--
-- Name: http; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS http WITH SCHEMA extensions;


--
-- Name: EXTENSION http; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION http IS 'HTTP client for PostgreSQL, allows web page retrieval inside the database.';


--
-- Name: pg_graphql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_graphql WITH SCHEMA graphql;


--
-- Name: EXTENSION pg_graphql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_graphql IS 'pg_graphql: GraphQL support';


--
-- Name: pg_stat_statements; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA extensions;


--
-- Name: EXTENSION pg_stat_statements; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_stat_statements IS 'track planning and execution statistics of all SQL statements executed';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: pgjwt; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgjwt WITH SCHEMA extensions;


--
-- Name: EXTENSION pgjwt; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgjwt IS 'JSON Web Token API for Postgresql';


--
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';


--
-- Name: supabase_vault; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS supabase_vault WITH SCHEMA vault;


--
-- Name: EXTENSION supabase_vault; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION supabase_vault IS 'Supabase Vault Extension';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: aal_level; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.aal_level AS ENUM (
    'aal1',
    'aal2',
    'aal3'
);


--
-- Name: code_challenge_method; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.code_challenge_method AS ENUM (
    's256',
    'plain'
);


--
-- Name: factor_status; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.factor_status AS ENUM (
    'unverified',
    'verified'
);


--
-- Name: factor_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.factor_type AS ENUM (
    'totp',
    'webauthn',
    'phone'
);


--
-- Name: oauth_authorization_status; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_authorization_status AS ENUM (
    'pending',
    'approved',
    'denied',
    'expired'
);


--
-- Name: oauth_client_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_client_type AS ENUM (
    'public',
    'confidential'
);


--
-- Name: oauth_registration_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_registration_type AS ENUM (
    'dynamic',
    'manual'
);


--
-- Name: oauth_response_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_response_type AS ENUM (
    'code'
);


--
-- Name: one_time_token_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.one_time_token_type AS ENUM (
    'confirmation_token',
    'reauthentication_token',
    'recovery_token',
    'email_change_token_new',
    'email_change_token_current',
    'phone_change_token'
);


--
-- Name: buckettype; Type: TYPE; Schema: storage; Owner: -
--

CREATE TYPE storage.buckettype AS ENUM (
    'STANDARD',
    'ANALYTICS',
    'VECTOR'
);


--
-- Name: completar_campos_geograficos(); Type: FUNCTION; Schema: _realtime; Owner: -
--

CREATE FUNCTION _realtime.completar_campos_geograficos() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
DECLARE
  v_municipio record;
BEGIN
  -- 1. Construir geometría
  NEW.geom := public.ST_SetSRID(
    public.ST_MakePoint(NEW.longitud_decimal, NEW.latitud_decimal),
    4326
  );

  -- 2. Buscar municipio y departamento por nombre de ciudad
  IF NEW.ciudad_temp IS NOT NULL THEN
    SELECT id, departamento_id 
    INTO v_municipio
    FROM public.municipios
    WHERE nombre ILIKE NEW.ciudad_temp
      AND activo = true
    LIMIT 1;

    NEW.municipio_id    := v_municipio.id;
    NEW.departamento_id := v_municipio.departamento_id;
  END IF;

  -- 3. Limpiar el campo temporal
  NEW.ciudad_temp := NULL;

  RETURN NEW;
END;
$$;


--
-- Name: exec_sql(text); Type: FUNCTION; Schema: _realtime; Owner: -
--

CREATE FUNCTION _realtime.exec_sql(sql_query text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  EXECUTE sql_query;
END;
$$;


--
-- Name: fn_fill_geometry(); Type: FUNCTION; Schema: _realtime; Owner: -
--

CREATE FUNCTION _realtime.fn_fill_geometry() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.latitud_decimal IS NOT NULL AND NEW.longitud_decimal IS NOT NULL THEN
        -- PostGIS: ST_MakePoint(longitude, latitude)
        NEW.geom := ST_SetSRID(
            ST_MakePoint(
                CAST(NEW.longitud_decimal AS FLOAT), 
                CAST(NEW.latitud_decimal AS FLOAT)
            ), 
            4326
        )::geography;
    END IF;
    RETURN NEW;
END;
$$;


--
-- Name: get_orphans_report(); Type: FUNCTION; Schema: _realtime; Owner: -
--

CREATE FUNCTION _realtime.get_orphans_report() RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    rec RECORD;
    total_count INTEGER := 0;
    details JSONB := '[]'::JSONB;
    current_table_count INTEGER;
BEGIN
    -- Listamos todas las tablas de formularios para ver qué encuentra
    FOR rec IN 
        SELECT slug, nombre, area_id 
        FROM public.formularios 
        -- Quitamos el WHERE activo = true temporalmente para debug
    LOOP
        BEGIN
            -- Ejecución dinámica directa
            EXECUTE format('SELECT count(*) FROM public.%I WHERE user_id IS NULL', rec.slug)
            INTO current_table_count;

            -- Registramos TODO lo que encuentre, incluso si es 0, para saber que está escaneando
            IF current_table_count IS NOT NULL THEN
                total_count := total_count + current_table_count;
                details := details || jsonb_build_object(
                    'slug', rec.slug,
                    'nombre', rec.nombre,
                    'count', current_table_count
                );
            END IF;
        EXCEPTION WHEN OTHERS THEN
            -- Si la tabla falla (ej. no existe), registramos el error en el detalle
            details := details || jsonb_build_object(
                'slug', rec.slug,
                'error', SQLERRM
            );
        END;
    END LOOP;

    RETURN json_build_object('total', total_count, 'tables', details);
END;
$$;


--
-- Name: get_table_metadata(text); Type: FUNCTION; Schema: _realtime; Owner: -
--

CREATE FUNCTION _realtime.get_table_metadata(table_name text) RETURNS TABLE(column_name text, data_type text, is_nullable text, foreign_table text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cols.column_name::text,
        cols.data_type::text,
        cols.is_nullable::text,
        -- Buscamos si la columna es una FK y extraemos la tabla a la que apunta
        (SELECT 
            ccu.table_name::text
         FROM information_schema.key_column_usage AS kcu
         JOIN information_schema.constraint_column_usage AS ccu 
           ON ccu.constraint_name = kcu.constraint_name
         WHERE kcu.table_name = get_table_metadata.table_name 
           AND kcu.column_name = cols.column_name 
           AND kcu.table_schema = 'public'
         LIMIT 1
        ) AS foreign_table
    FROM information_schema.columns cols
    WHERE cols.table_name = get_table_metadata.table_name
      AND cols.table_schema = 'public'
    ORDER BY cols.ordinal_position;
END;
$$;


--
-- Name: get_usuarios_por_area(uuid); Type: FUNCTION; Schema: _realtime; Owner: -
--

CREATE FUNCTION _realtime.get_usuarios_por_area(p_area_id uuid) RETURNS TABLE(user_id uuid, full_name text, email text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT u.id, u.nombre_completo, u.email
    FROM usuarios u
    JOIN usuarios_areas ua ON u.id = ua.user_id
    WHERE ua.area_id = p_area_id AND u.activo = true;
END;
$$;


--
-- Name: orphan_records_from_user(uuid); Type: FUNCTION; Schema: _realtime; Owner: -
--

CREATE FUNCTION _realtime.orphan_records_from_user(target_user_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    -- 1. Tablas de NEGOCIO: Ponemos en NULL para conservar el registro (Orfanar)
    UPDATE caza_furtiva SET user_id = NULL WHERE user_id = target_user_id;
    UPDATE ataques_grandes_felinos SET user_id = NULL WHERE user_id = target_user_id;
    UPDATE tenencia_fauna SET user_id = NULL WHERE user_id = target_user_id;
    UPDATE criadero_fauna_silvestre SET user_id = NULL WHERE user_id = target_user_id;

    -- 2. Tablas de RELACIÓN: Borramos la fila completa (Limpiar)
    -- Aquí es donde fallaba porque intentábamos hacer UPDATE a NULL
    DELETE FROM public.usuarios_rol WHERE user_id = target_user_id;
    DELETE FROM public.usuarios_areas WHERE user_id = target_user_id;

END;
$$;


--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: _realtime; Owner: -
--

CREATE FUNCTION _realtime.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


--
-- Name: email(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.email() RETURNS text
    LANGUAGE sql STABLE
    AS $$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.email', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'email')
  )::text
$$;


--
-- Name: FUNCTION email(); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.email() IS 'Deprecated. Use auth.jwt() -> ''email'' instead.';


--
-- Name: jwt(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.jwt() RETURNS jsonb
    LANGUAGE sql STABLE
    AS $$
  select 
    coalesce(
        nullif(current_setting('request.jwt.claim', true), ''),
        nullif(current_setting('request.jwt.claims', true), '')
    )::jsonb
$$;


--
-- Name: role(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.role() RETURNS text
    LANGUAGE sql STABLE
    AS $$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role')
  )::text
$$;


--
-- Name: FUNCTION role(); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.role() IS 'Deprecated. Use auth.jwt() -> ''role'' instead.';


--
-- Name: uid(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.uid() RETURNS uuid
    LANGUAGE sql STABLE
    AS $$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid
$$;


--
-- Name: FUNCTION uid(); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.uid() IS 'Deprecated. Use auth.jwt() -> ''sub'' instead.';


--
-- Name: grant_pg_cron_access(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.grant_pg_cron_access() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF EXISTS (
    SELECT
    FROM pg_event_trigger_ddl_commands() AS ev
    JOIN pg_extension AS ext
    ON ev.objid = ext.oid
    WHERE ext.extname = 'pg_cron'
  )
  THEN
    grant usage on schema cron to postgres with grant option;

    alter default privileges in schema cron grant all on tables to postgres with grant option;
    alter default privileges in schema cron grant all on functions to postgres with grant option;
    alter default privileges in schema cron grant all on sequences to postgres with grant option;

    alter default privileges for user supabase_admin in schema cron grant all
        on sequences to postgres with grant option;
    alter default privileges for user supabase_admin in schema cron grant all
        on tables to postgres with grant option;
    alter default privileges for user supabase_admin in schema cron grant all
        on functions to postgres with grant option;

    grant all privileges on all tables in schema cron to postgres with grant option;
    revoke all on table cron.job from postgres;
    grant select on table cron.job to postgres with grant option;
  END IF;
END;
$$;


--
-- Name: FUNCTION grant_pg_cron_access(); Type: COMMENT; Schema: extensions; Owner: -
--

COMMENT ON FUNCTION extensions.grant_pg_cron_access() IS 'Grants access to pg_cron';


--
-- Name: grant_pg_graphql_access(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.grant_pg_graphql_access() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $_$
DECLARE
    func_is_graphql_resolve bool;
BEGIN
    func_is_graphql_resolve = (
        SELECT n.proname = 'resolve'
        FROM pg_event_trigger_ddl_commands() AS ev
        LEFT JOIN pg_catalog.pg_proc AS n
        ON ev.objid = n.oid
    );

    IF func_is_graphql_resolve
    THEN
        -- Update public wrapper to pass all arguments through to the pg_graphql resolve func
        DROP FUNCTION IF EXISTS graphql_public.graphql;
        create or replace function graphql_public.graphql(
            "operationName" text default null,
            query text default null,
            variables jsonb default null,
            extensions jsonb default null
        )
            returns jsonb
            language sql
        as $$
            select graphql.resolve(
                query := query,
                variables := coalesce(variables, '{}'),
                "operationName" := "operationName",
                extensions := extensions
            );
        $$;

        -- This hook executes when `graphql.resolve` is created. That is not necessarily the last
        -- function in the extension so we need to grant permissions on existing entities AND
        -- update default permissions to any others that are created after `graphql.resolve`
        grant usage on schema graphql to postgres, anon, authenticated, service_role;
        grant select on all tables in schema graphql to postgres, anon, authenticated, service_role;
        grant execute on all functions in schema graphql to postgres, anon, authenticated, service_role;
        grant all on all sequences in schema graphql to postgres, anon, authenticated, service_role;
        alter default privileges in schema graphql grant all on tables to postgres, anon, authenticated, service_role;
        alter default privileges in schema graphql grant all on functions to postgres, anon, authenticated, service_role;
        alter default privileges in schema graphql grant all on sequences to postgres, anon, authenticated, service_role;

        -- Allow postgres role to allow granting usage on graphql and graphql_public schemas to custom roles
        grant usage on schema graphql_public to postgres with grant option;
        grant usage on schema graphql to postgres with grant option;
    END IF;

END;
$_$;


--
-- Name: FUNCTION grant_pg_graphql_access(); Type: COMMENT; Schema: extensions; Owner: -
--

COMMENT ON FUNCTION extensions.grant_pg_graphql_access() IS 'Grants access to pg_graphql';


--
-- Name: grant_pg_net_access(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.grant_pg_net_access() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_event_trigger_ddl_commands() AS ev
    JOIN pg_extension AS ext
    ON ev.objid = ext.oid
    WHERE ext.extname = 'pg_net'
  )
  THEN
    IF NOT EXISTS (
      SELECT 1
      FROM pg_roles
      WHERE rolname = 'supabase_functions_admin'
    )
    THEN
      CREATE USER supabase_functions_admin NOINHERIT CREATEROLE LOGIN NOREPLICATION;
    END IF;

    GRANT USAGE ON SCHEMA net TO supabase_functions_admin, postgres, anon, authenticated, service_role;

    IF EXISTS (
      SELECT FROM pg_extension
      WHERE extname = 'pg_net'
      -- all versions in use on existing projects as of 2025-02-20
      -- version 0.12.0 onwards don't need these applied
      AND extversion IN ('0.2', '0.6', '0.7', '0.7.1', '0.8', '0.10.0', '0.11.0')
    ) THEN
      ALTER function net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) SECURITY DEFINER;
      ALTER function net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) SECURITY DEFINER;

      ALTER function net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) SET search_path = net;
      ALTER function net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) SET search_path = net;

      REVOKE ALL ON FUNCTION net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) FROM PUBLIC;
      REVOKE ALL ON FUNCTION net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) FROM PUBLIC;

      GRANT EXECUTE ON FUNCTION net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) TO supabase_functions_admin, postgres, anon, authenticated, service_role;
      GRANT EXECUTE ON FUNCTION net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) TO supabase_functions_admin, postgres, anon, authenticated, service_role;
    END IF;
  END IF;
END;
$$;


--
-- Name: FUNCTION grant_pg_net_access(); Type: COMMENT; Schema: extensions; Owner: -
--

COMMENT ON FUNCTION extensions.grant_pg_net_access() IS 'Grants access to pg_net';


--
-- Name: pgrst_ddl_watch(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.pgrst_ddl_watch() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN SELECT * FROM pg_event_trigger_ddl_commands()
  LOOP
    IF cmd.command_tag IN (
      'CREATE SCHEMA', 'ALTER SCHEMA'
    , 'CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO', 'ALTER TABLE'
    , 'CREATE FOREIGN TABLE', 'ALTER FOREIGN TABLE'
    , 'CREATE VIEW', 'ALTER VIEW'
    , 'CREATE MATERIALIZED VIEW', 'ALTER MATERIALIZED VIEW'
    , 'CREATE FUNCTION', 'ALTER FUNCTION'
    , 'CREATE TRIGGER'
    , 'CREATE TYPE', 'ALTER TYPE'
    , 'CREATE RULE'
    , 'COMMENT'
    )
    -- don't notify in case of CREATE TEMP table or other objects created on pg_temp
    AND cmd.schema_name is distinct from 'pg_temp'
    THEN
      NOTIFY pgrst, 'reload schema';
    END IF;
  END LOOP;
END; $$;


--
-- Name: pgrst_drop_watch(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.pgrst_drop_watch() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  obj record;
BEGIN
  FOR obj IN SELECT * FROM pg_event_trigger_dropped_objects()
  LOOP
    IF obj.object_type IN (
      'schema'
    , 'table'
    , 'foreign table'
    , 'view'
    , 'materialized view'
    , 'function'
    , 'trigger'
    , 'type'
    , 'rule'
    )
    AND obj.is_temporary IS false -- no pg_temp objects
    THEN
      NOTIFY pgrst, 'reload schema';
    END IF;
  END LOOP;
END; $$;


--
-- Name: set_graphql_placeholder(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.set_graphql_placeholder() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $_$
    DECLARE
    graphql_is_dropped bool;
    BEGIN
    graphql_is_dropped = (
        SELECT ev.schema_name = 'graphql_public'
        FROM pg_event_trigger_dropped_objects() AS ev
        WHERE ev.schema_name = 'graphql_public'
    );

    IF graphql_is_dropped
    THEN
        create or replace function graphql_public.graphql(
            "operationName" text default null,
            query text default null,
            variables jsonb default null,
            extensions jsonb default null
        )
            returns jsonb
            language plpgsql
        as $$
            DECLARE
                server_version float;
            BEGIN
                server_version = (SELECT (SPLIT_PART((select version()), ' ', 2))::float);

                IF server_version >= 14 THEN
                    RETURN jsonb_build_object(
                        'errors', jsonb_build_array(
                            jsonb_build_object(
                                'message', 'pg_graphql extension is not enabled.'
                            )
                        )
                    );
                ELSE
                    RETURN jsonb_build_object(
                        'errors', jsonb_build_array(
                            jsonb_build_object(
                                'message', 'pg_graphql is only available on projects running Postgres 14 onwards.'
                            )
                        )
                    );
                END IF;
            END;
        $$;
    END IF;

    END;
$_$;


--
-- Name: FUNCTION set_graphql_placeholder(); Type: COMMENT; Schema: extensions; Owner: -
--

COMMENT ON FUNCTION extensions.set_graphql_placeholder() IS 'Reintroduces placeholder function for graphql_public.graphql';


--
-- Name: get_auth(text); Type: FUNCTION; Schema: pgbouncer; Owner: -
--

CREATE FUNCTION pgbouncer.get_auth(p_usename text) RETURNS TABLE(username text, password text)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $_$
begin
    raise debug 'PgBouncer auth request: %', p_usename;

    return query
    select 
        rolname::text, 
        case when rolvaliduntil < now() 
            then null 
            else rolpassword::text 
        end 
    from pg_authid 
    where rolname=$1 and rolcanlogin;
end;
$_$;


--
-- Name: check_is_admin(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_is_admin() RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.usuarios_rol ur
    JOIN public.roles r ON ur.rol_id = r.id
    WHERE ur.user_id = auth.uid() 
    AND r.key IN ('superadmin', 'admin')
    AND ur.activo = true
  );
END;
$$;


--
-- Name: check_is_area_admin(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_is_area_admin() RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.usuarios_rol ur
    JOIN public.roles r ON r.id = ur.rol_id
    WHERE ur.user_id = auth.uid() 
    AND r.key = 'adminArea'
    AND r.activo = true
  );
END;
$$;


--
-- Name: check_is_superadmin(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_is_superadmin() RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM public.usuarios_rol ur
    INNER JOIN public.roles r ON ur.rol_id = r.id
    WHERE ur.user_id = auth.uid() 
    AND r.key = 'superadmin'
  );
END;
$$;


--
-- Name: check_tables_exist(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_tables_exist() RETURNS TABLE(table_name text)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT t.table_name::text
    FROM information_schema.tables t
    WHERE t.table_schema = 'public';
END;
$$;


--
-- Name: check_user_in_area(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_user_in_area(target_area_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  -- Esta función la usan las RLS para INSERT y UPDATE.
  -- Permite la acción si el usuario tiene el área asignada y está activa.
  RETURN EXISTS (
    SELECT 1 FROM public.usuarios_areas
    WHERE user_id = auth.uid() 
    AND area_id = target_area_id
    AND activo = true
  );
END;
$$;


--
-- Name: desvincular_usuario_registros(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.desvincular_usuario_registros(target_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    -- Busca en todas las tablas del esquema public que tengan columnas que apunten a auth.users
    -- y las pone en NULL si se llama 'created_by' o 'user_id'
    UPDATE public.actuaciones_control_guardaparques SET created_by = NULL WHERE created_by = target_id;
    UPDATE public.actuaciones_control_guardaparques SET user_id = NULL WHERE user_id = target_id;
    
    UPDATE public.guias_transito_forestal SET created_by = NULL WHERE created_by = target_id;
    UPDATE public.guias_transito_forestal SET user_id = NULL WHERE user_id = target_id;
    
    -- Agregá acá cualquier tabla nueva que crees en el futuro
END;
$$;


--
-- Name: exec_sql(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.exec_sql(sql_query text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  EXECUTE sql_query;
END;
$$;


--
-- Name: fn_fill_geometry(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_fill_geometry() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.latitud_decimal IS NOT NULL AND NEW.longitud_decimal IS NOT NULL THEN
        -- Usamos public.ST_SetSRID y public.ST_MakePoint para mayor seguridad
        NEW.geom := public.ST_SetSRID(
            public.ST_MakePoint(
                CAST(NEW.longitud_decimal AS FLOAT), 
                CAST(NEW.latitud_decimal AS FLOAT)
            ), 
            4326
        );
    END IF;
    RETURN NEW;
END;
$$;


--
-- Name: get_orphans_report(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_orphans_report() RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    rec RECORD;
    total_count INTEGER := 0;
    details JSONB := '[]'::JSONB;
    current_table_count INTEGER;
BEGIN
    FOR rec IN 
        SELECT slug, nombre, area_id 
        FROM public.formularios 
        WHERE activo = true 
    LOOP
        BEGIN
            EXECUTE format('SELECT count(*) FROM public.%I WHERE user_id IS NULL AND activo = true', rec.slug)
            INTO current_table_count;

            IF current_table_count > 0 THEN
                total_count := total_count + current_table_count;
                details := details || jsonb_build_object(
                    'slug', rec.slug,
                    'nombre', rec.nombre,
                    'area_id', rec.area_id,
                    'count', current_table_count
                );
            END IF;
        EXCEPTION WHEN OTHERS THEN
            CONTINUE;
        END;
    END LOOP;

    RETURN json_build_object('total', total_count, 'tables', details);
END;
$$;


--
-- Name: get_orphans_report(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_orphans_report(p_area_id uuid DEFAULT NULL::uuid) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    row_record RECORD;
    table_count INT;
    total_orphans INT := 0;
    tables_list JSONB := '[]'::JSONB;
BEGIN
    -- Iteramos sobre los formularios activos
    FOR row_record IN 
        SELECT slug, nombre, area_id 
        FROM public.formularios 
        WHERE activo = true 
        AND (p_area_id IS NULL OR area_id = p_area_id) -- FILTRO POR ÁREA
    LOOP
        -- Contamos registros con user_id nulo en cada tabla dinámica
        EXECUTE format('SELECT count(*) FROM public.%I WHERE user_id IS NULL AND activo = true', row_record.slug)
        INTO table_count;

        IF table_count > 0 THEN
            total_orphans := total_orphans + table_count;
            tables_list := tables_list || jsonb_build_object(
                'slug', row_record.slug,
                'nombre', row_record.nombre,
                'count', table_count,
                'area_id', row_record.area_id
            );
        END IF;
    END LOOP;

    RETURN json_build_object(
        'total', total_orphans,
        'tables', tables_list
    );
END;
$$;


--
-- Name: get_table_columns(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_table_columns(table_name text) RETURNS TABLE(column_name text, data_type text, is_nullable text)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    c.column_name::text,
    c.data_type::text,
    c.is_nullable::text
  FROM information_schema.columns c
  WHERE c.table_name = get_table_columns.table_name
    AND c.table_schema = 'public'
  ORDER BY c.ordinal_position;
END;
$$;


--
-- Name: get_table_metadata(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_table_metadata(table_name text) RETURNS TABLE(column_name text, data_type text, is_nullable text, foreign_table text, foreign_column text)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.column_name::text,
        c.data_type::text,
        c.is_nullable::text,
        (SELECT tc.table_name FROM information_schema.key_column_usage kcu
         JOIN information_schema.constraint_column_usage tc ON kcu.constraint_name = tc.constraint_name
         JOIN information_schema.table_constraints tcons ON kcu.constraint_name = tcons.constraint_name
         WHERE kcu.table_name = get_table_metadata.table_name 
           AND kcu.column_name = c.column_name 
           AND tcons.constraint_type = 'FOREIGN KEY' LIMIT 1)::text as foreign_table,
        (SELECT tc.column_name FROM information_schema.key_column_usage kcu
         JOIN information_schema.constraint_column_usage tc ON kcu.constraint_name = tc.constraint_name
         JOIN information_schema.table_constraints tcons ON kcu.constraint_name = tcons.constraint_name
         WHERE kcu.table_name = get_table_metadata.table_name 
           AND kcu.column_name = c.column_name 
           AND tcons.constraint_type = 'FOREIGN KEY' LIMIT 1)::text as foreign_column
    FROM 
        information_schema.columns c
    WHERE 
        c.table_name = get_table_metadata.table_name
        AND c.table_schema = 'public'
    ORDER BY c.ordinal_position;
END;
$$;


--
-- Name: get_usuarios_por_area(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_usuarios_por_area(p_area_id uuid) RETURNS TABLE(user_id uuid, full_name text, email text)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ua.user_id,
    COALESCE((u.raw_user_meta_data->>'full_name')::text, u.email::text) as full_name,
    u.email::text
  FROM public.usuarios_areas ua
  JOIN auth.users u ON u.id = ua.user_id
  WHERE ua.area_id = p_area_id;
END;
$$;


--
-- Name: handle_new_user(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.handle_new_user() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, email)
  VALUES (new.id, new.raw_user_meta_data->>'full_name', new.email);
  RETURN new;
END;
$$;


--
-- Name: is_admin(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_admin() RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM usuarios_rol ur
    JOIN roles r ON ur.rol_id = r.id
    WHERE ur.user_id = auth.uid() 
    AND r.key IN ('admin', 'superadmin')
  );
END;
$$;


--
-- Name: is_superadmin(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_superadmin() RETURNS boolean
    LANGUAGE sql SECURITY DEFINER
    AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.usuarios_rol ur
    JOIN public.roles r ON ur.rol_id = r.id
    WHERE ur.user_id = auth.uid() AND r.key = 'superadmin'
  );
$$;


--
-- Name: orphan_records_from_user(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.orphan_records_from_user(target_user_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    -- 1. Tablas de Relación (DELETE)
    DELETE FROM public.usuarios_rol WHERE user_id = target_user_id;
    DELETE FROM public.usuarios_areas WHERE user_id = target_user_id;

    -- 2. Tablas de Negocio (UPDATE a NULL)
    UPDATE public.caza_furtiva SET user_id = NULL WHERE user_id = target_user_id;
    UPDATE public.ataques_grandes_felinos SET user_id = NULL WHERE user_id = target_user_id;
    UPDATE public.tenencia_fauna SET user_id = NULL WHERE user_id = target_user_id;
    UPDATE public.criadero_fauna_silvestre SET user_id = NULL WHERE user_id = target_user_id;
END;
$$;


--
-- Name: tiene_rol(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.tiene_rol(_rol text) RETURNS boolean
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1
    from usuarios_rol ur
    join roles r on r.id = ur.rol_id
    where ur.user_id = auth.uid()
      and r.key = _rol
  );
$$;


--
-- Name: update_geom_ataques_felinos(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_geom_ataques_felinos() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.latitud_decimal IS NOT NULL AND NEW.longitud_decimal IS NOT NULL THEN
    NEW.geom = ST_SetSRID(ST_MakePoint(NEW.longitud_decimal, NEW.latitud_decimal), 4326);
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


--
-- Name: usuario_en_area(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.usuario_en_area(_area_id uuid) RETURNS boolean
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1
    from usuarios_areas ua
    where ua.user_id = auth.uid()
      and ua.area_id = _area_id
  );
$$;


--
-- Name: add_prefixes(text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.add_prefixes(_bucket_id text, _name text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    prefixes text[];
BEGIN
    prefixes := "storage"."get_prefixes"("_name");

    IF array_length(prefixes, 1) > 0 THEN
        INSERT INTO storage.prefixes (name, bucket_id)
        SELECT UNNEST(prefixes) as name, "_bucket_id" ON CONFLICT DO NOTHING;
    END IF;
END;
$$;


--
-- Name: can_insert_object(text, text, uuid, jsonb); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.can_insert_object(bucketid text, name text, owner uuid, metadata jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  INSERT INTO "storage"."objects" ("bucket_id", "name", "owner", "metadata") VALUES (bucketid, name, owner, metadata);
  -- hack to rollback the successful insert
  RAISE sqlstate 'PT200' using
  message = 'ROLLBACK',
  detail = 'rollback successful insert';
END
$$;


--
-- Name: delete_leaf_prefixes(text[], text[]); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.delete_leaf_prefixes(bucket_ids text[], names text[]) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_rows_deleted integer;
BEGIN
    LOOP
        WITH candidates AS (
            SELECT DISTINCT
                t.bucket_id,
                unnest(storage.get_prefixes(t.name)) AS name
            FROM unnest(bucket_ids, names) AS t(bucket_id, name)
        ),
        uniq AS (
             SELECT
                 bucket_id,
                 name,
                 storage.get_level(name) AS level
             FROM candidates
             WHERE name <> ''
             GROUP BY bucket_id, name
        ),
        leaf AS (
             SELECT
                 p.bucket_id,
                 p.name,
                 p.level
             FROM storage.prefixes AS p
                  JOIN uniq AS u
                       ON u.bucket_id = p.bucket_id
                           AND u.name = p.name
                           AND u.level = p.level
             WHERE NOT EXISTS (
                 SELECT 1
                 FROM storage.objects AS o
                 WHERE o.bucket_id = p.bucket_id
                   AND o.level = p.level + 1
                   AND o.name COLLATE "C" LIKE p.name || '/%'
             )
             AND NOT EXISTS (
                 SELECT 1
                 FROM storage.prefixes AS c
                 WHERE c.bucket_id = p.bucket_id
                   AND c.level = p.level + 1
                   AND c.name COLLATE "C" LIKE p.name || '/%'
             )
        )
        DELETE
        FROM storage.prefixes AS p
            USING leaf AS l
        WHERE p.bucket_id = l.bucket_id
          AND p.name = l.name
          AND p.level = l.level;

        GET DIAGNOSTICS v_rows_deleted = ROW_COUNT;
        EXIT WHEN v_rows_deleted = 0;
    END LOOP;
END;
$$;


--
-- Name: delete_prefix(text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.delete_prefix(_bucket_id text, _name text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    -- Check if we can delete the prefix
    IF EXISTS(
        SELECT FROM "storage"."prefixes"
        WHERE "prefixes"."bucket_id" = "_bucket_id"
          AND level = "storage"."get_level"("_name") + 1
          AND "prefixes"."name" COLLATE "C" LIKE "_name" || '/%'
        LIMIT 1
    )
    OR EXISTS(
        SELECT FROM "storage"."objects"
        WHERE "objects"."bucket_id" = "_bucket_id"
          AND "storage"."get_level"("objects"."name") = "storage"."get_level"("_name") + 1
          AND "objects"."name" COLLATE "C" LIKE "_name" || '/%'
        LIMIT 1
    ) THEN
    -- There are sub-objects, skip deletion
    RETURN false;
    ELSE
        DELETE FROM "storage"."prefixes"
        WHERE "prefixes"."bucket_id" = "_bucket_id"
          AND level = "storage"."get_level"("_name")
          AND "prefixes"."name" = "_name";
        RETURN true;
    END IF;
END;
$$;


--
-- Name: delete_prefix_hierarchy_trigger(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.delete_prefix_hierarchy_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    prefix text;
BEGIN
    prefix := "storage"."get_prefix"(OLD."name");

    IF coalesce(prefix, '') != '' THEN
        PERFORM "storage"."delete_prefix"(OLD."bucket_id", prefix);
    END IF;

    RETURN OLD;
END;
$$;


--
-- Name: enforce_bucket_name_length(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.enforce_bucket_name_length() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    if length(new.name) > 100 then
        raise exception 'bucket name "%" is too long (% characters). Max is 100.', new.name, length(new.name);
    end if;
    return new;
end;
$$;


--
-- Name: extension(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.extension(name text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    _parts text[];
    _filename text;
BEGIN
    SELECT string_to_array(name, '/') INTO _parts;
    SELECT _parts[array_length(_parts,1)] INTO _filename;
    RETURN reverse(split_part(reverse(_filename), '.', 1));
END
$$;


--
-- Name: filename(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.filename(name text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
_parts text[];
BEGIN
	select string_to_array(name, '/') into _parts;
	return _parts[array_length(_parts,1)];
END
$$;


--
-- Name: foldername(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.foldername(name text) RETURNS text[]
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    _parts text[];
BEGIN
    -- Split on "/" to get path segments
    SELECT string_to_array(name, '/') INTO _parts;
    -- Return everything except the last segment
    RETURN _parts[1 : array_length(_parts,1) - 1];
END
$$;


--
-- Name: get_level(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.get_level(name text) RETURNS integer
    LANGUAGE sql IMMUTABLE STRICT
    AS $$
SELECT array_length(string_to_array("name", '/'), 1);
$$;


--
-- Name: get_prefix(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.get_prefix(name text) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$
SELECT
    CASE WHEN strpos("name", '/') > 0 THEN
             regexp_replace("name", '[\/]{1}[^\/]+\/?$', '')
         ELSE
             ''
        END;
$_$;


--
-- Name: get_prefixes(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.get_prefixes(name text) RETURNS text[]
    LANGUAGE plpgsql IMMUTABLE STRICT
    AS $$
DECLARE
    parts text[];
    prefixes text[];
    prefix text;
BEGIN
    -- Split the name into parts by '/'
    parts := string_to_array("name", '/');
    prefixes := '{}';

    -- Construct the prefixes, stopping one level below the last part
    FOR i IN 1..array_length(parts, 1) - 1 LOOP
            prefix := array_to_string(parts[1:i], '/');
            prefixes := array_append(prefixes, prefix);
    END LOOP;

    RETURN prefixes;
END;
$$;


--
-- Name: get_size_by_bucket(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.get_size_by_bucket() RETURNS TABLE(size bigint, bucket_id text)
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    return query
        select sum((metadata->>'size')::bigint) as size, obj.bucket_id
        from "storage".objects as obj
        group by obj.bucket_id;
END
$$;


--
-- Name: list_multipart_uploads_with_delimiter(text, text, text, integer, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.list_multipart_uploads_with_delimiter(bucket_id text, prefix_param text, delimiter_param text, max_keys integer DEFAULT 100, next_key_token text DEFAULT ''::text, next_upload_token text DEFAULT ''::text) RETURNS TABLE(key text, id text, created_at timestamp with time zone)
    LANGUAGE plpgsql
    AS $_$
BEGIN
    RETURN QUERY EXECUTE
        'SELECT DISTINCT ON(key COLLATE "C") * from (
            SELECT
                CASE
                    WHEN position($2 IN substring(key from length($1) + 1)) > 0 THEN
                        substring(key from 1 for length($1) + position($2 IN substring(key from length($1) + 1)))
                    ELSE
                        key
                END AS key, id, created_at
            FROM
                storage.s3_multipart_uploads
            WHERE
                bucket_id = $5 AND
                key ILIKE $1 || ''%'' AND
                CASE
                    WHEN $4 != '''' AND $6 = '''' THEN
                        CASE
                            WHEN position($2 IN substring(key from length($1) + 1)) > 0 THEN
                                substring(key from 1 for length($1) + position($2 IN substring(key from length($1) + 1))) COLLATE "C" > $4
                            ELSE
                                key COLLATE "C" > $4
                            END
                    ELSE
                        true
                END AND
                CASE
                    WHEN $6 != '''' THEN
                        id COLLATE "C" > $6
                    ELSE
                        true
                    END
            ORDER BY
                key COLLATE "C" ASC, created_at ASC) as e order by key COLLATE "C" LIMIT $3'
        USING prefix_param, delimiter_param, max_keys, next_key_token, bucket_id, next_upload_token;
END;
$_$;


--
-- Name: list_objects_with_delimiter(text, text, text, integer, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.list_objects_with_delimiter(bucket_id text, prefix_param text, delimiter_param text, max_keys integer DEFAULT 100, start_after text DEFAULT ''::text, next_token text DEFAULT ''::text) RETURNS TABLE(name text, id uuid, metadata jsonb, updated_at timestamp with time zone)
    LANGUAGE plpgsql
    AS $_$
BEGIN
    RETURN QUERY EXECUTE
        'SELECT DISTINCT ON(name COLLATE "C") * from (
            SELECT
                CASE
                    WHEN position($2 IN substring(name from length($1) + 1)) > 0 THEN
                        substring(name from 1 for length($1) + position($2 IN substring(name from length($1) + 1)))
                    ELSE
                        name
                END AS name, id, metadata, updated_at
            FROM
                storage.objects
            WHERE
                bucket_id = $5 AND
                name ILIKE $1 || ''%'' AND
                CASE
                    WHEN $6 != '''' THEN
                    name COLLATE "C" > $6
                ELSE true END
                AND CASE
                    WHEN $4 != '''' THEN
                        CASE
                            WHEN position($2 IN substring(name from length($1) + 1)) > 0 THEN
                                substring(name from 1 for length($1) + position($2 IN substring(name from length($1) + 1))) COLLATE "C" > $4
                            ELSE
                                name COLLATE "C" > $4
                            END
                    ELSE
                        true
                END
            ORDER BY
                name COLLATE "C" ASC) as e order by name COLLATE "C" LIMIT $3'
        USING prefix_param, delimiter_param, max_keys, next_token, bucket_id, start_after;
END;
$_$;


--
-- Name: lock_top_prefixes(text[], text[]); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.lock_top_prefixes(bucket_ids text[], names text[]) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_bucket text;
    v_top text;
BEGIN
    FOR v_bucket, v_top IN
        SELECT DISTINCT t.bucket_id,
            split_part(t.name, '/', 1) AS top
        FROM unnest(bucket_ids, names) AS t(bucket_id, name)
        WHERE t.name <> ''
        ORDER BY 1, 2
        LOOP
            PERFORM pg_advisory_xact_lock(hashtextextended(v_bucket || '/' || v_top, 0));
        END LOOP;
END;
$$;


--
-- Name: objects_delete_cleanup(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.objects_delete_cleanup() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_bucket_ids text[];
    v_names      text[];
BEGIN
    IF current_setting('storage.gc.prefixes', true) = '1' THEN
        RETURN NULL;
    END IF;

    PERFORM set_config('storage.gc.prefixes', '1', true);

    SELECT COALESCE(array_agg(d.bucket_id), '{}'),
           COALESCE(array_agg(d.name), '{}')
    INTO v_bucket_ids, v_names
    FROM deleted AS d
    WHERE d.name <> '';

    PERFORM storage.lock_top_prefixes(v_bucket_ids, v_names);
    PERFORM storage.delete_leaf_prefixes(v_bucket_ids, v_names);

    RETURN NULL;
END;
$$;


--
-- Name: objects_insert_prefix_trigger(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.objects_insert_prefix_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM "storage"."add_prefixes"(NEW."bucket_id", NEW."name");
    NEW.level := "storage"."get_level"(NEW."name");

    RETURN NEW;
END;
$$;


--
-- Name: objects_update_cleanup(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.objects_update_cleanup() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    -- NEW - OLD (destinations to create prefixes for)
    v_add_bucket_ids text[];
    v_add_names      text[];

    -- OLD - NEW (sources to prune)
    v_src_bucket_ids text[];
    v_src_names      text[];
BEGIN
    IF TG_OP <> 'UPDATE' THEN
        RETURN NULL;
    END IF;

    -- 1) Compute NEW−OLD (added paths) and OLD−NEW (moved-away paths)
    WITH added AS (
        SELECT n.bucket_id, n.name
        FROM new_rows n
        WHERE n.name <> '' AND position('/' in n.name) > 0
        EXCEPT
        SELECT o.bucket_id, o.name FROM old_rows o WHERE o.name <> ''
    ),
    moved AS (
         SELECT o.bucket_id, o.name
         FROM old_rows o
         WHERE o.name <> ''
         EXCEPT
         SELECT n.bucket_id, n.name FROM new_rows n WHERE n.name <> ''
    )
    SELECT
        -- arrays for ADDED (dest) in stable order
        COALESCE( (SELECT array_agg(a.bucket_id ORDER BY a.bucket_id, a.name) FROM added a), '{}' ),
        COALESCE( (SELECT array_agg(a.name      ORDER BY a.bucket_id, a.name) FROM added a), '{}' ),
        -- arrays for MOVED (src) in stable order
        COALESCE( (SELECT array_agg(m.bucket_id ORDER BY m.bucket_id, m.name) FROM moved m), '{}' ),
        COALESCE( (SELECT array_agg(m.name      ORDER BY m.bucket_id, m.name) FROM moved m), '{}' )
    INTO v_add_bucket_ids, v_add_names, v_src_bucket_ids, v_src_names;

    -- Nothing to do?
    IF (array_length(v_add_bucket_ids, 1) IS NULL) AND (array_length(v_src_bucket_ids, 1) IS NULL) THEN
        RETURN NULL;
    END IF;

    -- 2) Take per-(bucket, top) locks: ALL prefixes in consistent global order to prevent deadlocks
    DECLARE
        v_all_bucket_ids text[];
        v_all_names text[];
    BEGIN
        -- Combine source and destination arrays for consistent lock ordering
        v_all_bucket_ids := COALESCE(v_src_bucket_ids, '{}') || COALESCE(v_add_bucket_ids, '{}');
        v_all_names := COALESCE(v_src_names, '{}') || COALESCE(v_add_names, '{}');

        -- Single lock call ensures consistent global ordering across all transactions
        IF array_length(v_all_bucket_ids, 1) IS NOT NULL THEN
            PERFORM storage.lock_top_prefixes(v_all_bucket_ids, v_all_names);
        END IF;
    END;

    -- 3) Create destination prefixes (NEW−OLD) BEFORE pruning sources
    IF array_length(v_add_bucket_ids, 1) IS NOT NULL THEN
        WITH candidates AS (
            SELECT DISTINCT t.bucket_id, unnest(storage.get_prefixes(t.name)) AS name
            FROM unnest(v_add_bucket_ids, v_add_names) AS t(bucket_id, name)
            WHERE name <> ''
        )
        INSERT INTO storage.prefixes (bucket_id, name)
        SELECT c.bucket_id, c.name
        FROM candidates c
        ON CONFLICT DO NOTHING;
    END IF;

    -- 4) Prune source prefixes bottom-up for OLD−NEW
    IF array_length(v_src_bucket_ids, 1) IS NOT NULL THEN
        -- re-entrancy guard so DELETE on prefixes won't recurse
        IF current_setting('storage.gc.prefixes', true) <> '1' THEN
            PERFORM set_config('storage.gc.prefixes', '1', true);
        END IF;

        PERFORM storage.delete_leaf_prefixes(v_src_bucket_ids, v_src_names);
    END IF;

    RETURN NULL;
END;
$$;


--
-- Name: objects_update_level_trigger(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.objects_update_level_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Ensure this is an update operation and the name has changed
    IF TG_OP = 'UPDATE' AND (NEW."name" <> OLD."name" OR NEW."bucket_id" <> OLD."bucket_id") THEN
        -- Set the new level
        NEW."level" := "storage"."get_level"(NEW."name");
    END IF;
    RETURN NEW;
END;
$$;


--
-- Name: objects_update_prefix_trigger(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.objects_update_prefix_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    old_prefixes TEXT[];
BEGIN
    -- Ensure this is an update operation and the name has changed
    IF TG_OP = 'UPDATE' AND (NEW."name" <> OLD."name" OR NEW."bucket_id" <> OLD."bucket_id") THEN
        -- Retrieve old prefixes
        old_prefixes := "storage"."get_prefixes"(OLD."name");

        -- Remove old prefixes that are only used by this object
        WITH all_prefixes as (
            SELECT unnest(old_prefixes) as prefix
        ),
        can_delete_prefixes as (
             SELECT prefix
             FROM all_prefixes
             WHERE NOT EXISTS (
                 SELECT 1 FROM "storage"."objects"
                 WHERE "bucket_id" = OLD."bucket_id"
                   AND "name" <> OLD."name"
                   AND "name" LIKE (prefix || '%')
             )
         )
        DELETE FROM "storage"."prefixes" WHERE name IN (SELECT prefix FROM can_delete_prefixes);

        -- Add new prefixes
        PERFORM "storage"."add_prefixes"(NEW."bucket_id", NEW."name");
    END IF;
    -- Set the new level
    NEW."level" := "storage"."get_level"(NEW."name");

    RETURN NEW;
END;
$$;


--
-- Name: operation(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.operation() RETURNS text
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    RETURN current_setting('storage.operation', true);
END;
$$;


--
-- Name: prefixes_delete_cleanup(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.prefixes_delete_cleanup() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_bucket_ids text[];
    v_names      text[];
BEGIN
    IF current_setting('storage.gc.prefixes', true) = '1' THEN
        RETURN NULL;
    END IF;

    PERFORM set_config('storage.gc.prefixes', '1', true);

    SELECT COALESCE(array_agg(d.bucket_id), '{}'),
           COALESCE(array_agg(d.name), '{}')
    INTO v_bucket_ids, v_names
    FROM deleted AS d
    WHERE d.name <> '';

    PERFORM storage.lock_top_prefixes(v_bucket_ids, v_names);
    PERFORM storage.delete_leaf_prefixes(v_bucket_ids, v_names);

    RETURN NULL;
END;
$$;


--
-- Name: prefixes_insert_trigger(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.prefixes_insert_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM "storage"."add_prefixes"(NEW."bucket_id", NEW."name");
    RETURN NEW;
END;
$$;


--
-- Name: search(text, text, integer, integer, integer, text, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.search(prefix text, bucketname text, limits integer DEFAULT 100, levels integer DEFAULT 1, offsets integer DEFAULT 0, search text DEFAULT ''::text, sortcolumn text DEFAULT 'name'::text, sortorder text DEFAULT 'asc'::text) RETURNS TABLE(name text, id uuid, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone, metadata jsonb)
    LANGUAGE plpgsql
    AS $$
declare
    can_bypass_rls BOOLEAN;
begin
    SELECT rolbypassrls
    INTO can_bypass_rls
    FROM pg_roles
    WHERE rolname = coalesce(nullif(current_setting('role', true), 'none'), current_user);

    IF can_bypass_rls THEN
        RETURN QUERY SELECT * FROM storage.search_v1_optimised(prefix, bucketname, limits, levels, offsets, search, sortcolumn, sortorder);
    ELSE
        RETURN QUERY SELECT * FROM storage.search_legacy_v1(prefix, bucketname, limits, levels, offsets, search, sortcolumn, sortorder);
    END IF;
end;
$$;


--
-- Name: search_legacy_v1(text, text, integer, integer, integer, text, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.search_legacy_v1(prefix text, bucketname text, limits integer DEFAULT 100, levels integer DEFAULT 1, offsets integer DEFAULT 0, search text DEFAULT ''::text, sortcolumn text DEFAULT 'name'::text, sortorder text DEFAULT 'asc'::text) RETURNS TABLE(name text, id uuid, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone, metadata jsonb)
    LANGUAGE plpgsql STABLE
    AS $_$
declare
    v_order_by text;
    v_sort_order text;
begin
    case
        when sortcolumn = 'name' then
            v_order_by = 'name';
        when sortcolumn = 'updated_at' then
            v_order_by = 'updated_at';
        when sortcolumn = 'created_at' then
            v_order_by = 'created_at';
        when sortcolumn = 'last_accessed_at' then
            v_order_by = 'last_accessed_at';
        else
            v_order_by = 'name';
        end case;

    case
        when sortorder = 'asc' then
            v_sort_order = 'asc';
        when sortorder = 'desc' then
            v_sort_order = 'desc';
        else
            v_sort_order = 'asc';
        end case;

    v_order_by = v_order_by || ' ' || v_sort_order;

    return query execute
        'with folders as (
           select path_tokens[$1] as folder
           from storage.objects
             where objects.name ilike $2 || $3 || ''%''
               and bucket_id = $4
               and array_length(objects.path_tokens, 1) <> $1
           group by folder
           order by folder ' || v_sort_order || '
     )
     (select folder as "name",
            null as id,
            null as updated_at,
            null as created_at,
            null as last_accessed_at,
            null as metadata from folders)
     union all
     (select path_tokens[$1] as "name",
            id,
            updated_at,
            created_at,
            last_accessed_at,
            metadata
     from storage.objects
     where objects.name ilike $2 || $3 || ''%''
       and bucket_id = $4
       and array_length(objects.path_tokens, 1) = $1
     order by ' || v_order_by || ')
     limit $5
     offset $6' using levels, prefix, search, bucketname, limits, offsets;
end;
$_$;


--
-- Name: search_v1_optimised(text, text, integer, integer, integer, text, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.search_v1_optimised(prefix text, bucketname text, limits integer DEFAULT 100, levels integer DEFAULT 1, offsets integer DEFAULT 0, search text DEFAULT ''::text, sortcolumn text DEFAULT 'name'::text, sortorder text DEFAULT 'asc'::text) RETURNS TABLE(name text, id uuid, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone, metadata jsonb)
    LANGUAGE plpgsql STABLE
    AS $_$
declare
    v_order_by text;
    v_sort_order text;
begin
    case
        when sortcolumn = 'name' then
            v_order_by = 'name';
        when sortcolumn = 'updated_at' then
            v_order_by = 'updated_at';
        when sortcolumn = 'created_at' then
            v_order_by = 'created_at';
        when sortcolumn = 'last_accessed_at' then
            v_order_by = 'last_accessed_at';
        else
            v_order_by = 'name';
        end case;

    case
        when sortorder = 'asc' then
            v_sort_order = 'asc';
        when sortorder = 'desc' then
            v_sort_order = 'desc';
        else
            v_sort_order = 'asc';
        end case;

    v_order_by = v_order_by || ' ' || v_sort_order;

    return query execute
        'with folders as (
           select (string_to_array(name, ''/''))[level] as name
           from storage.prefixes
             where lower(prefixes.name) like lower($2 || $3) || ''%''
               and bucket_id = $4
               and level = $1
           order by name ' || v_sort_order || '
     )
     (select name,
            null as id,
            null as updated_at,
            null as created_at,
            null as last_accessed_at,
            null as metadata from folders)
     union all
     (select path_tokens[level] as "name",
            id,
            updated_at,
            created_at,
            last_accessed_at,
            metadata
     from storage.objects
     where lower(objects.name) like lower($2 || $3) || ''%''
       and bucket_id = $4
       and level = $1
     order by ' || v_order_by || ')
     limit $5
     offset $6' using levels, prefix, search, bucketname, limits, offsets;
end;
$_$;


--
-- Name: search_v2(text, text, integer, integer, text, text, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.search_v2(prefix text, bucket_name text, limits integer DEFAULT 100, levels integer DEFAULT 1, start_after text DEFAULT ''::text, sort_order text DEFAULT 'asc'::text, sort_column text DEFAULT 'name'::text, sort_column_after text DEFAULT ''::text) RETURNS TABLE(key text, name text, id uuid, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone, metadata jsonb)
    LANGUAGE plpgsql STABLE
    AS $_$
DECLARE
    sort_col text;
    sort_ord text;
    cursor_op text;
    cursor_expr text;
    sort_expr text;
BEGIN
    -- Validate sort_order
    sort_ord := lower(sort_order);
    IF sort_ord NOT IN ('asc', 'desc') THEN
        sort_ord := 'asc';
    END IF;

    -- Determine cursor comparison operator
    IF sort_ord = 'asc' THEN
        cursor_op := '>';
    ELSE
        cursor_op := '<';
    END IF;
    
    sort_col := lower(sort_column);
    -- Validate sort column  
    IF sort_col IN ('updated_at', 'created_at') THEN
        cursor_expr := format(
            '($5 = '''' OR ROW(date_trunc(''milliseconds'', %I), name COLLATE "C") %s ROW(COALESCE(NULLIF($6, '''')::timestamptz, ''epoch''::timestamptz), $5))',
            sort_col, cursor_op
        );
        sort_expr := format(
            'COALESCE(date_trunc(''milliseconds'', %I), ''epoch''::timestamptz) %s, name COLLATE "C" %s',
            sort_col, sort_ord, sort_ord
        );
    ELSE
        cursor_expr := format('($5 = '''' OR name COLLATE "C" %s $5)', cursor_op);
        sort_expr := format('name COLLATE "C" %s', sort_ord);
    END IF;

    RETURN QUERY EXECUTE format(
        $sql$
        SELECT * FROM (
            (
                SELECT
                    split_part(name, '/', $4) AS key,
                    name,
                    NULL::uuid AS id,
                    updated_at,
                    created_at,
                    NULL::timestamptz AS last_accessed_at,
                    NULL::jsonb AS metadata
                FROM storage.prefixes
                WHERE name COLLATE "C" LIKE $1 || '%%'
                    AND bucket_id = $2
                    AND level = $4
                    AND %s
                ORDER BY %s
                LIMIT $3
            )
            UNION ALL
            (
                SELECT
                    split_part(name, '/', $4) AS key,
                    name,
                    id,
                    updated_at,
                    created_at,
                    last_accessed_at,
                    metadata
                FROM storage.objects
                WHERE name COLLATE "C" LIKE $1 || '%%'
                    AND bucket_id = $2
                    AND level = $4
                    AND %s
                ORDER BY %s
                LIMIT $3
            )
        ) obj
        ORDER BY %s
        LIMIT $3
        $sql$,
        cursor_expr,    -- prefixes WHERE
        sort_expr,      -- prefixes ORDER BY
        cursor_expr,    -- objects WHERE
        sort_expr,      -- objects ORDER BY
        sort_expr       -- final ORDER BY
    )
    USING prefix, bucket_name, limits, levels, start_after, sort_column_after;
END;
$_$;


--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW; 
END;
$$;


--
-- Name: http_request(); Type: FUNCTION; Schema: supabase_functions; Owner: -
--

CREATE FUNCTION supabase_functions.http_request() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'supabase_functions'
    AS $$
    DECLARE
      request_id bigint;
      payload jsonb;
      url text := TG_ARGV[0]::text;
      method text := TG_ARGV[1]::text;
      headers jsonb DEFAULT '{}'::jsonb;
      params jsonb DEFAULT '{}'::jsonb;
      timeout_ms integer DEFAULT 1000;
    BEGIN
      IF url IS NULL OR url = 'null' THEN
        RAISE EXCEPTION 'url argument is missing';
      END IF;

      IF method IS NULL OR method = 'null' THEN
        RAISE EXCEPTION 'method argument is missing';
      END IF;

      IF TG_ARGV[2] IS NULL OR TG_ARGV[2] = 'null' THEN
        headers = '{"Content-Type": "application/json"}'::jsonb;
      ELSE
        headers = TG_ARGV[2]::jsonb;
      END IF;

      IF TG_ARGV[3] IS NULL OR TG_ARGV[3] = 'null' THEN
        params = '{}'::jsonb;
      ELSE
        params = TG_ARGV[3]::jsonb;
      END IF;

      IF TG_ARGV[4] IS NULL OR TG_ARGV[4] = 'null' THEN
        timeout_ms = 1000;
      ELSE
        timeout_ms = TG_ARGV[4]::integer;
      END IF;

      CASE
        WHEN method = 'GET' THEN
          SELECT http_get INTO request_id FROM net.http_get(
            url,
            params,
            headers,
            timeout_ms
          );
        WHEN method = 'POST' THEN
          payload = jsonb_build_object(
            'old_record', OLD,
            'record', NEW,
            'type', TG_OP,
            'table', TG_TABLE_NAME,
            'schema', TG_TABLE_SCHEMA
          );

          SELECT http_post INTO request_id FROM net.http_post(
            url,
            payload,
            params,
            headers,
            timeout_ms
          );
        ELSE
          RAISE EXCEPTION 'method argument % is invalid', method;
      END CASE;

      INSERT INTO supabase_functions.hooks
        (hook_table_id, hook_name, request_id)
      VALUES
        (TG_RELID, TG_NAME, request_id);

      RETURN NEW;
    END
  $$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: extensions; Type: TABLE; Schema: _realtime; Owner: -
--

CREATE TABLE _realtime.extensions (
    id uuid NOT NULL,
    type text,
    settings jsonb,
    tenant_external_id text,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: schema_migrations; Type: TABLE; Schema: _realtime; Owner: -
--

CREATE TABLE _realtime.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone
);


--
-- Name: tenants; Type: TABLE; Schema: _realtime; Owner: -
--

CREATE TABLE _realtime.tenants (
    id uuid NOT NULL,
    name text,
    external_id text,
    jwt_secret text,
    max_concurrent_users integer DEFAULT 200 NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    max_events_per_second integer DEFAULT 100 NOT NULL,
    postgres_cdc_default text DEFAULT 'postgres_cdc_rls'::text,
    max_bytes_per_second integer DEFAULT 100000 NOT NULL,
    max_channels_per_client integer DEFAULT 100 NOT NULL,
    max_joins_per_second integer DEFAULT 500 NOT NULL,
    suspend boolean DEFAULT false,
    jwt_jwks jsonb,
    notify_private_alpha boolean DEFAULT false,
    private_only boolean DEFAULT false NOT NULL,
    migrations_ran integer DEFAULT 0,
    broadcast_adapter character varying(255) DEFAULT 'gen_rpc'::character varying,
    max_presence_events_per_second integer DEFAULT 1000,
    max_payload_size_in_kb integer DEFAULT 3000
);


--
-- Name: audit_log_entries; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.audit_log_entries (
    instance_id uuid,
    id uuid NOT NULL,
    payload json,
    created_at timestamp with time zone,
    ip_address character varying(64) DEFAULT ''::character varying NOT NULL
);


--
-- Name: TABLE audit_log_entries; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.audit_log_entries IS 'Auth: Audit trail for user actions.';


--
-- Name: flow_state; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.flow_state (
    id uuid NOT NULL,
    user_id uuid,
    auth_code text NOT NULL,
    code_challenge_method auth.code_challenge_method NOT NULL,
    code_challenge text NOT NULL,
    provider_type text NOT NULL,
    provider_access_token text,
    provider_refresh_token text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    authentication_method text NOT NULL,
    auth_code_issued_at timestamp with time zone
);


--
-- Name: TABLE flow_state; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.flow_state IS 'stores metadata for pkce logins';


--
-- Name: identities; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.identities (
    provider_id text NOT NULL,
    user_id uuid NOT NULL,
    identity_data jsonb NOT NULL,
    provider text NOT NULL,
    last_sign_in_at timestamp with time zone,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    email text GENERATED ALWAYS AS (lower((identity_data ->> 'email'::text))) STORED,
    id uuid DEFAULT gen_random_uuid() NOT NULL
);


--
-- Name: TABLE identities; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.identities IS 'Auth: Stores identities associated to a user.';


--
-- Name: COLUMN identities.email; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.identities.email IS 'Auth: Email is a generated column that references the optional email property in the identity_data';


--
-- Name: instances; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.instances (
    id uuid NOT NULL,
    uuid uuid,
    raw_base_config text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone
);


--
-- Name: TABLE instances; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.instances IS 'Auth: Manages users across multiple sites.';


--
-- Name: mfa_amr_claims; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.mfa_amr_claims (
    session_id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    authentication_method text NOT NULL,
    id uuid NOT NULL
);


--
-- Name: TABLE mfa_amr_claims; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.mfa_amr_claims IS 'auth: stores authenticator method reference claims for multi factor authentication';


--
-- Name: mfa_challenges; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.mfa_challenges (
    id uuid NOT NULL,
    factor_id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    verified_at timestamp with time zone,
    ip_address inet NOT NULL,
    otp_code text,
    web_authn_session_data jsonb
);


--
-- Name: TABLE mfa_challenges; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.mfa_challenges IS 'auth: stores metadata about challenge requests made';


--
-- Name: mfa_factors; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.mfa_factors (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    friendly_name text,
    factor_type auth.factor_type NOT NULL,
    status auth.factor_status NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    secret text,
    phone text,
    last_challenged_at timestamp with time zone,
    web_authn_credential jsonb,
    web_authn_aaguid uuid,
    last_webauthn_challenge_data jsonb
);


--
-- Name: TABLE mfa_factors; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.mfa_factors IS 'auth: stores metadata about factors';


--
-- Name: COLUMN mfa_factors.last_webauthn_challenge_data; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.mfa_factors.last_webauthn_challenge_data IS 'Stores the latest WebAuthn challenge data including attestation/assertion for customer verification';


--
-- Name: oauth_authorizations; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.oauth_authorizations (
    id uuid NOT NULL,
    authorization_id text NOT NULL,
    client_id uuid NOT NULL,
    user_id uuid,
    redirect_uri text NOT NULL,
    scope text NOT NULL,
    state text,
    resource text,
    code_challenge text,
    code_challenge_method auth.code_challenge_method,
    response_type auth.oauth_response_type DEFAULT 'code'::auth.oauth_response_type NOT NULL,
    status auth.oauth_authorization_status DEFAULT 'pending'::auth.oauth_authorization_status NOT NULL,
    authorization_code text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone DEFAULT (now() + '00:03:00'::interval) NOT NULL,
    approved_at timestamp with time zone,
    nonce text,
    CONSTRAINT oauth_authorizations_authorization_code_length CHECK ((char_length(authorization_code) <= 255)),
    CONSTRAINT oauth_authorizations_code_challenge_length CHECK ((char_length(code_challenge) <= 128)),
    CONSTRAINT oauth_authorizations_expires_at_future CHECK ((expires_at > created_at)),
    CONSTRAINT oauth_authorizations_nonce_length CHECK ((char_length(nonce) <= 255)),
    CONSTRAINT oauth_authorizations_redirect_uri_length CHECK ((char_length(redirect_uri) <= 2048)),
    CONSTRAINT oauth_authorizations_resource_length CHECK ((char_length(resource) <= 2048)),
    CONSTRAINT oauth_authorizations_scope_length CHECK ((char_length(scope) <= 4096)),
    CONSTRAINT oauth_authorizations_state_length CHECK ((char_length(state) <= 4096))
);


--
-- Name: oauth_client_states; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.oauth_client_states (
    id uuid NOT NULL,
    provider_type text NOT NULL,
    code_verifier text,
    created_at timestamp with time zone NOT NULL
);


--
-- Name: TABLE oauth_client_states; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.oauth_client_states IS 'Stores OAuth states for third-party provider authentication flows where Supabase acts as the OAuth client.';


--
-- Name: oauth_clients; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.oauth_clients (
    id uuid NOT NULL,
    client_secret_hash text,
    registration_type auth.oauth_registration_type NOT NULL,
    redirect_uris text NOT NULL,
    grant_types text NOT NULL,
    client_name text,
    client_uri text,
    logo_uri text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    client_type auth.oauth_client_type DEFAULT 'confidential'::auth.oauth_client_type NOT NULL,
    CONSTRAINT oauth_clients_client_name_length CHECK ((char_length(client_name) <= 1024)),
    CONSTRAINT oauth_clients_client_uri_length CHECK ((char_length(client_uri) <= 2048)),
    CONSTRAINT oauth_clients_logo_uri_length CHECK ((char_length(logo_uri) <= 2048))
);


--
-- Name: oauth_consents; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.oauth_consents (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    client_id uuid NOT NULL,
    scopes text NOT NULL,
    granted_at timestamp with time zone DEFAULT now() NOT NULL,
    revoked_at timestamp with time zone,
    CONSTRAINT oauth_consents_revoked_after_granted CHECK (((revoked_at IS NULL) OR (revoked_at >= granted_at))),
    CONSTRAINT oauth_consents_scopes_length CHECK ((char_length(scopes) <= 2048)),
    CONSTRAINT oauth_consents_scopes_not_empty CHECK ((char_length(TRIM(BOTH FROM scopes)) > 0))
);


--
-- Name: one_time_tokens; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.one_time_tokens (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    token_type auth.one_time_token_type NOT NULL,
    token_hash text NOT NULL,
    relates_to text NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    CONSTRAINT one_time_tokens_token_hash_check CHECK ((char_length(token_hash) > 0))
);


--
-- Name: refresh_tokens; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.refresh_tokens (
    instance_id uuid,
    id bigint NOT NULL,
    token character varying(255),
    user_id character varying(255),
    revoked boolean,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    parent character varying(255),
    session_id uuid
);


--
-- Name: TABLE refresh_tokens; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.refresh_tokens IS 'Auth: Store of tokens used to refresh JWT tokens once they expire.';


--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE; Schema: auth; Owner: -
--

CREATE SEQUENCE auth.refresh_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: auth; Owner: -
--

ALTER SEQUENCE auth.refresh_tokens_id_seq OWNED BY auth.refresh_tokens.id;


--
-- Name: saml_providers; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.saml_providers (
    id uuid NOT NULL,
    sso_provider_id uuid NOT NULL,
    entity_id text NOT NULL,
    metadata_xml text NOT NULL,
    metadata_url text,
    attribute_mapping jsonb,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    name_id_format text,
    CONSTRAINT "entity_id not empty" CHECK ((char_length(entity_id) > 0)),
    CONSTRAINT "metadata_url not empty" CHECK (((metadata_url = NULL::text) OR (char_length(metadata_url) > 0))),
    CONSTRAINT "metadata_xml not empty" CHECK ((char_length(metadata_xml) > 0))
);


--
-- Name: TABLE saml_providers; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.saml_providers IS 'Auth: Manages SAML Identity Provider connections.';


--
-- Name: saml_relay_states; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.saml_relay_states (
    id uuid NOT NULL,
    sso_provider_id uuid NOT NULL,
    request_id text NOT NULL,
    for_email text,
    redirect_to text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    flow_state_id uuid,
    CONSTRAINT "request_id not empty" CHECK ((char_length(request_id) > 0))
);


--
-- Name: TABLE saml_relay_states; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.saml_relay_states IS 'Auth: Contains SAML Relay State information for each Service Provider initiated login.';


--
-- Name: schema_migrations; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.schema_migrations (
    version character varying(255) NOT NULL
);


--
-- Name: TABLE schema_migrations; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.schema_migrations IS 'Auth: Manages updates to the auth system.';


--
-- Name: sessions; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.sessions (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    factor_id uuid,
    aal auth.aal_level,
    not_after timestamp with time zone,
    refreshed_at timestamp without time zone,
    user_agent text,
    ip inet,
    tag text,
    oauth_client_id uuid,
    refresh_token_hmac_key text,
    refresh_token_counter bigint,
    scopes text,
    CONSTRAINT sessions_scopes_length CHECK ((char_length(scopes) <= 4096))
);


--
-- Name: TABLE sessions; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.sessions IS 'Auth: Stores session data associated to a user.';


--
-- Name: COLUMN sessions.not_after; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.sessions.not_after IS 'Auth: Not after is a nullable column that contains a timestamp after which the session should be regarded as expired.';


--
-- Name: COLUMN sessions.refresh_token_hmac_key; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.sessions.refresh_token_hmac_key IS 'Holds a HMAC-SHA256 key used to sign refresh tokens for this session.';


--
-- Name: COLUMN sessions.refresh_token_counter; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.sessions.refresh_token_counter IS 'Holds the ID (counter) of the last issued refresh token.';


--
-- Name: sso_domains; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.sso_domains (
    id uuid NOT NULL,
    sso_provider_id uuid NOT NULL,
    domain text NOT NULL,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    CONSTRAINT "domain not empty" CHECK ((char_length(domain) > 0))
);


--
-- Name: TABLE sso_domains; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.sso_domains IS 'Auth: Manages SSO email address domain mapping to an SSO Identity Provider.';


--
-- Name: sso_providers; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.sso_providers (
    id uuid NOT NULL,
    resource_id text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    disabled boolean,
    CONSTRAINT "resource_id not empty" CHECK (((resource_id = NULL::text) OR (char_length(resource_id) > 0)))
);


--
-- Name: TABLE sso_providers; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.sso_providers IS 'Auth: Manages SSO identity provider information; see saml_providers for SAML.';


--
-- Name: COLUMN sso_providers.resource_id; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.sso_providers.resource_id IS 'Auth: Uniquely identifies a SSO provider according to a user-chosen resource ID (case insensitive), useful in infrastructure as code.';


--
-- Name: users; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.users (
    instance_id uuid,
    id uuid NOT NULL,
    aud character varying(255),
    role character varying(255),
    email character varying(255),
    encrypted_password character varying(255),
    email_confirmed_at timestamp with time zone,
    invited_at timestamp with time zone,
    confirmation_token character varying(255),
    confirmation_sent_at timestamp with time zone,
    recovery_token character varying(255),
    recovery_sent_at timestamp with time zone,
    email_change_token_new character varying(255),
    email_change character varying(255),
    email_change_sent_at timestamp with time zone,
    last_sign_in_at timestamp with time zone,
    raw_app_meta_data jsonb,
    raw_user_meta_data jsonb,
    is_super_admin boolean,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    phone text DEFAULT NULL::character varying,
    phone_confirmed_at timestamp with time zone,
    phone_change text DEFAULT ''::character varying,
    phone_change_token character varying(255) DEFAULT ''::character varying,
    phone_change_sent_at timestamp with time zone,
    confirmed_at timestamp with time zone GENERATED ALWAYS AS (LEAST(email_confirmed_at, phone_confirmed_at)) STORED,
    email_change_token_current character varying(255) DEFAULT ''::character varying,
    email_change_confirm_status smallint DEFAULT 0,
    banned_until timestamp with time zone,
    reauthentication_token character varying(255) DEFAULT ''::character varying,
    reauthentication_sent_at timestamp with time zone,
    is_sso_user boolean DEFAULT false NOT NULL,
    deleted_at timestamp with time zone,
    is_anonymous boolean DEFAULT false NOT NULL,
    CONSTRAINT users_email_change_confirm_status_check CHECK (((email_change_confirm_status >= 0) AND (email_change_confirm_status <= 2)))
);


--
-- Name: TABLE users; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.users IS 'Auth: Stores user login data within a secure schema.';


--
-- Name: COLUMN users.is_sso_user; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.users.is_sso_user IS 'Auth: Set this column to true when the account comes from SSO. These accounts can have duplicate emails.';


--
-- Name: actuaciones_control_guardaparques; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.actuaciones_control_guardaparques (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    fecha date,
    tipo_de_acta text,
    n_acta text,
    departamento_id uuid,
    municipio_id uuid,
    latitud_decimal numeric,
    longitud_decimal numeric,
    latitud_dms text,
    longitud_dms text,
    actuante text,
    infractor text,
    n_dni text,
    elementos_secuestrados text,
    animales text,
    elementos_sec_movilidad text,
    actividad text,
    observaciones text,
    created_at timestamp with time zone DEFAULT now(),
    created_by uuid DEFAULT auth.uid(),
    user_id uuid DEFAULT auth.uid(),
    formulario_id uuid DEFAULT '48efcd89-3298-4951-8648-1263ed85b4a2'::uuid,
    activo boolean DEFAULT true,
    geom public.geometry(Point,4326),
    updated_at timestamp with time zone DEFAULT now()
);

ALTER TABLE ONLY public.actuaciones_control_guardaparques REPLICA IDENTITY FULL;


--
-- Name: almidoneras; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.almidoneras (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    n_orden text,
    n_expediente text,
    empresa text,
    latitud_decimal numeric,
    longitud_decimal numeric,
    latitud_dms text,
    longitud_dms text,
    municipio_id uuid,
    sistema_tratamiento text,
    tipo text,
    operativo boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    created_by uuid DEFAULT auth.uid(),
    user_id uuid DEFAULT auth.uid(),
    formulario_id uuid DEFAULT 'af15cfcd-6d12-43eb-8666-0c83e8b7b60c'::uuid,
    activo boolean DEFAULT true,
    geom public.geometry(Point,4326),
    updated_at timestamp with time zone DEFAULT now(),
    departamento_id uuid
);

ALTER TABLE ONLY public.almidoneras REPLICA IDENTITY FULL;


--
-- Name: aprovechamiento_pfnm; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.aprovechamiento_pfnm (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    user_id uuid DEFAULT auth.uid(),
    created_by uuid DEFAULT auth.uid(),
    formulario_id uuid DEFAULT 'e0fc4fc7-19c8-44b5-9759-4dbf629b8d88'::uuid,
    latitud_decimal double precision,
    longitud_decimal double precision,
    latitud_dms text,
    longitud_dms text,
    geom public.geometry(Point,4326),
    updated_at timestamp with time zone DEFAULT now(),
    activo boolean DEFAULT true,
    departamento_id uuid,
    municipio_id uuid,
    nro_orden numeric,
    nro_expediente numeric,
    fecha_ingreso_departamento date,
    producto text,
    ubicacion text,
    persona text,
    cantidad numeric,
    unidad_medida_id uuid,
    destino text,
    autorizacion text,
    nro_guia numeric,
    fecha_vencimiento date,
    estado_tramite_id uuid
);


--
-- Name: areas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.areas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    key text NOT NULL,
    nombre text NOT NULL,
    descripcion text,
    activo boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: areas_naturales_protegidas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.areas_naturales_protegidas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre_anp text,
    destacamentos_guardaparques integer DEFAULT 0,
    departamento_id uuid,
    municipio_id uuid,
    latitud_decimal numeric,
    longitud_decimal numeric,
    latitud_dms text,
    longitud_dms text,
    nomenclatura_catastral text,
    fecha_creacion date,
    fecha_caducidad date,
    n_ley_decreto_creacion text,
    titular text,
    superficie text,
    sup_cat_i text,
    sup_cat_ii text,
    tuvo_modificacion_sup boolean DEFAULT false,
    fecha_modificacion date,
    sup_final_mensura_ha numeric,
    sup_cat_i_final text,
    plan_de_manejo text,
    observaciones text,
    created_at timestamp with time zone DEFAULT now(),
    created_by uuid DEFAULT auth.uid(),
    user_id uuid DEFAULT auth.uid(),
    formulario_id uuid DEFAULT 'e292142a-3cf3-420f-b087-cc8bebc5f02b'::uuid,
    activo boolean DEFAULT true,
    geom public.geometry(Point,4326),
    updated_at timestamp with time zone DEFAULT now()
);

ALTER TABLE ONLY public.areas_naturales_protegidas REPLICA IDENTITY FULL;


--
-- Name: aspectos_sanitarios; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.aspectos_sanitarios (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre text NOT NULL,
    activo boolean DEFAULT true,
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: ataques_grandes_felinos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ataques_grandes_felinos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    n_orden integer,
    n_expediente_acta_id text,
    fecha date,
    latitud_decimal numeric,
    latitud_dms text,
    longitud_decimal numeric,
    longitud_dms text,
    ubicacion text,
    departamento_id uuid,
    municipio_id uuid,
    propietario text,
    dni bigint,
    felino text,
    constancia_policial boolean DEFAULT false,
    constatacion_meyrn text,
    nro_constatacion text,
    estado_acta_expediente text,
    observaciones text,
    formulario_id uuid DEFAULT 'd5f4de58-7805-4d64-a0ef-19bf0dd9e1a5'::uuid,
    user_id uuid DEFAULT auth.uid(),
    created_by uuid,
    created_at timestamp with time zone DEFAULT now(),
    geom public.geometry(Point,4326),
    activo boolean DEFAULT true,
    updated_at timestamp with time zone DEFAULT now()
);

ALTER TABLE ONLY public.ataques_grandes_felinos REPLICA IDENTITY FULL;


--
-- Name: atropellamiento_fauna_silvestre; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.atropellamiento_fauna_silvestre (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    n_orden integer,
    fecha date DEFAULT CURRENT_DATE,
    latitud_decimal numeric,
    latitud_dms text,
    longitud_decimal numeric,
    longitud_dms text,
    ubicacion text,
    departamento_id uuid,
    municipio_id uuid,
    observador_interventor text,
    tipo_denuncia text,
    animal text,
    nombre_cientifico text,
    observaciones text,
    created_at timestamp with time zone DEFAULT now(),
    created_by uuid DEFAULT auth.uid(),
    user_id uuid DEFAULT auth.uid(),
    formulario_id uuid DEFAULT 'e50643c0-a434-4706-bba0-c6044f73fc3d'::uuid,
    geom public.geometry(Point,4326),
    activo boolean DEFAULT true,
    updated_at timestamp with time zone DEFAULT now()
);

ALTER TABLE ONLY public.atropellamiento_fauna_silvestre REPLICA IDENTITY FULL;


--
-- Name: avistamiento_axis; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.avistamiento_axis (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    n_orden text,
    fecha date DEFAULT CURRENT_DATE,
    lugar text,
    latitud_decimal numeric,
    longitud_decimal numeric,
    latitud_dms text,
    longitud_dms text,
    municipio_id uuid,
    observador_interventor text,
    tipo_denuncia text,
    avistaje_positivo boolean DEFAULT true,
    observaciones text,
    created_at timestamp with time zone DEFAULT now(),
    created_by uuid DEFAULT auth.uid(),
    user_id uuid DEFAULT auth.uid(),
    formulario_id uuid DEFAULT '57bf44c7-1102-45b2-865d-f76a1f091ec3'::uuid,
    tipo_avistaje text,
    activo boolean DEFAULT true,
    geom public.geometry(Point,4326),
    updated_at timestamp with time zone DEFAULT now(),
    departamento_id uuid
);

ALTER TABLE ONLY public.avistamiento_axis REPLICA IDENTITY FULL;


--
-- Name: camaras_trampas_anp; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.camaras_trampas_anp (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    parque_provincial text,
    zona text,
    latitud_decimal numeric,
    latitud_dms text,
    longitud_decimal numeric,
    longitud_dms text,
    departamento_id uuid,
    municipio_id uuid,
    tipo_camara_trampa text,
    cantidad integer DEFAULT 1,
    guardaparques_cargo text,
    observaciones text,
    formulario_id uuid DEFAULT 'b0088506-c8be-40ae-8729-2b655ab836b7'::uuid,
    user_id uuid DEFAULT auth.uid(),
    created_by uuid DEFAULT auth.uid(),
    created_at timestamp with time zone DEFAULT now(),
    geom public.geometry(Point,4326),
    activo boolean DEFAULT true,
    updated_at timestamp with time zone DEFAULT now()
);

ALTER TABLE ONLY public.camaras_trampas_anp REPLICA IDENTITY FULL;


--
-- Name: carnet_pesca_deportiva; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.carnet_pesca_deportiva (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    user_id uuid DEFAULT auth.uid(),
    created_by uuid DEFAULT auth.uid(),
    formulario_id uuid DEFAULT '73d5d7e2-a535-4940-9512-dcb435ff460a'::uuid,
    latitud_decimal double precision,
    longitud_decimal double precision,
    latitud_dms text,
    longitud_dms text,
    geom public.geometry(Point,4326),
    updated_at timestamp with time zone DEFAULT now(),
    activo boolean DEFAULT true,
    departamento_id uuid,
    municipio_id uuid,
    numero numeric,
    identificacion text,
    nombre text,
    dni numeric,
    delegacion_id uuid,
    categoria_id uuid,
    fecha date,
    estado_carnet_id uuid,
    "Provincia" text,
    "Pais" text,
    "Categoria" text,
    "Mes" text,
    "Ano" numeric
);


--
-- Name: carnet_pesca_subsistencia_comercial; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.carnet_pesca_subsistencia_comercial (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    user_id uuid DEFAULT auth.uid(),
    created_by uuid DEFAULT auth.uid(),
    formulario_id uuid DEFAULT 'a2b1c3d4-e5f6-4789-b0c1-d2e3f4a5b6c7'::uuid,
    latitud_decimal double precision,
    longitud_decimal double precision,
    latitud_dms text,
    longitud_dms text,
    geom public.geometry(Point,4326),
    updated_at timestamp with time zone DEFAULT now(),
    activo boolean DEFAULT true,
    departamento_id uuid,
    municipio_id uuid,
    nro_orden numeric,
    nro_id text,
    nombre text,
    dni numeric,
    municipio_relacion_id uuid,
    direccion text,
    zona_pesca text,
    nro_cbu numeric,
    estado_carnet_id uuid
);


--
-- Name: categorias_carnet_pesca_deportiva; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.categorias_carnet_pesca_deportiva (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre text NOT NULL,
    activo boolean DEFAULT true
);


--
-- Name: caza_furtiva; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.caza_furtiva (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    fecha date DEFAULT CURRENT_DATE,
    latitud_decimal numeric,
    latitud_dms text,
    longitud_decimal numeric,
    longitud_dms text,
    lugar text,
    departamento_id uuid,
    municipio_id uuid,
    anp text,
    terrenos_privados boolean DEFAULT false,
    intervencion text,
    cantidad_cazadores integer DEFAULT 0,
    elementos_secuestrados text,
    formulario_id uuid DEFAULT '3c675f9e-81df-44c8-aa39-7d81d3eac4cd'::uuid,
    user_id uuid DEFAULT auth.uid(),
    created_by uuid DEFAULT auth.uid(),
    created_at timestamp with time zone DEFAULT now(),
    geom public.geometry(Point,4326),
    activo boolean DEFAULT true,
    observaciones text,
    updated_at timestamp with time zone DEFAULT now()
);

ALTER TABLE ONLY public.caza_furtiva REPLICA IDENTITY FULL;


--
-- Name: centros_manejo_fauna; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.centros_manejo_fauna (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    user_id uuid DEFAULT auth.uid(),
    created_by uuid DEFAULT auth.uid(),
    formulario_id uuid DEFAULT '0a5a5853-7d59-43b9-88e1-f7fb9de38733'::uuid,
    latitud_decimal double precision,
    longitud_decimal double precision,
    latitud_dms text,
    longitud_dms text,
    geom public.geometry(Point,4326),
    updated_at timestamp with time zone DEFAULT now(),
    activo boolean DEFAULT true,
    departamento_id uuid,
    municipio_id uuid,
    numero numeric,
    nombre text,
    ubicacion text,
    propietario text,
    responsables text,
    contacto text,
    especies text,
    estado text,
    destino_final text
);


--
-- Name: control_forestal; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.control_forestal (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nro_operativo text,
    anio integer,
    fecha date,
    tipo_actividad text,
    departamento_id uuid,
    municipio_id uuid,
    latitud_decimal numeric,
    longitud_decimal numeric,
    latitud_dms text,
    longitud_dms text,
    km_recorridos numeric DEFAULT 0,
    detalle_actuacion text,
    acta_constatacion text,
    origen_denuncia text,
    resultado_operativo text,
    caucion text,
    depositario text,
    expediente_id_nro text,
    predio_apto_deposito text,
    created_at timestamp with time zone DEFAULT now(),
    created_by uuid DEFAULT auth.uid(),
    user_id uuid DEFAULT auth.uid(),
    formulario_id uuid DEFAULT '00ad87b2-a9a1-44e1-b292-f9a15d091352'::uuid,
    activo boolean DEFAULT true,
    geom public.geometry(Point,4326),
    updated_at timestamp with time zone DEFAULT now()
);

ALTER TABLE ONLY public.control_forestal REPLICA IDENTITY FULL;


--
-- Name: criadero_fauna_silvestre; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.criadero_fauna_silvestre (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    n_orden integer,
    n_expediente text,
    objetivo text,
    establecimiento text,
    apellido_nombre text,
    dni bigint,
    direccion text,
    contacto text,
    latitud_decimal numeric,
    latitud_dms text,
    longitud_decimal numeric,
    longitud_dms text,
    departamento_id uuid,
    municipio_id uuid,
    especie text,
    nombre_vulgar text,
    cantidad_total integer DEFAULT 0,
    tenencia_a_la_fecha integer DEFAULT 0,
    estado_renovacion_2025 text,
    ultima_fecha_inspeccion date,
    acta_constatacion boolean DEFAULT false,
    observaciones text,
    formulario_id uuid DEFAULT 'e56c3edb-fc02-44d2-ab05-c4c9d5d448c1'::uuid,
    user_id uuid DEFAULT auth.uid(),
    created_by uuid DEFAULT auth.uid(),
    created_at timestamp with time zone DEFAULT now(),
    geom public.geometry(Point,4326),
    activo boolean DEFAULT true,
    updated_at timestamp with time zone DEFAULT now()
);

ALTER TABLE ONLY public.criadero_fauna_silvestre REPLICA IDENTITY FULL;


--
-- Name: departamentos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.departamentos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    codigo integer NOT NULL,
    nombre text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    activo boolean DEFAULT true,
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: destino_rehabilitacion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.destino_rehabilitacion (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre text NOT NULL
);


--
-- Name: entrega_alevines; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.entrega_alevines (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    user_id uuid DEFAULT auth.uid(),
    created_by uuid DEFAULT auth.uid(),
    formulario_id uuid DEFAULT 'f8e78190-ca79-4404-a0c5-cc907d36b2fc'::uuid,
    latitud_decimal numeric,
    longitud_decimal numeric,
    latitud_dms text,
    longitud_dms text,
    geom public.geometry(Point,4326),
    updated_at timestamp with time zone DEFAULT now(),
    n_orden integer NOT NULL,
    activo boolean DEFAULT true,
    fecha date DEFAULT CURRENT_DATE,
    departamento_id uuid,
    municipio_id uuid,
    receptor text,
    lugar_entrega text,
    total_alevines integer DEFAULT 0,
    n_productores_beneficiados integer DEFAULT 0,
    myleus_pacu integer DEFAULT 0,
    prochilodus_lineatus_sabalo integer DEFAULT 0,
    boops_boops_boga integer DEFAULT 0
);


--
-- Name: entrega_alevines_n_orden_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.entrega_alevines_n_orden_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: entrega_alevines_n_orden_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.entrega_alevines_n_orden_seq OWNED BY public.entrega_alevines.n_orden;


--
-- Name: estados_aprovechamiento; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.estados_aprovechamiento (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre text NOT NULL,
    activo boolean DEFAULT true
);


--
-- Name: estados_carnet_pesca; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.estados_carnet_pesca (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre text NOT NULL,
    activo boolean DEFAULT true
);


--
-- Name: estados_conservacion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.estados_conservacion (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre text NOT NULL,
    activo boolean DEFAULT true
);


--
-- Name: estados_tramite_honorario; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.estados_tramite_honorario (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre text NOT NULL,
    activo boolean DEFAULT true
);


--
-- Name: exoticas_invasoras; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.exoticas_invasoras (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    user_id uuid DEFAULT auth.uid(),
    created_by uuid DEFAULT auth.uid(),
    formulario_id uuid DEFAULT '77313e42-53f5-4c24-9320-5c27d2ca6fe2'::uuid,
    latitud_decimal double precision,
    longitud_decimal double precision,
    latitud_dms text,
    longitud_dms text,
    geom public.geometry(Point,4326),
    updated_at timestamp with time zone DEFAULT now(),
    activo boolean DEFAULT true,
    departamento_id uuid,
    municipio_id uuid,
    nro_orden numeric,
    nombre_cientifico text,
    nombre_vulgar text
);


--
-- Name: expedientes_impacto_ambiental; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.expedientes_impacto_ambiental (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    numero integer,
    codigo_organismo text,
    nro_expte text NOT NULL,
    anio_expte integer,
    fecha_creacion_expte date,
    proponente text,
    cuit_cuil text,
    asunto text,
    fecha_dispositivo date,
    nro_resolucion text,
    tipo_vad_vap text,
    tipo_actividad text,
    dominio text,
    codigo_municipio integer,
    municipio_id uuid,
    nomenclatura_catastral text,
    observaciones text,
    consultor_designado text,
    formulario_id uuid DEFAULT '2e2ba354-d6bd-4b89-8a50-1b344ab78edd'::uuid NOT NULL,
    user_id uuid,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now(),
    latitud_decimal numeric,
    longitud_decimal numeric,
    latitud_dms text,
    longitud_dms text,
    estado_expte text,
    ultimo_movimiento text,
    inspeccion_campo boolean DEFAULT false,
    geom public.geometry(Point,4326),
    activo boolean DEFAULT true,
    updated_at timestamp with time zone DEFAULT now(),
    departamento_id uuid
);

ALTER TABLE ONLY public.expedientes_impacto_ambiental REPLICA IDENTITY FULL;


--
-- Name: feedlots; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.feedlots (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    n_orden text,
    n_expediente_impacto_ambiental text,
    proponente text,
    tipo_actividad text,
    latitud_decimal numeric,
    longitud_decimal numeric,
    latitud_dms text,
    longitud_dms text,
    municipio_id uuid,
    sistema_tratamiento text,
    tipo text,
    operativo boolean DEFAULT true,
    viabilidad_ambiental_definitiva text,
    created_at timestamp with time zone DEFAULT now(),
    created_by uuid DEFAULT auth.uid(),
    user_id uuid DEFAULT auth.uid(),
    formulario_id uuid DEFAULT 'c3d4e5f6-a7b8-4c9d-e0f1-a2b3c4d5e6f7'::uuid,
    activo boolean DEFAULT true,
    geom public.geometry(Point,4326),
    updated_at timestamp with time zone DEFAULT now(),
    departamento_id uuid
);

ALTER TABLE ONLY public.feedlots REPLICA IDENTITY FULL;


--
-- Name: fitosanitarios_domisanitarios; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fitosanitarios_domisanitarios (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    user_id uuid DEFAULT auth.uid(),
    created_by uuid DEFAULT auth.uid(),
    formulario_id uuid DEFAULT '9a5c03c7-6d4b-451f-b649-8f81c947f284'::uuid,
    latitud_decimal double precision,
    longitud_decimal double precision,
    latitud_dms text,
    longitud_dms text,
    geom public.geometry(Point,4326),
    updated_at timestamp with time zone DEFAULT now(),
    activo boolean DEFAULT true,
    departamento_id uuid,
    municipio_id uuid,
    orden numeric,
    empresa text,
    tipo_id uuid,
    nro_registro numeric,
    actividades text,
    direccion text,
    anio_pago_registro numeric
);


--
-- Name: formularios; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.formularios (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    area_id uuid NOT NULL,
    nombre text NOT NULL,
    descripcion text,
    slug text NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: frigorificos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.frigorificos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    n_orden text,
    n_expediente_impacto_ambiental text,
    n_expediente_recursos_vitales text,
    empresa text,
    tipo_actividad text,
    latitud_decimal numeric,
    longitud_decimal numeric,
    latitud_dms text,
    longitud_dms text,
    municipio_id uuid,
    sistema_tratamiento text,
    tipo text,
    operativo boolean DEFAULT true,
    viabilidad_ambiental_definitiva text,
    camara_extraccion_muestras text,
    created_at timestamp with time zone DEFAULT now(),
    created_by uuid DEFAULT auth.uid(),
    user_id uuid DEFAULT auth.uid(),
    formulario_id uuid DEFAULT '435cd4ca-afea-4bd1-a6b7-c95391fc78ff'::uuid,
    activo boolean DEFAULT true,
    geom public.geometry(Point,4326),
    updated_at timestamp with time zone DEFAULT now(),
    departamento_id uuid
);

ALTER TABLE ONLY public.frigorificos REPLICA IDENTITY FULL;


--
-- Name: guardafauna_honorario; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.guardafauna_honorario (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    user_id uuid DEFAULT auth.uid(),
    created_by uuid DEFAULT auth.uid(),
    formulario_id uuid DEFAULT '94b1c2d5-5222-4803-b733-84445e5ca3e3'::uuid,
    latitud_decimal double precision,
    longitud_decimal double precision,
    latitud_dms text,
    longitud_dms text,
    geom public.geometry(Point,4326),
    updated_at timestamp with time zone DEFAULT now(),
    activo boolean DEFAULT true,
    departamento_id uuid,
    municipio_id uuid,
    nro_orden numeric,
    nro_expediente text,
    nombre_apellido text,
    dni numeric,
    domicilio text,
    telefono text,
    correo_electronico text,
    anio_vigente numeric,
    estado_tramite_id uuid,
    otorga text,
    fecha_vigencia date,
    dispositivo_legal text,
    observaciones text
);


--
-- Name: maestro_especies_tipo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.maestro_especies_tipo (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre text NOT NULL
);


--
-- Name: maestro_meses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.maestro_meses (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre text NOT NULL,
    orden integer
);


--
-- Name: mapa_cauciones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mapa_cauciones (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    user_id uuid DEFAULT auth.uid(),
    created_by uuid DEFAULT auth.uid(),
    formulario_id uuid DEFAULT '8d38431b-a5f1-4c07-9cbf-91bea5f744b7'::uuid,
    latitud_decimal double precision,
    longitud_decimal double precision,
    latitud_dms text,
    longitud_dms text,
    geom public.geometry(Point,4326),
    updated_at timestamp with time zone DEFAULT now(),
    activo boolean DEFAULT true,
    departamento_id uuid,
    municipio_id uuid
);


--
-- Name: mascotismo_ilegal; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mascotismo_ilegal (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    n_orden integer,
    fecha date DEFAULT CURRENT_DATE,
    latitud_decimal numeric,
    latitud_dms text,
    longitud_decimal numeric,
    longitud_dms text,
    lugar text,
    departamento_id uuid,
    municipio_id uuid,
    intervencion text,
    procedencia_id uuid,
    causa_ingreso text,
    tipo_animales text,
    crfs text,
    aspecto_sanitario_id uuid,
    aspectos_etologicos text,
    liberado boolean DEFAULT false,
    formulario_id uuid DEFAULT 'cb42bd28-3233-4d6e-ade6-b942cbc686b5'::uuid,
    user_id uuid DEFAULT auth.uid(),
    created_by uuid DEFAULT auth.uid(),
    created_at timestamp with time zone DEFAULT now(),
    geom public.geometry(Point,4326),
    activo boolean DEFAULT true,
    updated_at timestamp with time zone DEFAULT now()
);

ALTER TABLE ONLY public.mascotismo_ilegal REPLICA IDENTITY FULL;


--
-- Name: mataderos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mataderos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    n_orden text,
    n_expediente_impacto_ambiental text,
    n_expediente_recursos_vitales text,
    municipal boolean DEFAULT false,
    tipo_actividad text,
    latitud_decimal numeric,
    longitud_decimal numeric,
    latitud_dms text,
    longitud_dms text,
    municipio_id uuid,
    sistema_tratamiento text,
    tipo text,
    operativo boolean DEFAULT true,
    viabilidad_ambiental_definitiva text,
    created_at timestamp with time zone DEFAULT now(),
    created_by uuid DEFAULT auth.uid(),
    user_id uuid DEFAULT auth.uid(),
    formulario_id uuid DEFAULT 'b2a1c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d'::uuid,
    activo boolean DEFAULT true,
    geom public.geometry(Point,4326),
    updated_at timestamp with time zone DEFAULT now(),
    departamento_id uuid
);

ALTER TABLE ONLY public.mataderos REPLICA IDENTITY FULL;


--
-- Name: mobile_apps; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mobile_apps (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    formulario_slug text NOT NULL,
    nombre text NOT NULL,
    descripcion text,
    version text DEFAULT '1.0.0'::text,
    apk_path text NOT NULL,
    activo boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: monos_aulladores; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.monos_aulladores (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    user_id uuid DEFAULT auth.uid(),
    created_by uuid DEFAULT auth.uid(),
    formulario_id uuid DEFAULT '4b4d6e5d-3f62-49d4-93b4-c896ca81adf0'::uuid,
    latitud_decimal double precision,
    longitud_decimal double precision,
    latitud_dms text,
    longitud_dms text,
    geom public.geometry(Point,4326),
    updated_at timestamp with time zone DEFAULT now(),
    activo boolean DEFAULT true,
    departamento_id uuid,
    municipio_id uuid,
    nro_orden numeric,
    localidad_sitio text,
    especie text,
    fecha_registro date,
    tipo_registro text,
    observador text,
    observaciones text
);


--
-- Name: monumentos_naturales_provinciales; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.monumentos_naturales_provinciales (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    user_id uuid DEFAULT auth.uid(),
    created_by uuid DEFAULT auth.uid(),
    formulario_id uuid DEFAULT 'd29ce3b4-013d-4d43-b7f5-14c9fbb614e6'::uuid,
    latitud_decimal double precision,
    longitud_decimal double precision,
    latitud_dms text,
    longitud_dms text,
    geom public.geometry(Point,4326),
    updated_at timestamp with time zone DEFAULT now(),
    activo boolean DEFAULT true,
    departamento_id uuid,
    municipio_id uuid,
    nro_orden numeric,
    nro_ley text,
    especie text,
    nombre_vulgar text,
    estado_conservacion_provincial_id uuid,
    localidad text,
    estado_conservacion_nacional_id uuid,
    estado_conservacion_internacional_id uuid,
    tiene_gps boolean DEFAULT false,
    enlaces_caracteristicas text
);


--
-- Name: municipios; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.municipios (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre text NOT NULL,
    latitud_geografica double precision,
    longitud_geografica double precision,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    codigo_municipio integer,
    departamento_id uuid,
    activo boolean DEFAULT true,
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: origen_rehabilitacion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.origen_rehabilitacion (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre text NOT NULL
);


--
-- Name: perforaciones_constatadas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.perforaciones_constatadas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    user_id uuid DEFAULT auth.uid(),
    created_by uuid DEFAULT auth.uid(),
    formulario_id uuid DEFAULT 'c8d4f619-a23e-49b0-8893-7342a989cac8'::uuid,
    latitud_decimal double precision,
    longitud_decimal double precision,
    latitud_dms text,
    longitud_dms text,
    geom public.geometry(Point,4326),
    updated_at timestamp with time zone DEFAULT now(),
    activo boolean DEFAULT true,
    departamento_id uuid,
    municipio_id uuid,
    nro_acta numeric,
    razon_social text,
    actividad text,
    cant_perforaciones numeric,
    telefono text,
    correo_electronico text,
    nro_expte text,
    nro_registro text
);


--
-- Name: perforaciones_registradas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.perforaciones_registradas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    user_id uuid DEFAULT auth.uid(),
    created_by uuid DEFAULT auth.uid(),
    formulario_id uuid DEFAULT '8f7863f5-2d6a-4ae1-8fa9-8775a6c5995e'::uuid,
    latitud_decimal double precision,
    longitud_decimal double precision,
    latitud_dms text,
    longitud_dms text,
    geom public.geometry(Point,4326),
    updated_at timestamp with time zone DEFAULT now(),
    activo boolean DEFAULT true,
    departamento_id uuid,
    municipio_id uuid,
    codigo_pozo text,
    fecha_mesa_entrada date,
    titular_representante text,
    documento_cuil text,
    uso_agua text,
    empresa_perforista text,
    caudal_m3h text,
    medicion_cte_caudal_m3h text,
    profundidad_perforacion_m text,
    profundidad_succion_m text,
    profundidad_nivel_estatico_m text,
    profundidad_nivel_dinamico_m text,
    diametro_perforacion text,
    observaciones text
);


--
-- Name: plan_provincial_manejo_fuego; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.plan_provincial_manejo_fuego (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    created_by uuid,
    user_id uuid,
    formulario_id uuid DEFAULT '2b412292-5909-433f-85ee-81e7eae6ddef'::uuid,
    activo boolean DEFAULT true,
    nombre_incendio text,
    fecha_inicio date,
    hora_inicio time without time zone,
    fecha_finalizacion date,
    vegetacion_afectada text,
    hectareas_consumidas numeric,
    vehiculo text,
    ppmf numeric,
    quien_denuncia_via text,
    otro_personal text,
    fotos text[] DEFAULT '{}'::text[],
    audios text[] DEFAULT '{}'::text[],
    departamento_id uuid,
    municipio_id uuid,
    latitud_decimal double precision,
    longitud_decimal double precision,
    latitud_dms text,
    longitud_dms text,
    geom public.geometry(Point,4326),
    ciudad_temp text
);


--
-- Name: planes_bosques; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.planes_bosques (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    user_id uuid DEFAULT auth.uid(),
    created_by uuid DEFAULT auth.uid(),
    formulario_id uuid DEFAULT '2f4dbae9-adf5-4bdf-a484-2e6ee526f692'::uuid,
    latitud_decimal double precision,
    longitud_decimal double precision,
    latitud_dms text,
    longitud_dms text,
    geom public.geometry(Point,4326),
    updated_at timestamp with time zone DEFAULT now(),
    activo boolean DEFAULT true,
    departamento_id uuid,
    municipio_id uuid
);


--
-- Name: planilla_auditoria; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.planilla_auditoria (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    user_id uuid DEFAULT auth.uid(),
    created_by uuid DEFAULT auth.uid(),
    formulario_id uuid DEFAULT '2cf08d57-7e01-4bf6-b218-32f1ff014130'::uuid,
    latitud_decimal double precision,
    longitud_decimal double precision,
    latitud_dms text,
    longitud_dms text,
    geom public.geometry(Point,4326),
    updated_at timestamp with time zone DEFAULT now(),
    activo boolean DEFAULT true,
    departamento_id uuid,
    municipio_id uuid,
    nro numeric,
    nro_expediente text,
    infractor text,
    madera text,
    camion text,
    depositario text,
    ultimo_movimiento text,
    estado text
);


--
-- Name: procedencia_tipo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.procedencia_tipo (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre text NOT NULL,
    activo boolean DEFAULT true,
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.profiles (
    id uuid NOT NULL,
    full_name text,
    email text,
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: registro_historico_coleccionistas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.registro_historico_coleccionistas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    user_id uuid DEFAULT auth.uid(),
    created_by uuid DEFAULT auth.uid(),
    formulario_id uuid DEFAULT 'b2c3d4e5-f6a7-4890-b1c2-d3e4f5a6b7c8'::uuid,
    latitud_decimal numeric,
    longitud_decimal numeric,
    latitud_dms text,
    longitud_dms text,
    geom public.geometry,
    activo boolean DEFAULT true,
    departamento_id uuid,
    municipio_id uuid,
    registro_nro numeric,
    expediente_nro text,
    establecimiento text,
    titular text,
    dni text,
    objetivos text,
    ubicacion_descripcion text,
    habilitacion text,
    observaciones text
);


--
-- Name: registro_historico_viveros; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.registro_historico_viveros (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    user_id uuid DEFAULT auth.uid(),
    created_by uuid DEFAULT auth.uid(),
    formulario_id uuid DEFAULT 'a1b2c3d4-e5f6-4789-a0b1-c2d3e4f5a6b7'::uuid,
    latitud_decimal numeric,
    longitud_decimal numeric,
    latitud_dms text,
    longitud_dms text,
    geom public.geometry,
    activo boolean DEFAULT true,
    departamento_id uuid,
    municipio_id uuid,
    establecimiento_nro numeric,
    expediente_nro text,
    establecimiento_nombre text,
    titular text,
    direccion text,
    contacto text,
    dni text,
    objetivos text,
    ubicacion_descripcion text,
    observaciones text,
    habilitacion text,
    solicitud_talonario_a text
);


--
-- Name: registro_historico_viveros_medicinales; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.registro_historico_viveros_medicinales (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    user_id uuid DEFAULT auth.uid(),
    created_by uuid DEFAULT auth.uid(),
    formulario_id uuid DEFAULT 'c3d4e5f6-a7b8-4901-c2d3-e4f5a6b7c8d9'::uuid,
    latitud_decimal numeric,
    longitud_decimal numeric,
    latitud_dms text,
    longitud_dms text,
    geom public.geometry,
    activo boolean DEFAULT true,
    departamento_id uuid,
    municipio_id uuid,
    registro_nro numeric,
    expediente_nro text,
    establecimiento text,
    titular text,
    dni text,
    objetivos text,
    ubicacion_descripcion text,
    habilitacion text,
    observaciones text
);


--
-- Name: registro_inscripciones_lotes_industrias_martillos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.registro_inscripciones_lotes_industrias_martillos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    user_id uuid,
    created_by uuid,
    formulario_id uuid DEFAULT '7ba2a582-f2d3-403d-b7c5-373f28da3965'::uuid,
    cuil_dni text,
    nombre_razon_social text,
    domicilio_catastral text,
    tramite text,
    asunto text,
    expediente text,
    se_entrega_1 text,
    se_entrega_2 text,
    fecha_inscripcion date,
    fecha_vencimiento date,
    retira text,
    cel_correo_electronico text,
    fecha_retiro date,
    activo boolean DEFAULT true,
    latitud_decimal double precision,
    longitud_decimal double precision,
    latitud_dms text,
    longitud_dms text,
    geom public.geometry(Point,4326),
    updated_at timestamp with time zone DEFAULT now(),
    departamento_id uuid,
    municipio_id uuid
);

ALTER TABLE ONLY public.registro_inscripciones_lotes_industrias_martillos REPLICA IDENTITY FULL;


--
-- Name: registros_casos_fiebre_amarilla; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.registros_casos_fiebre_amarilla (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    created_by uuid,
    user_id uuid,
    formulario_id uuid DEFAULT '3d4e0232-f6e1-4b23-b4c2-02ed7100d40f'::uuid,
    activo boolean DEFAULT true,
    nro_orden numeric,
    fecha_registro date,
    ubicacion_posible_epizootia text,
    especie text,
    nombre_vulgar text,
    causa_hallazgo text,
    genero text,
    toma_muestras_tejido text,
    resultados text,
    observaciones text,
    departamento_id uuid,
    municipio_id uuid,
    latitud_decimal double precision,
    longitud_decimal double precision,
    latitud_dms text,
    longitud_dms text,
    geom public.geometry(Point,4326)
);


--
-- Name: rehabilitacion_ingresos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rehabilitacion_ingresos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    user_id uuid DEFAULT auth.uid(),
    created_by uuid DEFAULT auth.uid(),
    formulario_id uuid DEFAULT 'bbe0e432-c171-46e5-8383-050e4f67a4ad'::uuid,
    latitud_decimal double precision,
    longitud_decimal double precision,
    latitud_dms text,
    longitud_dms text,
    geom public.geometry(Point,4326),
    updated_at timestamp with time zone DEFAULT now(),
    activo boolean DEFAULT true,
    departamento_id uuid,
    municipio_id uuid,
    fecha date,
    anio integer,
    mes_id uuid,
    especie_tipo_id uuid,
    cantidad numeric DEFAULT 1,
    individuo text,
    origen_id uuid,
    destino_id uuid
);


--
-- Name: rehabilitacion_plantel_estable; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rehabilitacion_plantel_estable (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    user_id uuid DEFAULT auth.uid(),
    created_by uuid DEFAULT auth.uid(),
    formulario_id uuid DEFAULT '201d0a59-083d-45ab-bf56-e3e29e0a08a1'::uuid,
    latitud_decimal double precision,
    longitud_decimal double precision,
    latitud_dms text,
    longitud_dms text,
    geom public.geometry(Point,4326),
    updated_at timestamp with time zone DEFAULT now(),
    activo boolean DEFAULT true,
    departamento_id uuid,
    municipio_id uuid,
    sector_id uuid,
    especie_tipo_id uuid,
    individuo text,
    cantidad numeric DEFAULT 1
);


--
-- Name: residuos_peligrosos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.residuos_peligrosos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    generador text,
    anexo_252_2015 boolean DEFAULT false,
    tipo_actividad text,
    cuit text,
    latitud_decimal numeric,
    longitud_decimal numeric,
    latitud_dms text,
    longitud_dms text,
    domicilio text,
    municipio_id uuid,
    n_manifiesto text,
    fecha_manifiesto date,
    clase_ley_24051 text,
    volumen_masa text,
    created_at timestamp with time zone DEFAULT now(),
    created_by uuid DEFAULT auth.uid(),
    user_id uuid DEFAULT auth.uid(),
    formulario_id uuid DEFAULT 'b555a54f-cff7-4ffd-b339-ba1feebadba2'::uuid,
    activo boolean DEFAULT true,
    geom public.geometry(Point,4326),
    updated_at timestamp with time zone DEFAULT now(),
    departamento_id uuid
);

ALTER TABLE ONLY public.residuos_peligrosos REPLICA IDENTITY FULL;


--
-- Name: roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.roles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    key text NOT NULL,
    nombre text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    activo boolean DEFAULT true,
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone,
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: sectores_rehabilitacion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sectores_rehabilitacion (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre text NOT NULL,
    activo boolean DEFAULT true
);


--
-- Name: situacion_expedientes_vehiculos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.situacion_expedientes_vehiculos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre text NOT NULL,
    activo boolean DEFAULT true
);


--
-- Name: solicitudes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solicitudes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    solicitante_id uuid,
    solicitante_email text,
    solicitante_nombre text,
    nombre_completo text NOT NULL,
    email text NOT NULL,
    rol_id uuid,
    areas jsonb DEFAULT '[]'::jsonb,
    formularios jsonb DEFAULT '[]'::jsonb,
    creado boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    reiteraciones integer DEFAULT 0,
    tipo text DEFAULT 'registro'::text,
    user_id uuid,
    estado text DEFAULT 'pendiente'::text NOT NULL
);


--
-- Name: COLUMN solicitudes.tipo; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.solicitudes.tipo IS 'Puede ser "registro" para nuevos o "update" para cambios de permisos';


--
-- Name: solicitudes_apeo_ejido_urbano; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solicitudes_apeo_ejido_urbano (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    user_id uuid DEFAULT auth.uid(),
    created_by uuid DEFAULT auth.uid(),
    formulario_id uuid DEFAULT '6bd6b89b-003c-49c6-b3fe-7898535e63e2'::uuid,
    latitud_decimal double precision,
    longitud_decimal double precision,
    latitud_dms text,
    longitud_dms text,
    geom public.geometry(Point,4326),
    updated_at timestamp with time zone DEFAULT now(),
    activo boolean DEFAULT true,
    departamento_id uuid,
    municipio_id uuid,
    expediente_id text,
    fecha date,
    iniciador text,
    motivo text,
    ubicacion_descripcion text,
    resultado text
);


--
-- Name: solicitudes_en_tramite; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solicitudes_en_tramite (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    user_id uuid DEFAULT auth.uid(),
    created_by uuid DEFAULT auth.uid(),
    formulario_id uuid DEFAULT 'd4e5f6a7-b8c9-4012-d3e4-f5a6b7c8d9e0'::uuid,
    latitud_decimal numeric,
    longitud_decimal numeric,
    latitud_dms text,
    longitud_dms text,
    geom public.geometry,
    activo boolean DEFAULT true,
    departamento_id uuid,
    municipio_id uuid,
    fecha_recepcion date,
    expediente_nro text,
    id_nro text,
    asunto text,
    iniciador text,
    identificacion_fiscal text,
    observacion text,
    ubicacion_descripcion text,
    resultado text
);


--
-- Name: tenencia_fauna; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tenencia_fauna (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    numero_orden integer,
    numero_expediente text,
    apellido_nombre text,
    latitud_decimal double precision,
    latitud_dms text,
    longitud_decimal double precision,
    longitud_dms text,
    direccion text,
    departamento_id uuid,
    municipio_id uuid,
    contacto text,
    especie text,
    nombre_vulgar text,
    cantidad_total integer,
    permiso_tenencia boolean,
    estado_renovacion text,
    certificado_origen text,
    guia_transito boolean,
    observaciones text,
    formulario_id uuid DEFAULT '5222ed8b-d422-4ca3-a4d5-728c8795fba6'::uuid,
    created_at timestamp with time zone DEFAULT now(),
    created_by uuid,
    user_id uuid DEFAULT auth.uid(),
    geom public.geometry(Point,4326),
    fecha_permiso_tenencia date,
    activo boolean DEFAULT true,
    updated_at timestamp with time zone DEFAULT now()
);

ALTER TABLE ONLY public.tenencia_fauna REPLICA IDENTITY FULL;


--
-- Name: tipos_fito_domi; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tipos_fito_domi (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre text NOT NULL,
    activo boolean DEFAULT true
);


--
-- Name: toma_muestras_arroyos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.toma_muestras_arroyos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    n_orden text,
    fecha date,
    n_expediente text,
    municipio_id uuid,
    latitud_decimal numeric,
    longitud_decimal numeric,
    latitud_dms text,
    longitud_dms text,
    cantidad_muestras integer,
    cuenca_hidrografica text,
    arroyo text,
    analisis_fisico_quimicos text,
    created_at timestamp with time zone DEFAULT now(),
    created_by uuid DEFAULT auth.uid(),
    user_id uuid DEFAULT auth.uid(),
    formulario_id uuid DEFAULT '55507aef-68cb-44ce-862a-e59662058cef'::uuid,
    activo boolean DEFAULT true,
    geom public.geometry(Point,4326),
    updated_at timestamp with time zone DEFAULT now(),
    departamento_id uuid
);

ALTER TABLE ONLY public.toma_muestras_arroyos REPLICA IDENTITY FULL;


--
-- Name: toma_muestras_efluentes_industriales; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.toma_muestras_efluentes_industriales (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    n_orden text,
    fecha date,
    n_expediente_acta text,
    proponente text,
    tipo_actividad text,
    municipio_id uuid,
    latitud_decimal numeric,
    longitud_decimal numeric,
    latitud_dms text,
    longitud_dms text,
    cantidad_muestras integer,
    cuenca_hidrografica text,
    rio_arroyo text,
    analisis_fisico_microbiol text,
    created_at timestamp with time zone DEFAULT now(),
    created_by uuid DEFAULT auth.uid(),
    user_id uuid DEFAULT auth.uid(),
    formulario_id uuid DEFAULT '334d37a7-347c-469a-b290-65f42f476ad1'::uuid,
    activo boolean DEFAULT true,
    geom public.geometry(Point,4326),
    updated_at timestamp with time zone DEFAULT now(),
    departamento_id uuid
);

ALTER TABLE ONLY public.toma_muestras_efluentes_industriales REPLICA IDENTITY FULL;


--
-- Name: unidades_medida_aprovechamiento; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.unidades_medida_aprovechamiento (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre text NOT NULL,
    activo boolean DEFAULT true
);


--
-- Name: usuarios_areas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.usuarios_areas (
    user_id uuid NOT NULL,
    area_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    activo boolean DEFAULT true,
    updated_at timestamp with time zone DEFAULT now(),
    es_editor boolean DEFAULT true
);


--
-- Name: COLUMN usuarios_areas.es_editor; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.usuarios_areas.es_editor IS 'Si es false, el usuario solo puede ver los datos del área sin modificarlos';


--
-- Name: usuarios_formularios; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.usuarios_formularios (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    formulario_id uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    es_editor boolean DEFAULT true
);


--
-- Name: usuarios_rol; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.usuarios_rol (
    user_id uuid NOT NULL,
    rol_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    activo boolean DEFAULT true,
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: v_formulario_impacto_ambiental; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_formulario_impacto_ambiental AS
 SELECT 'impacto_ambiental_expedientes'::text AS formulario_slug,
    columns.column_name AS campo,
    columns.data_type AS tipo,
    initcap(replace((columns.column_name)::text, '_'::text, ' '::text)) AS label,
    ((columns.is_nullable)::text = 'NO'::text) AS requerido
   FROM information_schema.columns
  WHERE (((columns.table_schema)::name = 'public'::name) AND ((columns.table_name)::name = 'impacto_ambiental_expedientes'::name) AND ((columns.column_name)::name <> ALL (ARRAY['id'::name, 'created_at'::name, 'user_id'::name, 'created_by'::name, 'formulario_id'::name])))
  ORDER BY columns.ordinal_position;


--
-- Name: v_formulario_tenencia_fauna; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_formulario_tenencia_fauna AS
 SELECT 'tenencia_fauna'::text AS formulario_slug,
    columns.column_name AS campo,
    columns.data_type AS tipo,
    initcap(replace((columns.column_name)::text, '_'::text, ' '::text)) AS label,
    ((columns.is_nullable)::text = 'NO'::text) AS requerido
   FROM information_schema.columns
  WHERE (((columns.table_schema)::name = 'public'::name) AND ((columns.table_name)::name = 'tenencia_fauna'::name) AND ((columns.column_name)::name <> ALL (ARRAY['id'::name, 'created_at'::name, 'user_id'::name, 'created_by'::name, 'formulario_id'::name])))
  ORDER BY columns.ordinal_position;


--
-- Name: vehiculos_secuestrados; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vehiculos_secuestrados (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    created_by uuid,
    user_id uuid,
    formulario_id uuid DEFAULT 'd906d57a-d59d-4769-a59f-5da7eb6346d4'::uuid,
    activo boolean DEFAULT true,
    nro_acta_expte text,
    titular text,
    tipo_vehiculo text,
    dominio text,
    estado text,
    depositario text,
    situacion_expediente_id uuid,
    departamento_id uuid,
    municipio_id uuid,
    latitud_decimal double precision,
    longitud_decimal double precision,
    latitud_dms text,
    longitud_dms text,
    geom public.geometry(Point,4326)
);


--
-- Name: vista_secuestros; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vista_secuestros (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    user_id uuid DEFAULT auth.uid(),
    created_by uuid DEFAULT auth.uid(),
    formulario_id uuid DEFAULT '3ec8f74d-6ddd-4c9d-8d8c-fc3ebf0598e9'::uuid,
    latitud_decimal double precision,
    longitud_decimal double precision,
    latitud_dms text,
    longitud_dms text,
    geom public.geometry(Point,4326),
    updated_at timestamp with time zone DEFAULT now(),
    activo boolean DEFAULT true,
    departamento_id uuid,
    municipio_id uuid,
    nro_registro numeric,
    anio integer,
    fecha date,
    detalle_secuestro text,
    depositario text,
    acta_nro text,
    consta_en_id text,
    expediente_nro text,
    sujeto_implicado text,
    sancion text,
    estado_instruccion text,
    disposicion_nro text,
    estado_actual text,
    ultimo_movimiento text,
    estado_final text,
    observaciones_1 text,
    observaciones_2 text,
    backup_bosque text
);


--
-- Name: vivero_el_puma; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vivero_el_puma (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    user_id uuid DEFAULT auth.uid(),
    created_by uuid DEFAULT auth.uid(),
    formulario_id uuid DEFAULT '5a4dcc14-c387-4c99-afd8-96b89b0cbbc5'::uuid,
    latitud_decimal double precision,
    longitud_decimal double precision,
    latitud_dms text,
    longitud_dms text,
    geom public.geometry(Point,4326),
    updated_at timestamp with time zone DEFAULT now(),
    activo boolean DEFAULT true,
    departamento_id uuid,
    municipio_id uuid
);


--
-- Name: projects; Type: TABLE; Schema: realtime; Owner: -
--

CREATE TABLE realtime.projects (
    id bigint NOT NULL,
    external_id text NOT NULL,
    name text,
    jwt_secret text,
    db_host text NOT NULL,
    db_name text NOT NULL,
    db_port integer NOT NULL,
    db_user text NOT NULL,
    db_password text NOT NULL,
    db_schema text DEFAULT 'public'::text,
    db_ssl boolean DEFAULT false,
    inserted_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: projects_id_seq; Type: SEQUENCE; Schema: realtime; Owner: -
--

CREATE SEQUENCE realtime.projects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: projects_id_seq; Type: SEQUENCE OWNED BY; Schema: realtime; Owner: -
--

ALTER SEQUENCE realtime.projects_id_seq OWNED BY realtime.projects.id;


--
-- Name: buckets; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.buckets (
    id text NOT NULL,
    name text NOT NULL,
    owner uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    public boolean DEFAULT false,
    avif_autodetection boolean DEFAULT false,
    file_size_limit bigint,
    allowed_mime_types text[],
    owner_id text,
    type storage.buckettype DEFAULT 'STANDARD'::storage.buckettype NOT NULL
);


--
-- Name: COLUMN buckets.owner; Type: COMMENT; Schema: storage; Owner: -
--

COMMENT ON COLUMN storage.buckets.owner IS 'Field is deprecated, use owner_id instead';


--
-- Name: buckets_analytics; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.buckets_analytics (
    name text NOT NULL,
    type storage.buckettype DEFAULT 'ANALYTICS'::storage.buckettype NOT NULL,
    format text DEFAULT 'ICEBERG'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    deleted_at timestamp with time zone
);


--
-- Name: buckets_vectors; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.buckets_vectors (
    id text NOT NULL,
    type storage.buckettype DEFAULT 'VECTOR'::storage.buckettype NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: iceberg_namespaces; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.iceberg_namespaces (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    bucket_name text NOT NULL,
    name text NOT NULL COLLATE pg_catalog."C",
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    catalog_id uuid NOT NULL
);


--
-- Name: iceberg_tables; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.iceberg_tables (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    namespace_id uuid NOT NULL,
    bucket_name text NOT NULL,
    name text NOT NULL COLLATE pg_catalog."C",
    location text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    remote_table_id text,
    shard_key text,
    shard_id text,
    catalog_id uuid NOT NULL
);


--
-- Name: migrations; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.migrations (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    hash character varying(40) NOT NULL,
    executed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: objects; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.objects (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    bucket_id text,
    name text,
    owner uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    last_accessed_at timestamp with time zone DEFAULT now(),
    metadata jsonb,
    path_tokens text[] GENERATED ALWAYS AS (string_to_array(name, '/'::text)) STORED,
    version text,
    owner_id text,
    user_metadata jsonb,
    level integer
);


--
-- Name: COLUMN objects.owner; Type: COMMENT; Schema: storage; Owner: -
--

COMMENT ON COLUMN storage.objects.owner IS 'Field is deprecated, use owner_id instead';


--
-- Name: prefixes; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.prefixes (
    bucket_id text NOT NULL,
    name text NOT NULL COLLATE pg_catalog."C",
    level integer GENERATED ALWAYS AS (storage.get_level(name)) STORED NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: s3_multipart_uploads; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.s3_multipart_uploads (
    id text NOT NULL,
    in_progress_size bigint DEFAULT 0 NOT NULL,
    upload_signature text NOT NULL,
    bucket_id text NOT NULL,
    key text NOT NULL COLLATE pg_catalog."C",
    version text NOT NULL,
    owner_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    user_metadata jsonb
);


--
-- Name: s3_multipart_uploads_parts; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.s3_multipart_uploads_parts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    upload_id text NOT NULL,
    size bigint DEFAULT 0 NOT NULL,
    part_number integer NOT NULL,
    bucket_id text NOT NULL,
    key text NOT NULL COLLATE pg_catalog."C",
    etag text NOT NULL,
    owner_id text,
    version text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: vector_indexes; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.vector_indexes (
    id text DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL COLLATE pg_catalog."C",
    bucket_id text NOT NULL,
    data_type text NOT NULL,
    dimension integer NOT NULL,
    distance_metric text NOT NULL,
    metadata_configuration jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: hooks; Type: TABLE; Schema: supabase_functions; Owner: -
--

CREATE TABLE supabase_functions.hooks (
    id bigint NOT NULL,
    hook_table_id integer NOT NULL,
    hook_name text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    request_id bigint
);


--
-- Name: TABLE hooks; Type: COMMENT; Schema: supabase_functions; Owner: -
--

COMMENT ON TABLE supabase_functions.hooks IS 'Supabase Functions Hooks: Audit trail for triggered hooks.';


--
-- Name: hooks_id_seq; Type: SEQUENCE; Schema: supabase_functions; Owner: -
--

CREATE SEQUENCE supabase_functions.hooks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: hooks_id_seq; Type: SEQUENCE OWNED BY; Schema: supabase_functions; Owner: -
--

ALTER SEQUENCE supabase_functions.hooks_id_seq OWNED BY supabase_functions.hooks.id;


--
-- Name: migrations; Type: TABLE; Schema: supabase_functions; Owner: -
--

CREATE TABLE supabase_functions.migrations (
    version text NOT NULL,
    inserted_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: refresh_tokens id; Type: DEFAULT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens ALTER COLUMN id SET DEFAULT nextval('auth.refresh_tokens_id_seq'::regclass);


--
-- Name: entrega_alevines n_orden; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entrega_alevines ALTER COLUMN n_orden SET DEFAULT nextval('public.entrega_alevines_n_orden_seq'::regclass);


--
-- Name: projects id; Type: DEFAULT; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.projects ALTER COLUMN id SET DEFAULT nextval('realtime.projects_id_seq'::regclass);


--
-- Name: hooks id; Type: DEFAULT; Schema: supabase_functions; Owner: -
--

ALTER TABLE ONLY supabase_functions.hooks ALTER COLUMN id SET DEFAULT nextval('supabase_functions.hooks_id_seq'::regclass);


--
-- Name: extensions extensions_pkey; Type: CONSTRAINT; Schema: _realtime; Owner: -
--

ALTER TABLE ONLY _realtime.extensions
    ADD CONSTRAINT extensions_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: _realtime; Owner: -
--

ALTER TABLE ONLY _realtime.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: tenants tenants_pkey; Type: CONSTRAINT; Schema: _realtime; Owner: -
--

ALTER TABLE ONLY _realtime.tenants
    ADD CONSTRAINT tenants_pkey PRIMARY KEY (id);


--
-- Name: mfa_amr_claims amr_id_pk; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_amr_claims
    ADD CONSTRAINT amr_id_pk PRIMARY KEY (id);


--
-- Name: audit_log_entries audit_log_entries_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.audit_log_entries
    ADD CONSTRAINT audit_log_entries_pkey PRIMARY KEY (id);


--
-- Name: flow_state flow_state_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.flow_state
    ADD CONSTRAINT flow_state_pkey PRIMARY KEY (id);


--
-- Name: identities identities_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.identities
    ADD CONSTRAINT identities_pkey PRIMARY KEY (id);


--
-- Name: identities identities_provider_id_provider_unique; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.identities
    ADD CONSTRAINT identities_provider_id_provider_unique UNIQUE (provider_id, provider);


--
-- Name: instances instances_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.instances
    ADD CONSTRAINT instances_pkey PRIMARY KEY (id);


--
-- Name: mfa_amr_claims mfa_amr_claims_session_id_authentication_method_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_amr_claims
    ADD CONSTRAINT mfa_amr_claims_session_id_authentication_method_pkey UNIQUE (session_id, authentication_method);


--
-- Name: mfa_challenges mfa_challenges_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_challenges
    ADD CONSTRAINT mfa_challenges_pkey PRIMARY KEY (id);


--
-- Name: mfa_factors mfa_factors_last_challenged_at_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_factors
    ADD CONSTRAINT mfa_factors_last_challenged_at_key UNIQUE (last_challenged_at);


--
-- Name: mfa_factors mfa_factors_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_factors
    ADD CONSTRAINT mfa_factors_pkey PRIMARY KEY (id);


--
-- Name: oauth_authorizations oauth_authorizations_authorization_code_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_authorization_code_key UNIQUE (authorization_code);


--
-- Name: oauth_authorizations oauth_authorizations_authorization_id_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_authorization_id_key UNIQUE (authorization_id);


--
-- Name: oauth_authorizations oauth_authorizations_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_pkey PRIMARY KEY (id);


--
-- Name: oauth_client_states oauth_client_states_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_client_states
    ADD CONSTRAINT oauth_client_states_pkey PRIMARY KEY (id);


--
-- Name: oauth_clients oauth_clients_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_clients
    ADD CONSTRAINT oauth_clients_pkey PRIMARY KEY (id);


--
-- Name: oauth_consents oauth_consents_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_pkey PRIMARY KEY (id);


--
-- Name: oauth_consents oauth_consents_user_client_unique; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_user_client_unique UNIQUE (user_id, client_id);


--
-- Name: one_time_tokens one_time_tokens_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.one_time_tokens
    ADD CONSTRAINT one_time_tokens_pkey PRIMARY KEY (id);


--
-- Name: refresh_tokens refresh_tokens_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens
    ADD CONSTRAINT refresh_tokens_pkey PRIMARY KEY (id);


--
-- Name: refresh_tokens refresh_tokens_token_unique; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens
    ADD CONSTRAINT refresh_tokens_token_unique UNIQUE (token);


--
-- Name: saml_providers saml_providers_entity_id_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_providers
    ADD CONSTRAINT saml_providers_entity_id_key UNIQUE (entity_id);


--
-- Name: saml_providers saml_providers_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_providers
    ADD CONSTRAINT saml_providers_pkey PRIMARY KEY (id);


--
-- Name: saml_relay_states saml_relay_states_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_relay_states
    ADD CONSTRAINT saml_relay_states_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: sso_domains sso_domains_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sso_domains
    ADD CONSTRAINT sso_domains_pkey PRIMARY KEY (id);


--
-- Name: sso_providers sso_providers_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sso_providers
    ADD CONSTRAINT sso_providers_pkey PRIMARY KEY (id);


--
-- Name: users users_phone_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT users_phone_key UNIQUE (phone);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: actuaciones_control_guardaparques actuaciones_control_guardaparques_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.actuaciones_control_guardaparques
    ADD CONSTRAINT actuaciones_control_guardaparques_pkey PRIMARY KEY (id);


--
-- Name: almidoneras almidoneras_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.almidoneras
    ADD CONSTRAINT almidoneras_pkey PRIMARY KEY (id);


--
-- Name: aprovechamiento_pfnm aprovechamiento_pfnm_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aprovechamiento_pfnm
    ADD CONSTRAINT aprovechamiento_pfnm_pkey PRIMARY KEY (id);


--
-- Name: areas areas_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.areas
    ADD CONSTRAINT areas_key_key UNIQUE (key);


--
-- Name: areas_naturales_protegidas areas_naturales_protegidas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.areas_naturales_protegidas
    ADD CONSTRAINT areas_naturales_protegidas_pkey PRIMARY KEY (id);


--
-- Name: areas areas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.areas
    ADD CONSTRAINT areas_pkey PRIMARY KEY (id);


--
-- Name: aspectos_sanitarios aspectos_sanitarios_nombre_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aspectos_sanitarios
    ADD CONSTRAINT aspectos_sanitarios_nombre_key UNIQUE (nombre);


--
-- Name: aspectos_sanitarios aspectos_sanitarios_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aspectos_sanitarios
    ADD CONSTRAINT aspectos_sanitarios_pkey PRIMARY KEY (id);


--
-- Name: ataques_grandes_felinos ataques_grandes_felinos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ataques_grandes_felinos
    ADD CONSTRAINT ataques_grandes_felinos_pkey PRIMARY KEY (id);


--
-- Name: atropellamiento_fauna_silvestre atropellamiento_fauna_silvestre_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.atropellamiento_fauna_silvestre
    ADD CONSTRAINT atropellamiento_fauna_silvestre_pkey PRIMARY KEY (id);


--
-- Name: avistamiento_axis avistamiento_axis_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avistamiento_axis
    ADD CONSTRAINT avistamiento_axis_pkey PRIMARY KEY (id);


--
-- Name: camaras_trampas_anp camaras_trampas_anp_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.camaras_trampas_anp
    ADD CONSTRAINT camaras_trampas_anp_pkey PRIMARY KEY (id);


--
-- Name: carnet_pesca_deportiva carnet_pesca_deportiva_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.carnet_pesca_deportiva
    ADD CONSTRAINT carnet_pesca_deportiva_pkey PRIMARY KEY (id);


--
-- Name: carnet_pesca_subsistencia_comercial carnet_pesca_subsistencia_comercial_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.carnet_pesca_subsistencia_comercial
    ADD CONSTRAINT carnet_pesca_subsistencia_comercial_pkey PRIMARY KEY (id);


--
-- Name: categorias_carnet_pesca_deportiva categorias_carnet_pesca_deportiva_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categorias_carnet_pesca_deportiva
    ADD CONSTRAINT categorias_carnet_pesca_deportiva_pkey PRIMARY KEY (id);


--
-- Name: caza_furtiva caza_furtiva_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.caza_furtiva
    ADD CONSTRAINT caza_furtiva_pkey PRIMARY KEY (id);


--
-- Name: centros_manejo_fauna centros_manejo_fauna_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.centros_manejo_fauna
    ADD CONSTRAINT centros_manejo_fauna_pkey PRIMARY KEY (id);


--
-- Name: control_forestal control_forestal_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.control_forestal
    ADD CONSTRAINT control_forestal_pkey PRIMARY KEY (id);


--
-- Name: criadero_fauna_silvestre criadero_fauna_silvestre_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.criadero_fauna_silvestre
    ADD CONSTRAINT criadero_fauna_silvestre_pkey PRIMARY KEY (id);


--
-- Name: departamentos departamentos_codigo_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departamentos
    ADD CONSTRAINT departamentos_codigo_key UNIQUE (codigo);


--
-- Name: departamentos departamentos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departamentos
    ADD CONSTRAINT departamentos_pkey PRIMARY KEY (id);


--
-- Name: destino_rehabilitacion destino_rehabilitacion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.destino_rehabilitacion
    ADD CONSTRAINT destino_rehabilitacion_pkey PRIMARY KEY (id);


--
-- Name: entrega_alevines entrega_alevines_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entrega_alevines
    ADD CONSTRAINT entrega_alevines_pkey PRIMARY KEY (id);


--
-- Name: estados_aprovechamiento estados_aprovechamiento_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.estados_aprovechamiento
    ADD CONSTRAINT estados_aprovechamiento_pkey PRIMARY KEY (id);


--
-- Name: estados_carnet_pesca estados_carnet_pesca_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.estados_carnet_pesca
    ADD CONSTRAINT estados_carnet_pesca_pkey PRIMARY KEY (id);


--
-- Name: estados_conservacion estados_conservacion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.estados_conservacion
    ADD CONSTRAINT estados_conservacion_pkey PRIMARY KEY (id);


--
-- Name: estados_tramite_honorario estados_tramite_honorario_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.estados_tramite_honorario
    ADD CONSTRAINT estados_tramite_honorario_pkey PRIMARY KEY (id);


--
-- Name: exoticas_invasoras exoticas_invasoras_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exoticas_invasoras
    ADD CONSTRAINT exoticas_invasoras_pkey PRIMARY KEY (id);


--
-- Name: feedlots feedlots_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feedlots
    ADD CONSTRAINT feedlots_pkey PRIMARY KEY (id);


--
-- Name: fitosanitarios_domisanitarios fitosanitarios_domisanitarios_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fitosanitarios_domisanitarios
    ADD CONSTRAINT fitosanitarios_domisanitarios_pkey PRIMARY KEY (id);


--
-- Name: formularios formularios_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.formularios
    ADD CONSTRAINT formularios_pkey PRIMARY KEY (id);


--
-- Name: formularios formularios_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.formularios
    ADD CONSTRAINT formularios_slug_key UNIQUE (slug);


--
-- Name: frigorificos frigorificos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.frigorificos
    ADD CONSTRAINT frigorificos_pkey PRIMARY KEY (id);


--
-- Name: guardafauna_honorario guardafauna_honorario_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guardafauna_honorario
    ADD CONSTRAINT guardafauna_honorario_pkey PRIMARY KEY (id);


--
-- Name: expedientes_impacto_ambiental impacto_ambiental_expedientes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expedientes_impacto_ambiental
    ADD CONSTRAINT impacto_ambiental_expedientes_pkey PRIMARY KEY (id);


--
-- Name: maestro_especies_tipo maestro_especies_tipo_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.maestro_especies_tipo
    ADD CONSTRAINT maestro_especies_tipo_pkey PRIMARY KEY (id);


--
-- Name: maestro_meses maestro_meses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.maestro_meses
    ADD CONSTRAINT maestro_meses_pkey PRIMARY KEY (id);


--
-- Name: mapa_cauciones mapa_cauciones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mapa_cauciones
    ADD CONSTRAINT mapa_cauciones_pkey PRIMARY KEY (id);


--
-- Name: mascotismo_ilegal mascotismo_ilegal_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mascotismo_ilegal
    ADD CONSTRAINT mascotismo_ilegal_pkey PRIMARY KEY (id);


--
-- Name: mataderos mataderos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mataderos
    ADD CONSTRAINT mataderos_pkey PRIMARY KEY (id);


--
-- Name: mobile_apps mobile_apps_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mobile_apps
    ADD CONSTRAINT mobile_apps_pkey PRIMARY KEY (id);


--
-- Name: monos_aulladores monos_aulladores_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.monos_aulladores
    ADD CONSTRAINT monos_aulladores_pkey PRIMARY KEY (id);


--
-- Name: monumentos_naturales_provinciales monumentos_naturales_provinciales_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.monumentos_naturales_provinciales
    ADD CONSTRAINT monumentos_naturales_provinciales_pkey PRIMARY KEY (id);


--
-- Name: municipios municipios_nombre_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.municipios
    ADD CONSTRAINT municipios_nombre_key UNIQUE (nombre);


--
-- Name: municipios municipios_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.municipios
    ADD CONSTRAINT municipios_pkey PRIMARY KEY (id);


--
-- Name: origen_rehabilitacion origen_rehabilitacion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.origen_rehabilitacion
    ADD CONSTRAINT origen_rehabilitacion_pkey PRIMARY KEY (id);


--
-- Name: perforaciones_constatadas perforaciones_constatadas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.perforaciones_constatadas
    ADD CONSTRAINT perforaciones_constatadas_pkey PRIMARY KEY (id);


--
-- Name: perforaciones_registradas perforaciones_registradas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.perforaciones_registradas
    ADD CONSTRAINT perforaciones_registradas_pkey PRIMARY KEY (id);


--
-- Name: plan_provincial_manejo_fuego plan_provincial_manejo_fuego_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plan_provincial_manejo_fuego
    ADD CONSTRAINT plan_provincial_manejo_fuego_pkey PRIMARY KEY (id);


--
-- Name: planes_bosques planes_bosques_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.planes_bosques
    ADD CONSTRAINT planes_bosques_pkey PRIMARY KEY (id);


--
-- Name: planilla_auditoria planilla_auditoria_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.planilla_auditoria
    ADD CONSTRAINT planilla_auditoria_pkey PRIMARY KEY (id);


--
-- Name: procedencia_tipo procedencia_tipo_nombre_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.procedencia_tipo
    ADD CONSTRAINT procedencia_tipo_nombre_key UNIQUE (nombre);


--
-- Name: procedencia_tipo procedencia_tipo_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.procedencia_tipo
    ADD CONSTRAINT procedencia_tipo_pkey PRIMARY KEY (id);


--
-- Name: profiles profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);


--
-- Name: registro_historico_coleccionistas registro_historico_coleccionistas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.registro_historico_coleccionistas
    ADD CONSTRAINT registro_historico_coleccionistas_pkey PRIMARY KEY (id);


--
-- Name: registro_historico_viveros_medicinales registro_historico_viveros_medicinales_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.registro_historico_viveros_medicinales
    ADD CONSTRAINT registro_historico_viveros_medicinales_pkey PRIMARY KEY (id);


--
-- Name: registro_historico_viveros registro_historico_viveros_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.registro_historico_viveros
    ADD CONSTRAINT registro_historico_viveros_pkey PRIMARY KEY (id);


--
-- Name: registro_inscripciones_lotes_industrias_martillos registro_inscripciones_lotes_industrias_martillos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.registro_inscripciones_lotes_industrias_martillos
    ADD CONSTRAINT registro_inscripciones_lotes_industrias_martillos_pkey PRIMARY KEY (id);


--
-- Name: registros_casos_fiebre_amarilla registros_casos_fiebre_amarilla_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.registros_casos_fiebre_amarilla
    ADD CONSTRAINT registros_casos_fiebre_amarilla_pkey PRIMARY KEY (id);


--
-- Name: rehabilitacion_ingresos rehabilitacion_ingresos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rehabilitacion_ingresos
    ADD CONSTRAINT rehabilitacion_ingresos_pkey PRIMARY KEY (id);


--
-- Name: rehabilitacion_plantel_estable rehabilitacion_plantel_estable_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rehabilitacion_plantel_estable
    ADD CONSTRAINT rehabilitacion_plantel_estable_pkey PRIMARY KEY (id);


--
-- Name: residuos_peligrosos residuos_peligrosos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.residuos_peligrosos
    ADD CONSTRAINT residuos_peligrosos_pkey PRIMARY KEY (id);


--
-- Name: roles roles_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_key_key UNIQUE (key);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: sectores_rehabilitacion sectores_rehabilitacion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sectores_rehabilitacion
    ADD CONSTRAINT sectores_rehabilitacion_pkey PRIMARY KEY (id);


--
-- Name: situacion_expedientes_vehiculos situacion_expedientes_vehiculos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.situacion_expedientes_vehiculos
    ADD CONSTRAINT situacion_expedientes_vehiculos_pkey PRIMARY KEY (id);


--
-- Name: solicitudes_apeo_ejido_urbano solicitudes_apeo_ejido_urbano_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solicitudes_apeo_ejido_urbano
    ADD CONSTRAINT solicitudes_apeo_ejido_urbano_pkey PRIMARY KEY (id);


--
-- Name: solicitudes_en_tramite solicitudes_en_tramite_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solicitudes_en_tramite
    ADD CONSTRAINT solicitudes_en_tramite_pkey PRIMARY KEY (id);


--
-- Name: solicitudes solicitudes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solicitudes
    ADD CONSTRAINT solicitudes_pkey PRIMARY KEY (id);


--
-- Name: tenencia_fauna tenencia_fauna_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenencia_fauna
    ADD CONSTRAINT tenencia_fauna_pkey PRIMARY KEY (id);


--
-- Name: tipos_fito_domi tipos_fito_domi_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tipos_fito_domi
    ADD CONSTRAINT tipos_fito_domi_pkey PRIMARY KEY (id);


--
-- Name: toma_muestras_arroyos toma_muestras_arroyos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.toma_muestras_arroyos
    ADD CONSTRAINT toma_muestras_arroyos_pkey PRIMARY KEY (id);


--
-- Name: toma_muestras_efluentes_industriales toma_muestras_efluentes_industriales_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.toma_muestras_efluentes_industriales
    ADD CONSTRAINT toma_muestras_efluentes_industriales_pkey PRIMARY KEY (id);


--
-- Name: unidades_medida_aprovechamiento unidades_medida_aprovechamiento_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.unidades_medida_aprovechamiento
    ADD CONSTRAINT unidades_medida_aprovechamiento_pkey PRIMARY KEY (id);


--
-- Name: expedientes_impacto_ambiental unique_expediente; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expedientes_impacto_ambiental
    ADD CONSTRAINT unique_expediente UNIQUE (nro_expte, anio_expte, formulario_id);


--
-- Name: usuarios_areas usuarios_areas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuarios_areas
    ADD CONSTRAINT usuarios_areas_pkey PRIMARY KEY (user_id, area_id);


--
-- Name: usuarios_formularios usuarios_formularios_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuarios_formularios
    ADD CONSTRAINT usuarios_formularios_pkey PRIMARY KEY (id);


--
-- Name: usuarios_formularios usuarios_formularios_user_id_formulario_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuarios_formularios
    ADD CONSTRAINT usuarios_formularios_user_id_formulario_id_key UNIQUE (user_id, formulario_id);


--
-- Name: usuarios_rol usuarios_rol_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuarios_rol
    ADD CONSTRAINT usuarios_rol_pkey PRIMARY KEY (user_id);


--
-- Name: vehiculos_secuestrados vehiculos_secuestrados_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vehiculos_secuestrados
    ADD CONSTRAINT vehiculos_secuestrados_pkey PRIMARY KEY (id);


--
-- Name: vista_secuestros vista_secuestros_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vista_secuestros
    ADD CONSTRAINT vista_secuestros_pkey PRIMARY KEY (id);


--
-- Name: vivero_el_puma vivero_el_puma_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vivero_el_puma
    ADD CONSTRAINT vivero_el_puma_pkey PRIMARY KEY (id);


--
-- Name: projects projects_external_id_key; Type: CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.projects
    ADD CONSTRAINT projects_external_id_key UNIQUE (external_id);


--
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


--
-- Name: buckets_analytics buckets_analytics_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.buckets_analytics
    ADD CONSTRAINT buckets_analytics_pkey PRIMARY KEY (id);


--
-- Name: buckets buckets_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.buckets
    ADD CONSTRAINT buckets_pkey PRIMARY KEY (id);


--
-- Name: buckets_vectors buckets_vectors_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.buckets_vectors
    ADD CONSTRAINT buckets_vectors_pkey PRIMARY KEY (id);


--
-- Name: iceberg_namespaces iceberg_namespaces_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.iceberg_namespaces
    ADD CONSTRAINT iceberg_namespaces_pkey PRIMARY KEY (id);


--
-- Name: iceberg_tables iceberg_tables_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.iceberg_tables
    ADD CONSTRAINT iceberg_tables_pkey PRIMARY KEY (id);


--
-- Name: migrations migrations_name_key; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.migrations
    ADD CONSTRAINT migrations_name_key UNIQUE (name);


--
-- Name: migrations migrations_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.migrations
    ADD CONSTRAINT migrations_pkey PRIMARY KEY (id);


--
-- Name: objects objects_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.objects
    ADD CONSTRAINT objects_pkey PRIMARY KEY (id);


--
-- Name: prefixes prefixes_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.prefixes
    ADD CONSTRAINT prefixes_pkey PRIMARY KEY (bucket_id, level, name);


--
-- Name: s3_multipart_uploads_parts s3_multipart_uploads_parts_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads_parts
    ADD CONSTRAINT s3_multipart_uploads_parts_pkey PRIMARY KEY (id);


--
-- Name: s3_multipart_uploads s3_multipart_uploads_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads
    ADD CONSTRAINT s3_multipart_uploads_pkey PRIMARY KEY (id);


--
-- Name: vector_indexes vector_indexes_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.vector_indexes
    ADD CONSTRAINT vector_indexes_pkey PRIMARY KEY (id);


--
-- Name: hooks hooks_pkey; Type: CONSTRAINT; Schema: supabase_functions; Owner: -
--

ALTER TABLE ONLY supabase_functions.hooks
    ADD CONSTRAINT hooks_pkey PRIMARY KEY (id);


--
-- Name: migrations migrations_pkey; Type: CONSTRAINT; Schema: supabase_functions; Owner: -
--

ALTER TABLE ONLY supabase_functions.migrations
    ADD CONSTRAINT migrations_pkey PRIMARY KEY (version);


--
-- Name: extensions_tenant_external_id_index; Type: INDEX; Schema: _realtime; Owner: -
--

CREATE INDEX extensions_tenant_external_id_index ON _realtime.extensions USING btree (tenant_external_id);


--
-- Name: extensions_tenant_external_id_type_index; Type: INDEX; Schema: _realtime; Owner: -
--

CREATE UNIQUE INDEX extensions_tenant_external_id_type_index ON _realtime.extensions USING btree (tenant_external_id, type);


--
-- Name: tenants_external_id_index; Type: INDEX; Schema: _realtime; Owner: -
--

CREATE UNIQUE INDEX tenants_external_id_index ON _realtime.tenants USING btree (external_id);


--
-- Name: audit_logs_instance_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX audit_logs_instance_id_idx ON auth.audit_log_entries USING btree (instance_id);


--
-- Name: confirmation_token_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX confirmation_token_idx ON auth.users USING btree (confirmation_token) WHERE ((confirmation_token)::text !~ '^[0-9 ]*$'::text);


--
-- Name: email_change_token_current_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX email_change_token_current_idx ON auth.users USING btree (email_change_token_current) WHERE ((email_change_token_current)::text !~ '^[0-9 ]*$'::text);


--
-- Name: email_change_token_new_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX email_change_token_new_idx ON auth.users USING btree (email_change_token_new) WHERE ((email_change_token_new)::text !~ '^[0-9 ]*$'::text);


--
-- Name: factor_id_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX factor_id_created_at_idx ON auth.mfa_factors USING btree (user_id, created_at);


--
-- Name: flow_state_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX flow_state_created_at_idx ON auth.flow_state USING btree (created_at DESC);


--
-- Name: identities_email_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX identities_email_idx ON auth.identities USING btree (email text_pattern_ops);


--
-- Name: INDEX identities_email_idx; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON INDEX auth.identities_email_idx IS 'Auth: Ensures indexed queries on the email column';


--
-- Name: identities_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX identities_user_id_idx ON auth.identities USING btree (user_id);


--
-- Name: idx_auth_code; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_auth_code ON auth.flow_state USING btree (auth_code);


--
-- Name: idx_oauth_client_states_created_at; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_oauth_client_states_created_at ON auth.oauth_client_states USING btree (created_at);


--
-- Name: idx_user_id_auth_method; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_user_id_auth_method ON auth.flow_state USING btree (user_id, authentication_method);


--
-- Name: mfa_challenge_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX mfa_challenge_created_at_idx ON auth.mfa_challenges USING btree (created_at DESC);


--
-- Name: mfa_factors_user_friendly_name_unique; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX mfa_factors_user_friendly_name_unique ON auth.mfa_factors USING btree (friendly_name, user_id) WHERE (TRIM(BOTH FROM friendly_name) <> ''::text);


--
-- Name: mfa_factors_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX mfa_factors_user_id_idx ON auth.mfa_factors USING btree (user_id);


--
-- Name: oauth_auth_pending_exp_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_auth_pending_exp_idx ON auth.oauth_authorizations USING btree (expires_at) WHERE (status = 'pending'::auth.oauth_authorization_status);


--
-- Name: oauth_clients_deleted_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_clients_deleted_at_idx ON auth.oauth_clients USING btree (deleted_at);


--
-- Name: oauth_consents_active_client_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_consents_active_client_idx ON auth.oauth_consents USING btree (client_id) WHERE (revoked_at IS NULL);


--
-- Name: oauth_consents_active_user_client_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_consents_active_user_client_idx ON auth.oauth_consents USING btree (user_id, client_id) WHERE (revoked_at IS NULL);


--
-- Name: oauth_consents_user_order_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_consents_user_order_idx ON auth.oauth_consents USING btree (user_id, granted_at DESC);


--
-- Name: one_time_tokens_relates_to_hash_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX one_time_tokens_relates_to_hash_idx ON auth.one_time_tokens USING hash (relates_to);


--
-- Name: one_time_tokens_token_hash_hash_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX one_time_tokens_token_hash_hash_idx ON auth.one_time_tokens USING hash (token_hash);


--
-- Name: one_time_tokens_user_id_token_type_key; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX one_time_tokens_user_id_token_type_key ON auth.one_time_tokens USING btree (user_id, token_type);


--
-- Name: reauthentication_token_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX reauthentication_token_idx ON auth.users USING btree (reauthentication_token) WHERE ((reauthentication_token)::text !~ '^[0-9 ]*$'::text);


--
-- Name: recovery_token_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX recovery_token_idx ON auth.users USING btree (recovery_token) WHERE ((recovery_token)::text !~ '^[0-9 ]*$'::text);


--
-- Name: refresh_tokens_instance_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_instance_id_idx ON auth.refresh_tokens USING btree (instance_id);


--
-- Name: refresh_tokens_instance_id_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_instance_id_user_id_idx ON auth.refresh_tokens USING btree (instance_id, user_id);


--
-- Name: refresh_tokens_parent_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_parent_idx ON auth.refresh_tokens USING btree (parent);


--
-- Name: refresh_tokens_session_id_revoked_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_session_id_revoked_idx ON auth.refresh_tokens USING btree (session_id, revoked);


--
-- Name: refresh_tokens_updated_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_updated_at_idx ON auth.refresh_tokens USING btree (updated_at DESC);


--
-- Name: saml_providers_sso_provider_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_providers_sso_provider_id_idx ON auth.saml_providers USING btree (sso_provider_id);


--
-- Name: saml_relay_states_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_relay_states_created_at_idx ON auth.saml_relay_states USING btree (created_at DESC);


--
-- Name: saml_relay_states_for_email_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_relay_states_for_email_idx ON auth.saml_relay_states USING btree (for_email);


--
-- Name: saml_relay_states_sso_provider_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_relay_states_sso_provider_id_idx ON auth.saml_relay_states USING btree (sso_provider_id);


--
-- Name: sessions_not_after_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sessions_not_after_idx ON auth.sessions USING btree (not_after DESC);


--
-- Name: sessions_oauth_client_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sessions_oauth_client_id_idx ON auth.sessions USING btree (oauth_client_id);


--
-- Name: sessions_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sessions_user_id_idx ON auth.sessions USING btree (user_id);


--
-- Name: sso_domains_domain_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX sso_domains_domain_idx ON auth.sso_domains USING btree (lower(domain));


--
-- Name: sso_domains_sso_provider_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sso_domains_sso_provider_id_idx ON auth.sso_domains USING btree (sso_provider_id);


--
-- Name: sso_providers_resource_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX sso_providers_resource_id_idx ON auth.sso_providers USING btree (lower(resource_id));


--
-- Name: sso_providers_resource_id_pattern_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sso_providers_resource_id_pattern_idx ON auth.sso_providers USING btree (resource_id text_pattern_ops);


--
-- Name: unique_phone_factor_per_user; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX unique_phone_factor_per_user ON auth.mfa_factors USING btree (user_id, phone);


--
-- Name: user_id_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX user_id_created_at_idx ON auth.sessions USING btree (user_id, created_at);


--
-- Name: users_email_partial_key; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX users_email_partial_key ON auth.users USING btree (email) WHERE (is_sso_user = false);


--
-- Name: INDEX users_email_partial_key; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON INDEX auth.users_email_partial_key IS 'Auth: A partial unique index that applies only when is_sso_user is false';


--
-- Name: users_instance_id_email_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX users_instance_id_email_idx ON auth.users USING btree (instance_id, lower((email)::text));


--
-- Name: users_instance_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX users_instance_id_idx ON auth.users USING btree (instance_id);


--
-- Name: users_is_anonymous_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX users_is_anonymous_idx ON auth.users USING btree (is_anonymous);


--
-- Name: areas_nombre_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX areas_nombre_idx ON public.areas USING btree (nombre);


--
-- Name: formularios_activo_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX formularios_activo_idx ON public.formularios USING btree (activo);


--
-- Name: formularios_area_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX formularios_area_id_idx ON public.formularios USING btree (area_id);


--
-- Name: formularios_area_id_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX formularios_area_id_idx1 ON public.formularios USING btree (area_id);


--
-- Name: formularios_slug_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX formularios_slug_idx ON public.formularios USING btree (slug);


--
-- Name: idx_departamentos_codigo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_departamentos_codigo ON public.departamentos USING btree (codigo);


--
-- Name: idx_expedientes_geom; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_expedientes_geom ON public.expedientes_impacto_ambiental USING gist (geom);


--
-- Name: idx_impacto_expte_codigo_municipio; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_impacto_expte_codigo_municipio ON public.expedientes_impacto_ambiental USING btree (codigo_municipio);


--
-- Name: idx_impacto_expte_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_impacto_expte_created_at ON public.expedientes_impacto_ambiental USING btree (created_at);


--
-- Name: idx_impacto_expte_created_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_impacto_expte_created_by ON public.expedientes_impacto_ambiental USING btree (created_by);


--
-- Name: idx_impacto_expte_formulario; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_impacto_expte_formulario ON public.expedientes_impacto_ambiental USING btree (formulario_id);


--
-- Name: idx_impacto_expte_municipio; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_impacto_expte_municipio ON public.expedientes_impacto_ambiental USING btree (municipio_id);


--
-- Name: idx_impacto_expte_nro; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_impacto_expte_nro ON public.expedientes_impacto_ambiental USING btree (nro_expte, anio_expte);


--
-- Name: idx_mobile_apps_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_mobile_apps_slug ON public.mobile_apps USING btree (formulario_slug);


--
-- Name: idx_municipios_codigo_municipio; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_municipios_codigo_municipio ON public.municipios USING btree (codigo_municipio);


--
-- Name: idx_municipios_departamento_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_municipios_departamento_id ON public.municipios USING btree (departamento_id);


--
-- Name: idx_user_form_form; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_form_form ON public.usuarios_formularios USING btree (formulario_id);


--
-- Name: idx_user_form_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_form_user ON public.usuarios_formularios USING btree (user_id);


--
-- Name: idx_usuarios_rol_rol; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_usuarios_rol_rol ON public.usuarios_rol USING btree (rol_id);


--
-- Name: municipios_nombre_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX municipios_nombre_idx ON public.municipios USING btree (nombre);


--
-- Name: bname; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX bname ON storage.buckets USING btree (name);


--
-- Name: bucketid_objname; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX bucketid_objname ON storage.objects USING btree (bucket_id, name);


--
-- Name: buckets_analytics_unique_name_idx; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX buckets_analytics_unique_name_idx ON storage.buckets_analytics USING btree (name) WHERE (deleted_at IS NULL);


--
-- Name: idx_iceberg_namespaces_bucket_id; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX idx_iceberg_namespaces_bucket_id ON storage.iceberg_namespaces USING btree (catalog_id, name);


--
-- Name: idx_iceberg_tables_location; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX idx_iceberg_tables_location ON storage.iceberg_tables USING btree (location);


--
-- Name: idx_iceberg_tables_namespace_id; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX idx_iceberg_tables_namespace_id ON storage.iceberg_tables USING btree (catalog_id, namespace_id, name);


--
-- Name: idx_multipart_uploads_list; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX idx_multipart_uploads_list ON storage.s3_multipart_uploads USING btree (bucket_id, key, created_at);


--
-- Name: idx_name_bucket_level_unique; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX idx_name_bucket_level_unique ON storage.objects USING btree (name COLLATE "C", bucket_id, level);


--
-- Name: idx_objects_bucket_id_name; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX idx_objects_bucket_id_name ON storage.objects USING btree (bucket_id, name COLLATE "C");


--
-- Name: idx_objects_lower_name; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX idx_objects_lower_name ON storage.objects USING btree ((path_tokens[level]), lower(name) text_pattern_ops, bucket_id, level);


--
-- Name: idx_prefixes_lower_name; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX idx_prefixes_lower_name ON storage.prefixes USING btree (bucket_id, level, ((string_to_array(name, '/'::text))[level]), lower(name) text_pattern_ops);


--
-- Name: name_prefix_search; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX name_prefix_search ON storage.objects USING btree (name text_pattern_ops);


--
-- Name: objects_bucket_id_level_idx; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX objects_bucket_id_level_idx ON storage.objects USING btree (bucket_id, level, name COLLATE "C");


--
-- Name: vector_indexes_name_bucket_id_idx; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX vector_indexes_name_bucket_id_idx ON storage.vector_indexes USING btree (name, bucket_id);


--
-- Name: supabase_functions_hooks_h_table_id_h_name_idx; Type: INDEX; Schema: supabase_functions; Owner: -
--

CREATE INDEX supabase_functions_hooks_h_table_id_h_name_idx ON supabase_functions.hooks USING btree (hook_table_id, hook_name);


--
-- Name: supabase_functions_hooks_request_id_idx; Type: INDEX; Schema: supabase_functions; Owner: -
--

CREATE INDEX supabase_functions_hooks_request_id_idx ON supabase_functions.hooks USING btree (request_id);


--
-- Name: users on_auth_user_created; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


--
-- Name: actuaciones_control_guardaparques set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.actuaciones_control_guardaparques FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: almidoneras set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.almidoneras FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: aprovechamiento_pfnm set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.aprovechamiento_pfnm FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: areas set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.areas FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: areas_naturales_protegidas set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.areas_naturales_protegidas FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: aspectos_sanitarios set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.aspectos_sanitarios FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: ataques_grandes_felinos set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.ataques_grandes_felinos FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: atropellamiento_fauna_silvestre set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.atropellamiento_fauna_silvestre FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: avistamiento_axis set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.avistamiento_axis FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: camaras_trampas_anp set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.camaras_trampas_anp FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: carnet_pesca_deportiva set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.carnet_pesca_deportiva FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: carnet_pesca_subsistencia_comercial set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.carnet_pesca_subsistencia_comercial FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: caza_furtiva set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.caza_furtiva FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: centros_manejo_fauna set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.centros_manejo_fauna FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: control_forestal set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.control_forestal FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: criadero_fauna_silvestre set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.criadero_fauna_silvestre FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: departamentos set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.departamentos FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: entrega_alevines set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.entrega_alevines FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: exoticas_invasoras set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.exoticas_invasoras FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: expedientes_impacto_ambiental set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.expedientes_impacto_ambiental FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: feedlots set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.feedlots FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: fitosanitarios_domisanitarios set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.fitosanitarios_domisanitarios FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: formularios set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.formularios FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: frigorificos set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.frigorificos FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: guardafauna_honorario set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.guardafauna_honorario FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: mapa_cauciones set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.mapa_cauciones FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: mascotismo_ilegal set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.mascotismo_ilegal FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: mataderos set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.mataderos FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: monos_aulladores set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.monos_aulladores FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: monumentos_naturales_provinciales set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.monumentos_naturales_provinciales FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: municipios set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.municipios FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: perforaciones_constatadas set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.perforaciones_constatadas FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: perforaciones_registradas set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.perforaciones_registradas FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: planes_bosques set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.planes_bosques FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: planilla_auditoria set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.planilla_auditoria FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: procedencia_tipo set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.procedencia_tipo FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: profiles set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: registro_inscripciones_lotes_industrias_martillos set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.registro_inscripciones_lotes_industrias_martillos FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: rehabilitacion_ingresos set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.rehabilitacion_ingresos FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: rehabilitacion_plantel_estable set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.rehabilitacion_plantel_estable FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: residuos_peligrosos set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.residuos_peligrosos FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: roles set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.roles FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: solicitudes_apeo_ejido_urbano set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.solicitudes_apeo_ejido_urbano FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: tenencia_fauna set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.tenencia_fauna FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: toma_muestras_arroyos set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.toma_muestras_arroyos FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: toma_muestras_efluentes_industriales set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.toma_muestras_efluentes_industriales FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: usuarios_areas set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.usuarios_areas FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: usuarios_formularios set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.usuarios_formularios FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: usuarios_rol set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.usuarios_rol FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: vista_secuestros set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.vista_secuestros FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: vivero_el_puma set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.vivero_el_puma FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: actuaciones_control_guardaparques tr_auto_geom; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.actuaciones_control_guardaparques FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: almidoneras tr_auto_geom; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.almidoneras FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: aprovechamiento_pfnm tr_auto_geom; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.aprovechamiento_pfnm FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: areas_naturales_protegidas tr_auto_geom; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.areas_naturales_protegidas FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: ataques_grandes_felinos tr_auto_geom; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.ataques_grandes_felinos FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: atropellamiento_fauna_silvestre tr_auto_geom; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.atropellamiento_fauna_silvestre FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: avistamiento_axis tr_auto_geom; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.avistamiento_axis FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: camaras_trampas_anp tr_auto_geom; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.camaras_trampas_anp FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: carnet_pesca_deportiva tr_auto_geom; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.carnet_pesca_deportiva FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: carnet_pesca_subsistencia_comercial tr_auto_geom; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.carnet_pesca_subsistencia_comercial FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: caza_furtiva tr_auto_geom; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.caza_furtiva FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: centros_manejo_fauna tr_auto_geom; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.centros_manejo_fauna FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: control_forestal tr_auto_geom; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.control_forestal FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: criadero_fauna_silvestre tr_auto_geom; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.criadero_fauna_silvestre FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: entrega_alevines tr_auto_geom; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.entrega_alevines FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: exoticas_invasoras tr_auto_geom; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.exoticas_invasoras FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: expedientes_impacto_ambiental tr_auto_geom; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.expedientes_impacto_ambiental FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: feedlots tr_auto_geom; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.feedlots FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: fitosanitarios_domisanitarios tr_auto_geom; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.fitosanitarios_domisanitarios FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: frigorificos tr_auto_geom; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.frigorificos FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: guardafauna_honorario tr_auto_geom; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.guardafauna_honorario FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: mapa_cauciones tr_auto_geom; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.mapa_cauciones FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: mascotismo_ilegal tr_auto_geom; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.mascotismo_ilegal FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: mataderos tr_auto_geom; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.mataderos FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: monos_aulladores tr_auto_geom; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.monos_aulladores FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: monumentos_naturales_provinciales tr_auto_geom; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.monumentos_naturales_provinciales FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: perforaciones_constatadas tr_auto_geom; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.perforaciones_constatadas FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: perforaciones_registradas tr_auto_geom; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.perforaciones_registradas FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: planes_bosques tr_auto_geom; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.planes_bosques FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: planilla_auditoria tr_auto_geom; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.planilla_auditoria FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: registro_inscripciones_lotes_industrias_martillos tr_auto_geom; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.registro_inscripciones_lotes_industrias_martillos FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: rehabilitacion_ingresos tr_auto_geom; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.rehabilitacion_ingresos FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: rehabilitacion_plantel_estable tr_auto_geom; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.rehabilitacion_plantel_estable FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: residuos_peligrosos tr_auto_geom; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.residuos_peligrosos FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: solicitudes_apeo_ejido_urbano tr_auto_geom; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.solicitudes_apeo_ejido_urbano FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: tenencia_fauna tr_auto_geom; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.tenencia_fauna FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: toma_muestras_arroyos tr_auto_geom; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.toma_muestras_arroyos FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: toma_muestras_efluentes_industriales tr_auto_geom; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.toma_muestras_efluentes_industriales FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: vista_secuestros tr_auto_geom; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.vista_secuestros FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: vivero_el_puma tr_auto_geom; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.vivero_el_puma FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: plan_provincial_manejo_fuego tr_completar_geo_incendio; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_completar_geo_incendio BEFORE INSERT ON public.plan_provincial_manejo_fuego FOR EACH ROW EXECUTE FUNCTION _realtime.completar_campos_geograficos();


--
-- Name: registro_historico_coleccionistas tr_upd_hist_coleccionistas; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_upd_hist_coleccionistas BEFORE UPDATE ON public.registro_historico_coleccionistas FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: registro_historico_viveros tr_upd_hist_viveros; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_upd_hist_viveros BEFORE UPDATE ON public.registro_historico_viveros FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: registro_historico_viveros_medicinales tr_upd_hist_viveros_med; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_upd_hist_viveros_med BEFORE UPDATE ON public.registro_historico_viveros_medicinales FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: solicitudes_en_tramite tr_upd_solicitudes_tramite; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_upd_solicitudes_tramite BEFORE UPDATE ON public.solicitudes_en_tramite FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: carnet_pesca_deportiva tr_update_carnet_pesca_deportiva_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_update_carnet_pesca_deportiva_updated_at BEFORE UPDATE ON public.carnet_pesca_deportiva FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: carnet_pesca_subsistencia_comercial tr_update_carnet_pesca_subsistencia_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_update_carnet_pesca_subsistencia_updated_at BEFORE UPDATE ON public.carnet_pesca_subsistencia_comercial FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: centros_manejo_fauna tr_update_centros_manejo_fauna_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_update_centros_manejo_fauna_updated_at BEFORE UPDATE ON public.centros_manejo_fauna FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: exoticas_invasoras tr_update_exoticas_invasoras_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_update_exoticas_invasoras_updated_at BEFORE UPDATE ON public.exoticas_invasoras FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: registros_casos_fiebre_amarilla tr_update_fiebre_amarilla_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_update_fiebre_amarilla_updated_at BEFORE UPDATE ON public.registros_casos_fiebre_amarilla FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: fitosanitarios_domisanitarios tr_update_fitosanitarios_domi_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_update_fitosanitarios_domi_updated_at BEFORE UPDATE ON public.fitosanitarios_domisanitarios FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: guardafauna_honorario tr_update_guardafauna_honorario_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_update_guardafauna_honorario_updated_at BEFORE UPDATE ON public.guardafauna_honorario FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: monos_aulladores tr_update_monos_aulladores_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_update_monos_aulladores_updated_at BEFORE UPDATE ON public.monos_aulladores FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: monumentos_naturales_provinciales tr_update_monumentos_naturales_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_update_monumentos_naturales_updated_at BEFORE UPDATE ON public.monumentos_naturales_provinciales FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: perforaciones_constatadas tr_update_perforaciones_constatadas_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_update_perforaciones_constatadas_updated_at BEFORE UPDATE ON public.perforaciones_constatadas FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: perforaciones_registradas tr_update_perforaciones_registradas_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_update_perforaciones_registradas_updated_at BEFORE UPDATE ON public.perforaciones_registradas FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: plan_provincial_manejo_fuego tr_update_plan_fuego_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_update_plan_fuego_updated_at BEFORE UPDATE ON public.plan_provincial_manejo_fuego FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: planilla_auditoria tr_update_planilla_auditoria_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_update_planilla_auditoria_updated_at BEFORE UPDATE ON public.planilla_auditoria FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: rehabilitacion_plantel_estable tr_update_plantel_estable_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_update_plantel_estable_updated_at BEFORE UPDATE ON public.rehabilitacion_plantel_estable FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: rehabilitacion_ingresos tr_update_rehabilitacion_ingresos_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_update_rehabilitacion_ingresos_updated_at BEFORE UPDATE ON public.rehabilitacion_ingresos FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: solicitudes_apeo_ejido_urbano tr_update_solicitudes_apeo_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_update_solicitudes_apeo_updated_at BEFORE UPDATE ON public.solicitudes_apeo_ejido_urbano FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: vehiculos_secuestrados tr_update_vehiculos_secuestrados_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_update_vehiculos_secuestrados_updated_at BEFORE UPDATE ON public.vehiculos_secuestrados FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: vista_secuestros tr_update_vista_secuestros_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_update_vista_secuestros_updated_at BEFORE UPDATE ON public.vista_secuestros FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: aprovechamiento_pfnm update_aprovechamiento_pfnm_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_aprovechamiento_pfnm_updated_at BEFORE UPDATE ON public.aprovechamiento_pfnm FOR EACH ROW EXECUTE FUNCTION _realtime.update_updated_at_column();


--
-- Name: buckets enforce_bucket_name_length_trigger; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER enforce_bucket_name_length_trigger BEFORE INSERT OR UPDATE OF name ON storage.buckets FOR EACH ROW EXECUTE FUNCTION storage.enforce_bucket_name_length();


--
-- Name: objects objects_delete_delete_prefix; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER objects_delete_delete_prefix AFTER DELETE ON storage.objects FOR EACH ROW EXECUTE FUNCTION storage.delete_prefix_hierarchy_trigger();


--
-- Name: objects objects_insert_create_prefix; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER objects_insert_create_prefix BEFORE INSERT ON storage.objects FOR EACH ROW EXECUTE FUNCTION storage.objects_insert_prefix_trigger();


--
-- Name: objects objects_update_create_prefix; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER objects_update_create_prefix BEFORE UPDATE ON storage.objects FOR EACH ROW WHEN (((new.name <> old.name) OR (new.bucket_id <> old.bucket_id))) EXECUTE FUNCTION storage.objects_update_prefix_trigger();


--
-- Name: prefixes prefixes_create_hierarchy; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER prefixes_create_hierarchy BEFORE INSERT ON storage.prefixes FOR EACH ROW WHEN ((pg_trigger_depth() < 1)) EXECUTE FUNCTION storage.prefixes_insert_trigger();


--
-- Name: prefixes prefixes_delete_hierarchy; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER prefixes_delete_hierarchy AFTER DELETE ON storage.prefixes FOR EACH ROW EXECUTE FUNCTION storage.delete_prefix_hierarchy_trigger();


--
-- Name: objects update_objects_updated_at; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER update_objects_updated_at BEFORE UPDATE ON storage.objects FOR EACH ROW EXECUTE FUNCTION storage.update_updated_at_column();


--
-- Name: extensions extensions_tenant_external_id_fkey; Type: FK CONSTRAINT; Schema: _realtime; Owner: -
--

ALTER TABLE ONLY _realtime.extensions
    ADD CONSTRAINT extensions_tenant_external_id_fkey FOREIGN KEY (tenant_external_id) REFERENCES _realtime.tenants(external_id) ON DELETE CASCADE;


--
-- Name: identities identities_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.identities
    ADD CONSTRAINT identities_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: mfa_amr_claims mfa_amr_claims_session_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_amr_claims
    ADD CONSTRAINT mfa_amr_claims_session_id_fkey FOREIGN KEY (session_id) REFERENCES auth.sessions(id) ON DELETE CASCADE;


--
-- Name: mfa_challenges mfa_challenges_auth_factor_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_challenges
    ADD CONSTRAINT mfa_challenges_auth_factor_id_fkey FOREIGN KEY (factor_id) REFERENCES auth.mfa_factors(id) ON DELETE CASCADE;


--
-- Name: mfa_factors mfa_factors_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_factors
    ADD CONSTRAINT mfa_factors_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: oauth_authorizations oauth_authorizations_client_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_client_id_fkey FOREIGN KEY (client_id) REFERENCES auth.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: oauth_authorizations oauth_authorizations_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: oauth_consents oauth_consents_client_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_client_id_fkey FOREIGN KEY (client_id) REFERENCES auth.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: oauth_consents oauth_consents_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: one_time_tokens one_time_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.one_time_tokens
    ADD CONSTRAINT one_time_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: refresh_tokens refresh_tokens_session_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens
    ADD CONSTRAINT refresh_tokens_session_id_fkey FOREIGN KEY (session_id) REFERENCES auth.sessions(id) ON DELETE CASCADE;


--
-- Name: saml_providers saml_providers_sso_provider_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_providers
    ADD CONSTRAINT saml_providers_sso_provider_id_fkey FOREIGN KEY (sso_provider_id) REFERENCES auth.sso_providers(id) ON DELETE CASCADE;


--
-- Name: saml_relay_states saml_relay_states_flow_state_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_relay_states
    ADD CONSTRAINT saml_relay_states_flow_state_id_fkey FOREIGN KEY (flow_state_id) REFERENCES auth.flow_state(id) ON DELETE CASCADE;


--
-- Name: saml_relay_states saml_relay_states_sso_provider_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_relay_states
    ADD CONSTRAINT saml_relay_states_sso_provider_id_fkey FOREIGN KEY (sso_provider_id) REFERENCES auth.sso_providers(id) ON DELETE CASCADE;


--
-- Name: sessions sessions_oauth_client_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sessions
    ADD CONSTRAINT sessions_oauth_client_id_fkey FOREIGN KEY (oauth_client_id) REFERENCES auth.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: sessions sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sessions
    ADD CONSTRAINT sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: sso_domains sso_domains_sso_provider_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sso_domains
    ADD CONSTRAINT sso_domains_sso_provider_id_fkey FOREIGN KEY (sso_provider_id) REFERENCES auth.sso_providers(id) ON DELETE CASCADE;


--
-- Name: actuaciones_control_guardaparques actuaciones_control_guardaparques_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.actuaciones_control_guardaparques
    ADD CONSTRAINT actuaciones_control_guardaparques_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: actuaciones_control_guardaparques actuaciones_control_guardaparques_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.actuaciones_control_guardaparques
    ADD CONSTRAINT actuaciones_control_guardaparques_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: actuaciones_control_guardaparques actuaciones_control_guardaparques_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.actuaciones_control_guardaparques
    ADD CONSTRAINT actuaciones_control_guardaparques_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: actuaciones_control_guardaparques actuaciones_control_guardaparques_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.actuaciones_control_guardaparques
    ADD CONSTRAINT actuaciones_control_guardaparques_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: almidoneras almidoneras_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.almidoneras
    ADD CONSTRAINT almidoneras_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: almidoneras almidoneras_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.almidoneras
    ADD CONSTRAINT almidoneras_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: almidoneras almidoneras_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.almidoneras
    ADD CONSTRAINT almidoneras_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: almidoneras almidoneras_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.almidoneras
    ADD CONSTRAINT almidoneras_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: aprovechamiento_pfnm aprovechamiento_pfnm_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aprovechamiento_pfnm
    ADD CONSTRAINT aprovechamiento_pfnm_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: aprovechamiento_pfnm aprovechamiento_pfnm_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aprovechamiento_pfnm
    ADD CONSTRAINT aprovechamiento_pfnm_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: aprovechamiento_pfnm aprovechamiento_pfnm_estado_tramite_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aprovechamiento_pfnm
    ADD CONSTRAINT aprovechamiento_pfnm_estado_tramite_id_fkey FOREIGN KEY (estado_tramite_id) REFERENCES public.estados_aprovechamiento(id);


--
-- Name: aprovechamiento_pfnm aprovechamiento_pfnm_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aprovechamiento_pfnm
    ADD CONSTRAINT aprovechamiento_pfnm_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: aprovechamiento_pfnm aprovechamiento_pfnm_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aprovechamiento_pfnm
    ADD CONSTRAINT aprovechamiento_pfnm_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: aprovechamiento_pfnm aprovechamiento_pfnm_unidad_medida_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aprovechamiento_pfnm
    ADD CONSTRAINT aprovechamiento_pfnm_unidad_medida_id_fkey FOREIGN KEY (unidad_medida_id) REFERENCES public.unidades_medida_aprovechamiento(id);


--
-- Name: aprovechamiento_pfnm aprovechamiento_pfnm_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aprovechamiento_pfnm
    ADD CONSTRAINT aprovechamiento_pfnm_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: areas_naturales_protegidas areas_naturales_protegidas_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.areas_naturales_protegidas
    ADD CONSTRAINT areas_naturales_protegidas_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: areas_naturales_protegidas areas_naturales_protegidas_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.areas_naturales_protegidas
    ADD CONSTRAINT areas_naturales_protegidas_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: areas_naturales_protegidas areas_naturales_protegidas_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.areas_naturales_protegidas
    ADD CONSTRAINT areas_naturales_protegidas_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: areas_naturales_protegidas areas_naturales_protegidas_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.areas_naturales_protegidas
    ADD CONSTRAINT areas_naturales_protegidas_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: ataques_grandes_felinos ataques_grandes_felinos_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ataques_grandes_felinos
    ADD CONSTRAINT ataques_grandes_felinos_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: ataques_grandes_felinos ataques_grandes_felinos_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ataques_grandes_felinos
    ADD CONSTRAINT ataques_grandes_felinos_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: ataques_grandes_felinos ataques_grandes_felinos_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ataques_grandes_felinos
    ADD CONSTRAINT ataques_grandes_felinos_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: atropellamiento_fauna_silvestre atropellamiento_fauna_silvestre_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.atropellamiento_fauna_silvestre
    ADD CONSTRAINT atropellamiento_fauna_silvestre_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: atropellamiento_fauna_silvestre atropellamiento_fauna_silvestre_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.atropellamiento_fauna_silvestre
    ADD CONSTRAINT atropellamiento_fauna_silvestre_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: atropellamiento_fauna_silvestre atropellamiento_fauna_silvestre_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.atropellamiento_fauna_silvestre
    ADD CONSTRAINT atropellamiento_fauna_silvestre_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: avistamiento_axis avistamiento_axis_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avistamiento_axis
    ADD CONSTRAINT avistamiento_axis_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: avistamiento_axis avistamiento_axis_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avistamiento_axis
    ADD CONSTRAINT avistamiento_axis_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: avistamiento_axis avistamiento_axis_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avistamiento_axis
    ADD CONSTRAINT avistamiento_axis_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: avistamiento_axis avistamiento_axis_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avistamiento_axis
    ADD CONSTRAINT avistamiento_axis_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: camaras_trampas_anp camaras_trampas_anp_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.camaras_trampas_anp
    ADD CONSTRAINT camaras_trampas_anp_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: camaras_trampas_anp camaras_trampas_anp_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.camaras_trampas_anp
    ADD CONSTRAINT camaras_trampas_anp_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: camaras_trampas_anp camaras_trampas_anp_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.camaras_trampas_anp
    ADD CONSTRAINT camaras_trampas_anp_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: carnet_pesca_deportiva carnet_pesca_deportiva_categoria_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.carnet_pesca_deportiva
    ADD CONSTRAINT carnet_pesca_deportiva_categoria_id_fkey FOREIGN KEY (categoria_id) REFERENCES public.categorias_carnet_pesca_deportiva(id);


--
-- Name: carnet_pesca_deportiva carnet_pesca_deportiva_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.carnet_pesca_deportiva
    ADD CONSTRAINT carnet_pesca_deportiva_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: carnet_pesca_deportiva carnet_pesca_deportiva_delegacion_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.carnet_pesca_deportiva
    ADD CONSTRAINT carnet_pesca_deportiva_delegacion_id_fkey FOREIGN KEY (delegacion_id) REFERENCES public.municipios(id);


--
-- Name: carnet_pesca_deportiva carnet_pesca_deportiva_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.carnet_pesca_deportiva
    ADD CONSTRAINT carnet_pesca_deportiva_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: carnet_pesca_deportiva carnet_pesca_deportiva_estado_carnet_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.carnet_pesca_deportiva
    ADD CONSTRAINT carnet_pesca_deportiva_estado_carnet_id_fkey FOREIGN KEY (estado_carnet_id) REFERENCES public.estados_carnet_pesca(id);


--
-- Name: carnet_pesca_deportiva carnet_pesca_deportiva_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.carnet_pesca_deportiva
    ADD CONSTRAINT carnet_pesca_deportiva_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: carnet_pesca_deportiva carnet_pesca_deportiva_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.carnet_pesca_deportiva
    ADD CONSTRAINT carnet_pesca_deportiva_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: carnet_pesca_deportiva carnet_pesca_deportiva_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.carnet_pesca_deportiva
    ADD CONSTRAINT carnet_pesca_deportiva_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: carnet_pesca_subsistencia_comercial carnet_pesca_subsistencia_comercial_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.carnet_pesca_subsistencia_comercial
    ADD CONSTRAINT carnet_pesca_subsistencia_comercial_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: carnet_pesca_subsistencia_comercial carnet_pesca_subsistencia_comercial_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.carnet_pesca_subsistencia_comercial
    ADD CONSTRAINT carnet_pesca_subsistencia_comercial_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: carnet_pesca_subsistencia_comercial carnet_pesca_subsistencia_comercial_estado_carnet_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.carnet_pesca_subsistencia_comercial
    ADD CONSTRAINT carnet_pesca_subsistencia_comercial_estado_carnet_id_fkey FOREIGN KEY (estado_carnet_id) REFERENCES public.estados_carnet_pesca(id);


--
-- Name: carnet_pesca_subsistencia_comercial carnet_pesca_subsistencia_comercial_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.carnet_pesca_subsistencia_comercial
    ADD CONSTRAINT carnet_pesca_subsistencia_comercial_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: carnet_pesca_subsistencia_comercial carnet_pesca_subsistencia_comercial_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.carnet_pesca_subsistencia_comercial
    ADD CONSTRAINT carnet_pesca_subsistencia_comercial_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: carnet_pesca_subsistencia_comercial carnet_pesca_subsistencia_comercial_municipio_relacion_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.carnet_pesca_subsistencia_comercial
    ADD CONSTRAINT carnet_pesca_subsistencia_comercial_municipio_relacion_id_fkey FOREIGN KEY (municipio_relacion_id) REFERENCES public.municipios(id);


--
-- Name: carnet_pesca_subsistencia_comercial carnet_pesca_subsistencia_comercial_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.carnet_pesca_subsistencia_comercial
    ADD CONSTRAINT carnet_pesca_subsistencia_comercial_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: caza_furtiva caza_furtiva_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.caza_furtiva
    ADD CONSTRAINT caza_furtiva_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: caza_furtiva caza_furtiva_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.caza_furtiva
    ADD CONSTRAINT caza_furtiva_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: caza_furtiva caza_furtiva_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.caza_furtiva
    ADD CONSTRAINT caza_furtiva_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: centros_manejo_fauna centros_manejo_fauna_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.centros_manejo_fauna
    ADD CONSTRAINT centros_manejo_fauna_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: centros_manejo_fauna centros_manejo_fauna_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.centros_manejo_fauna
    ADD CONSTRAINT centros_manejo_fauna_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: centros_manejo_fauna centros_manejo_fauna_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.centros_manejo_fauna
    ADD CONSTRAINT centros_manejo_fauna_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: centros_manejo_fauna centros_manejo_fauna_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.centros_manejo_fauna
    ADD CONSTRAINT centros_manejo_fauna_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: centros_manejo_fauna centros_manejo_fauna_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.centros_manejo_fauna
    ADD CONSTRAINT centros_manejo_fauna_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: control_forestal control_forestal_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.control_forestal
    ADD CONSTRAINT control_forestal_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: control_forestal control_forestal_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.control_forestal
    ADD CONSTRAINT control_forestal_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: control_forestal control_forestal_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.control_forestal
    ADD CONSTRAINT control_forestal_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: control_forestal control_forestal_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.control_forestal
    ADD CONSTRAINT control_forestal_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: criadero_fauna_silvestre criadero_fauna_silvestre_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.criadero_fauna_silvestre
    ADD CONSTRAINT criadero_fauna_silvestre_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: criadero_fauna_silvestre criadero_fauna_silvestre_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.criadero_fauna_silvestre
    ADD CONSTRAINT criadero_fauna_silvestre_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: criadero_fauna_silvestre criadero_fauna_silvestre_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.criadero_fauna_silvestre
    ADD CONSTRAINT criadero_fauna_silvestre_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: entrega_alevines entrega_alevines_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entrega_alevines
    ADD CONSTRAINT entrega_alevines_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: entrega_alevines entrega_alevines_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entrega_alevines
    ADD CONSTRAINT entrega_alevines_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: entrega_alevines entrega_alevines_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entrega_alevines
    ADD CONSTRAINT entrega_alevines_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: exoticas_invasoras exoticas_invasoras_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exoticas_invasoras
    ADD CONSTRAINT exoticas_invasoras_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: exoticas_invasoras exoticas_invasoras_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exoticas_invasoras
    ADD CONSTRAINT exoticas_invasoras_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: exoticas_invasoras exoticas_invasoras_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exoticas_invasoras
    ADD CONSTRAINT exoticas_invasoras_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: exoticas_invasoras exoticas_invasoras_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exoticas_invasoras
    ADD CONSTRAINT exoticas_invasoras_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: exoticas_invasoras exoticas_invasoras_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exoticas_invasoras
    ADD CONSTRAINT exoticas_invasoras_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: expedientes_impacto_ambiental expedientes_impacto_ambiental_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expedientes_impacto_ambiental
    ADD CONSTRAINT expedientes_impacto_ambiental_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: feedlots feedlots_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feedlots
    ADD CONSTRAINT feedlots_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: feedlots feedlots_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feedlots
    ADD CONSTRAINT feedlots_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: feedlots feedlots_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feedlots
    ADD CONSTRAINT feedlots_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: feedlots feedlots_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feedlots
    ADD CONSTRAINT feedlots_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: fitosanitarios_domisanitarios fitosanitarios_domisanitarios_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fitosanitarios_domisanitarios
    ADD CONSTRAINT fitosanitarios_domisanitarios_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: fitosanitarios_domisanitarios fitosanitarios_domisanitarios_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fitosanitarios_domisanitarios
    ADD CONSTRAINT fitosanitarios_domisanitarios_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: fitosanitarios_domisanitarios fitosanitarios_domisanitarios_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fitosanitarios_domisanitarios
    ADD CONSTRAINT fitosanitarios_domisanitarios_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: fitosanitarios_domisanitarios fitosanitarios_domisanitarios_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fitosanitarios_domisanitarios
    ADD CONSTRAINT fitosanitarios_domisanitarios_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: fitosanitarios_domisanitarios fitosanitarios_domisanitarios_tipo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fitosanitarios_domisanitarios
    ADD CONSTRAINT fitosanitarios_domisanitarios_tipo_id_fkey FOREIGN KEY (tipo_id) REFERENCES public.tipos_fito_domi(id);


--
-- Name: fitosanitarios_domisanitarios fitosanitarios_domisanitarios_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fitosanitarios_domisanitarios
    ADD CONSTRAINT fitosanitarios_domisanitarios_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: expedientes_impacto_ambiental fk_municipio; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expedientes_impacto_ambiental
    ADD CONSTRAINT fk_municipio FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: municipios fk_municipios_departamento; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.municipios
    ADD CONSTRAINT fk_municipios_departamento FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id) ON DELETE RESTRICT;


--
-- Name: tenencia_fauna fk_tenencia_fauna_created_by; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenencia_fauna
    ADD CONSTRAINT fk_tenencia_fauna_created_by FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: formularios formularios_area_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.formularios
    ADD CONSTRAINT formularios_area_id_fkey FOREIGN KEY (area_id) REFERENCES public.areas(id) ON DELETE CASCADE;


--
-- Name: frigorificos frigorificos_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.frigorificos
    ADD CONSTRAINT frigorificos_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: frigorificos frigorificos_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.frigorificos
    ADD CONSTRAINT frigorificos_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: frigorificos frigorificos_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.frigorificos
    ADD CONSTRAINT frigorificos_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: frigorificos frigorificos_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.frigorificos
    ADD CONSTRAINT frigorificos_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: guardafauna_honorario guardafauna_honorario_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guardafauna_honorario
    ADD CONSTRAINT guardafauna_honorario_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: guardafauna_honorario guardafauna_honorario_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guardafauna_honorario
    ADD CONSTRAINT guardafauna_honorario_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: guardafauna_honorario guardafauna_honorario_estado_tramite_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guardafauna_honorario
    ADD CONSTRAINT guardafauna_honorario_estado_tramite_id_fkey FOREIGN KEY (estado_tramite_id) REFERENCES public.estados_tramite_honorario(id);


--
-- Name: guardafauna_honorario guardafauna_honorario_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guardafauna_honorario
    ADD CONSTRAINT guardafauna_honorario_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: guardafauna_honorario guardafauna_honorario_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guardafauna_honorario
    ADD CONSTRAINT guardafauna_honorario_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: guardafauna_honorario guardafauna_honorario_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guardafauna_honorario
    ADD CONSTRAINT guardafauna_honorario_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: expedientes_impacto_ambiental impacto_ambiental_expedientes_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expedientes_impacto_ambiental
    ADD CONSTRAINT impacto_ambiental_expedientes_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: expedientes_impacto_ambiental impacto_ambiental_expedientes_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expedientes_impacto_ambiental
    ADD CONSTRAINT impacto_ambiental_expedientes_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: expedientes_impacto_ambiental impacto_ambiental_expedientes_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expedientes_impacto_ambiental
    ADD CONSTRAINT impacto_ambiental_expedientes_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: expedientes_impacto_ambiental impacto_ambiental_expedientes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expedientes_impacto_ambiental
    ADD CONSTRAINT impacto_ambiental_expedientes_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: mapa_cauciones mapa_cauciones_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mapa_cauciones
    ADD CONSTRAINT mapa_cauciones_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: mapa_cauciones mapa_cauciones_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mapa_cauciones
    ADD CONSTRAINT mapa_cauciones_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: mapa_cauciones mapa_cauciones_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mapa_cauciones
    ADD CONSTRAINT mapa_cauciones_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: mapa_cauciones mapa_cauciones_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mapa_cauciones
    ADD CONSTRAINT mapa_cauciones_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: mapa_cauciones mapa_cauciones_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mapa_cauciones
    ADD CONSTRAINT mapa_cauciones_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: mascotismo_ilegal mascotismo_ilegal_aspecto_sanitario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mascotismo_ilegal
    ADD CONSTRAINT mascotismo_ilegal_aspecto_sanitario_id_fkey FOREIGN KEY (aspecto_sanitario_id) REFERENCES public.aspectos_sanitarios(id);


--
-- Name: mascotismo_ilegal mascotismo_ilegal_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mascotismo_ilegal
    ADD CONSTRAINT mascotismo_ilegal_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: mascotismo_ilegal mascotismo_ilegal_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mascotismo_ilegal
    ADD CONSTRAINT mascotismo_ilegal_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: mascotismo_ilegal mascotismo_ilegal_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mascotismo_ilegal
    ADD CONSTRAINT mascotismo_ilegal_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: mascotismo_ilegal mascotismo_ilegal_procedencia_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mascotismo_ilegal
    ADD CONSTRAINT mascotismo_ilegal_procedencia_id_fkey FOREIGN KEY (procedencia_id) REFERENCES public.procedencia_tipo(id);


--
-- Name: mataderos mataderos_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mataderos
    ADD CONSTRAINT mataderos_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: mataderos mataderos_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mataderos
    ADD CONSTRAINT mataderos_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: mataderos mataderos_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mataderos
    ADD CONSTRAINT mataderos_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: mataderos mataderos_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mataderos
    ADD CONSTRAINT mataderos_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: monos_aulladores monos_aulladores_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.monos_aulladores
    ADD CONSTRAINT monos_aulladores_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: monos_aulladores monos_aulladores_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.monos_aulladores
    ADD CONSTRAINT monos_aulladores_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: monos_aulladores monos_aulladores_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.monos_aulladores
    ADD CONSTRAINT monos_aulladores_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: monos_aulladores monos_aulladores_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.monos_aulladores
    ADD CONSTRAINT monos_aulladores_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: monos_aulladores monos_aulladores_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.monos_aulladores
    ADD CONSTRAINT monos_aulladores_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: monumentos_naturales_provinciales monumentos_naturales_provinci_estado_conservacion_internac_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.monumentos_naturales_provinciales
    ADD CONSTRAINT monumentos_naturales_provinci_estado_conservacion_internac_fkey FOREIGN KEY (estado_conservacion_internacional_id) REFERENCES public.estados_conservacion(id);


--
-- Name: monumentos_naturales_provinciales monumentos_naturales_provinci_estado_conservacion_nacional_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.monumentos_naturales_provinciales
    ADD CONSTRAINT monumentos_naturales_provinci_estado_conservacion_nacional_fkey FOREIGN KEY (estado_conservacion_nacional_id) REFERENCES public.estados_conservacion(id);


--
-- Name: monumentos_naturales_provinciales monumentos_naturales_provinci_estado_conservacion_provinci_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.monumentos_naturales_provinciales
    ADD CONSTRAINT monumentos_naturales_provinci_estado_conservacion_provinci_fkey FOREIGN KEY (estado_conservacion_provincial_id) REFERENCES public.estados_conservacion(id);


--
-- Name: monumentos_naturales_provinciales monumentos_naturales_provinciales_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.monumentos_naturales_provinciales
    ADD CONSTRAINT monumentos_naturales_provinciales_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: monumentos_naturales_provinciales monumentos_naturales_provinciales_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.monumentos_naturales_provinciales
    ADD CONSTRAINT monumentos_naturales_provinciales_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: monumentos_naturales_provinciales monumentos_naturales_provinciales_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.monumentos_naturales_provinciales
    ADD CONSTRAINT monumentos_naturales_provinciales_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: monumentos_naturales_provinciales monumentos_naturales_provinciales_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.monumentos_naturales_provinciales
    ADD CONSTRAINT monumentos_naturales_provinciales_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: monumentos_naturales_provinciales monumentos_naturales_provinciales_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.monumentos_naturales_provinciales
    ADD CONSTRAINT monumentos_naturales_provinciales_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: perforaciones_constatadas perforaciones_constatadas_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.perforaciones_constatadas
    ADD CONSTRAINT perforaciones_constatadas_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: perforaciones_constatadas perforaciones_constatadas_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.perforaciones_constatadas
    ADD CONSTRAINT perforaciones_constatadas_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: perforaciones_constatadas perforaciones_constatadas_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.perforaciones_constatadas
    ADD CONSTRAINT perforaciones_constatadas_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: perforaciones_constatadas perforaciones_constatadas_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.perforaciones_constatadas
    ADD CONSTRAINT perforaciones_constatadas_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: perforaciones_constatadas perforaciones_constatadas_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.perforaciones_constatadas
    ADD CONSTRAINT perforaciones_constatadas_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: perforaciones_registradas perforaciones_registradas_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.perforaciones_registradas
    ADD CONSTRAINT perforaciones_registradas_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: perforaciones_registradas perforaciones_registradas_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.perforaciones_registradas
    ADD CONSTRAINT perforaciones_registradas_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: perforaciones_registradas perforaciones_registradas_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.perforaciones_registradas
    ADD CONSTRAINT perforaciones_registradas_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: perforaciones_registradas perforaciones_registradas_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.perforaciones_registradas
    ADD CONSTRAINT perforaciones_registradas_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: perforaciones_registradas perforaciones_registradas_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.perforaciones_registradas
    ADD CONSTRAINT perforaciones_registradas_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: plan_provincial_manejo_fuego plan_provincial_manejo_fuego_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plan_provincial_manejo_fuego
    ADD CONSTRAINT plan_provincial_manejo_fuego_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: plan_provincial_manejo_fuego plan_provincial_manejo_fuego_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plan_provincial_manejo_fuego
    ADD CONSTRAINT plan_provincial_manejo_fuego_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: plan_provincial_manejo_fuego plan_provincial_manejo_fuego_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plan_provincial_manejo_fuego
    ADD CONSTRAINT plan_provincial_manejo_fuego_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: plan_provincial_manejo_fuego plan_provincial_manejo_fuego_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plan_provincial_manejo_fuego
    ADD CONSTRAINT plan_provincial_manejo_fuego_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: plan_provincial_manejo_fuego plan_provincial_manejo_fuego_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plan_provincial_manejo_fuego
    ADD CONSTRAINT plan_provincial_manejo_fuego_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: planes_bosques planes_bosques_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.planes_bosques
    ADD CONSTRAINT planes_bosques_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: planes_bosques planes_bosques_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.planes_bosques
    ADD CONSTRAINT planes_bosques_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: planes_bosques planes_bosques_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.planes_bosques
    ADD CONSTRAINT planes_bosques_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: planes_bosques planes_bosques_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.planes_bosques
    ADD CONSTRAINT planes_bosques_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: planes_bosques planes_bosques_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.planes_bosques
    ADD CONSTRAINT planes_bosques_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: planilla_auditoria planilla_auditoria_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.planilla_auditoria
    ADD CONSTRAINT planilla_auditoria_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: planilla_auditoria planilla_auditoria_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.planilla_auditoria
    ADD CONSTRAINT planilla_auditoria_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: planilla_auditoria planilla_auditoria_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.planilla_auditoria
    ADD CONSTRAINT planilla_auditoria_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: planilla_auditoria planilla_auditoria_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.planilla_auditoria
    ADD CONSTRAINT planilla_auditoria_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: planilla_auditoria planilla_auditoria_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.planilla_auditoria
    ADD CONSTRAINT planilla_auditoria_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: profiles profiles_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: registro_inscripciones_lotes_industrias_martillos registro_inscripciones_lotes_industrias_ma_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.registro_inscripciones_lotes_industrias_martillos
    ADD CONSTRAINT registro_inscripciones_lotes_industrias_ma_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: registro_inscripciones_lotes_industrias_martillos registro_inscripciones_lotes_industrias_mart_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.registro_inscripciones_lotes_industrias_martillos
    ADD CONSTRAINT registro_inscripciones_lotes_industrias_mart_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: registro_inscripciones_lotes_industrias_martillos registro_inscripciones_lotes_industrias_marti_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.registro_inscripciones_lotes_industrias_martillos
    ADD CONSTRAINT registro_inscripciones_lotes_industrias_marti_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: registro_inscripciones_lotes_industrias_martillos registro_inscripciones_lotes_industrias_martill_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.registro_inscripciones_lotes_industrias_martillos
    ADD CONSTRAINT registro_inscripciones_lotes_industrias_martill_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: registro_inscripciones_lotes_industrias_martillos registro_inscripciones_lotes_industrias_martillos_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.registro_inscripciones_lotes_industrias_martillos
    ADD CONSTRAINT registro_inscripciones_lotes_industrias_martillos_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: registros_casos_fiebre_amarilla registros_casos_fiebre_amarilla_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.registros_casos_fiebre_amarilla
    ADD CONSTRAINT registros_casos_fiebre_amarilla_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: registros_casos_fiebre_amarilla registros_casos_fiebre_amarilla_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.registros_casos_fiebre_amarilla
    ADD CONSTRAINT registros_casos_fiebre_amarilla_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: registros_casos_fiebre_amarilla registros_casos_fiebre_amarilla_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.registros_casos_fiebre_amarilla
    ADD CONSTRAINT registros_casos_fiebre_amarilla_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: registros_casos_fiebre_amarilla registros_casos_fiebre_amarilla_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.registros_casos_fiebre_amarilla
    ADD CONSTRAINT registros_casos_fiebre_amarilla_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: registros_casos_fiebre_amarilla registros_casos_fiebre_amarilla_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.registros_casos_fiebre_amarilla
    ADD CONSTRAINT registros_casos_fiebre_amarilla_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: rehabilitacion_ingresos rehabilitacion_ingresos_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rehabilitacion_ingresos
    ADD CONSTRAINT rehabilitacion_ingresos_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: rehabilitacion_ingresos rehabilitacion_ingresos_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rehabilitacion_ingresos
    ADD CONSTRAINT rehabilitacion_ingresos_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: rehabilitacion_ingresos rehabilitacion_ingresos_destino_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rehabilitacion_ingresos
    ADD CONSTRAINT rehabilitacion_ingresos_destino_id_fkey FOREIGN KEY (destino_id) REFERENCES public.destino_rehabilitacion(id);


--
-- Name: rehabilitacion_ingresos rehabilitacion_ingresos_especie_tipo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rehabilitacion_ingresos
    ADD CONSTRAINT rehabilitacion_ingresos_especie_tipo_id_fkey FOREIGN KEY (especie_tipo_id) REFERENCES public.maestro_especies_tipo(id);


--
-- Name: rehabilitacion_ingresos rehabilitacion_ingresos_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rehabilitacion_ingresos
    ADD CONSTRAINT rehabilitacion_ingresos_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: rehabilitacion_ingresos rehabilitacion_ingresos_mes_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rehabilitacion_ingresos
    ADD CONSTRAINT rehabilitacion_ingresos_mes_id_fkey FOREIGN KEY (mes_id) REFERENCES public.maestro_meses(id);


--
-- Name: rehabilitacion_ingresos rehabilitacion_ingresos_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rehabilitacion_ingresos
    ADD CONSTRAINT rehabilitacion_ingresos_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: rehabilitacion_ingresos rehabilitacion_ingresos_origen_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rehabilitacion_ingresos
    ADD CONSTRAINT rehabilitacion_ingresos_origen_id_fkey FOREIGN KEY (origen_id) REFERENCES public.origen_rehabilitacion(id);


--
-- Name: rehabilitacion_ingresos rehabilitacion_ingresos_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rehabilitacion_ingresos
    ADD CONSTRAINT rehabilitacion_ingresos_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: rehabilitacion_plantel_estable rehabilitacion_plantel_estable_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rehabilitacion_plantel_estable
    ADD CONSTRAINT rehabilitacion_plantel_estable_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: rehabilitacion_plantel_estable rehabilitacion_plantel_estable_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rehabilitacion_plantel_estable
    ADD CONSTRAINT rehabilitacion_plantel_estable_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: rehabilitacion_plantel_estable rehabilitacion_plantel_estable_especie_tipo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rehabilitacion_plantel_estable
    ADD CONSTRAINT rehabilitacion_plantel_estable_especie_tipo_id_fkey FOREIGN KEY (especie_tipo_id) REFERENCES public.maestro_especies_tipo(id);


--
-- Name: rehabilitacion_plantel_estable rehabilitacion_plantel_estable_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rehabilitacion_plantel_estable
    ADD CONSTRAINT rehabilitacion_plantel_estable_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: rehabilitacion_plantel_estable rehabilitacion_plantel_estable_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rehabilitacion_plantel_estable
    ADD CONSTRAINT rehabilitacion_plantel_estable_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: rehabilitacion_plantel_estable rehabilitacion_plantel_estable_sector_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rehabilitacion_plantel_estable
    ADD CONSTRAINT rehabilitacion_plantel_estable_sector_id_fkey FOREIGN KEY (sector_id) REFERENCES public.sectores_rehabilitacion(id);


--
-- Name: rehabilitacion_plantel_estable rehabilitacion_plantel_estable_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rehabilitacion_plantel_estable
    ADD CONSTRAINT rehabilitacion_plantel_estable_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: residuos_peligrosos residuos_peligrosos_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.residuos_peligrosos
    ADD CONSTRAINT residuos_peligrosos_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: residuos_peligrosos residuos_peligrosos_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.residuos_peligrosos
    ADD CONSTRAINT residuos_peligrosos_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: residuos_peligrosos residuos_peligrosos_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.residuos_peligrosos
    ADD CONSTRAINT residuos_peligrosos_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: residuos_peligrosos residuos_peligrosos_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.residuos_peligrosos
    ADD CONSTRAINT residuos_peligrosos_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: solicitudes_apeo_ejido_urbano solicitudes_apeo_ejido_urbano_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solicitudes_apeo_ejido_urbano
    ADD CONSTRAINT solicitudes_apeo_ejido_urbano_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: solicitudes_apeo_ejido_urbano solicitudes_apeo_ejido_urbano_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solicitudes_apeo_ejido_urbano
    ADD CONSTRAINT solicitudes_apeo_ejido_urbano_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: solicitudes_apeo_ejido_urbano solicitudes_apeo_ejido_urbano_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solicitudes_apeo_ejido_urbano
    ADD CONSTRAINT solicitudes_apeo_ejido_urbano_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: solicitudes_apeo_ejido_urbano solicitudes_apeo_ejido_urbano_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solicitudes_apeo_ejido_urbano
    ADD CONSTRAINT solicitudes_apeo_ejido_urbano_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: solicitudes_apeo_ejido_urbano solicitudes_apeo_ejido_urbano_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solicitudes_apeo_ejido_urbano
    ADD CONSTRAINT solicitudes_apeo_ejido_urbano_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: solicitudes solicitudes_rol_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solicitudes
    ADD CONSTRAINT solicitudes_rol_id_fkey FOREIGN KEY (rol_id) REFERENCES public.roles(id);


--
-- Name: solicitudes solicitudes_solicitante_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solicitudes
    ADD CONSTRAINT solicitudes_solicitante_id_fkey FOREIGN KEY (solicitante_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: solicitudes solicitudes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solicitudes
    ADD CONSTRAINT solicitudes_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: tenencia_fauna tenencia_fauna_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenencia_fauna
    ADD CONSTRAINT tenencia_fauna_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: tenencia_fauna tenencia_fauna_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenencia_fauna
    ADD CONSTRAINT tenencia_fauna_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: tenencia_fauna tenencia_fauna_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenencia_fauna
    ADD CONSTRAINT tenencia_fauna_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: toma_muestras_arroyos toma_muestras_arroyos_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.toma_muestras_arroyos
    ADD CONSTRAINT toma_muestras_arroyos_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: toma_muestras_arroyos toma_muestras_arroyos_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.toma_muestras_arroyos
    ADD CONSTRAINT toma_muestras_arroyos_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: toma_muestras_arroyos toma_muestras_arroyos_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.toma_muestras_arroyos
    ADD CONSTRAINT toma_muestras_arroyos_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: toma_muestras_arroyos toma_muestras_arroyos_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.toma_muestras_arroyos
    ADD CONSTRAINT toma_muestras_arroyos_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: toma_muestras_efluentes_industriales toma_muestras_efluentes_industriales_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.toma_muestras_efluentes_industriales
    ADD CONSTRAINT toma_muestras_efluentes_industriales_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: toma_muestras_efluentes_industriales toma_muestras_efluentes_industriales_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.toma_muestras_efluentes_industriales
    ADD CONSTRAINT toma_muestras_efluentes_industriales_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: toma_muestras_efluentes_industriales toma_muestras_efluentes_industriales_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.toma_muestras_efluentes_industriales
    ADD CONSTRAINT toma_muestras_efluentes_industriales_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: toma_muestras_efluentes_industriales toma_muestras_efluentes_industriales_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.toma_muestras_efluentes_industriales
    ADD CONSTRAINT toma_muestras_efluentes_industriales_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: usuarios_areas usuarios_areas_area_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuarios_areas
    ADD CONSTRAINT usuarios_areas_area_id_fkey FOREIGN KEY (area_id) REFERENCES public.areas(id) ON DELETE CASCADE;


--
-- Name: usuarios_areas usuarios_areas_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuarios_areas
    ADD CONSTRAINT usuarios_areas_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: usuarios_formularios usuarios_formularios_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuarios_formularios
    ADD CONSTRAINT usuarios_formularios_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id) ON DELETE CASCADE;


--
-- Name: usuarios_formularios usuarios_formularios_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuarios_formularios
    ADD CONSTRAINT usuarios_formularios_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: usuarios_rol usuarios_rol_rol_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuarios_rol
    ADD CONSTRAINT usuarios_rol_rol_id_fkey FOREIGN KEY (rol_id) REFERENCES public.roles(id) ON DELETE CASCADE;


--
-- Name: usuarios_rol usuarios_rol_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuarios_rol
    ADD CONSTRAINT usuarios_rol_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: vehiculos_secuestrados vehiculos_secuestrados_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vehiculos_secuestrados
    ADD CONSTRAINT vehiculos_secuestrados_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: vehiculos_secuestrados vehiculos_secuestrados_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vehiculos_secuestrados
    ADD CONSTRAINT vehiculos_secuestrados_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: vehiculos_secuestrados vehiculos_secuestrados_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vehiculos_secuestrados
    ADD CONSTRAINT vehiculos_secuestrados_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: vehiculos_secuestrados vehiculos_secuestrados_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vehiculos_secuestrados
    ADD CONSTRAINT vehiculos_secuestrados_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: vehiculos_secuestrados vehiculos_secuestrados_situacion_expediente_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vehiculos_secuestrados
    ADD CONSTRAINT vehiculos_secuestrados_situacion_expediente_id_fkey FOREIGN KEY (situacion_expediente_id) REFERENCES public.situacion_expedientes_vehiculos(id);


--
-- Name: vehiculos_secuestrados vehiculos_secuestrados_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vehiculos_secuestrados
    ADD CONSTRAINT vehiculos_secuestrados_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: vista_secuestros vista_secuestros_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vista_secuestros
    ADD CONSTRAINT vista_secuestros_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: vista_secuestros vista_secuestros_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vista_secuestros
    ADD CONSTRAINT vista_secuestros_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: vista_secuestros vista_secuestros_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vista_secuestros
    ADD CONSTRAINT vista_secuestros_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: vista_secuestros vista_secuestros_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vista_secuestros
    ADD CONSTRAINT vista_secuestros_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: vista_secuestros vista_secuestros_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vista_secuestros
    ADD CONSTRAINT vista_secuestros_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: vivero_el_puma vivero_el_puma_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vivero_el_puma
    ADD CONSTRAINT vivero_el_puma_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: vivero_el_puma vivero_el_puma_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vivero_el_puma
    ADD CONSTRAINT vivero_el_puma_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: vivero_el_puma vivero_el_puma_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vivero_el_puma
    ADD CONSTRAINT vivero_el_puma_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: vivero_el_puma vivero_el_puma_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vivero_el_puma
    ADD CONSTRAINT vivero_el_puma_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: vivero_el_puma vivero_el_puma_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vivero_el_puma
    ADD CONSTRAINT vivero_el_puma_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: iceberg_namespaces iceberg_namespaces_catalog_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.iceberg_namespaces
    ADD CONSTRAINT iceberg_namespaces_catalog_id_fkey FOREIGN KEY (catalog_id) REFERENCES storage.buckets_analytics(id) ON DELETE CASCADE;


--
-- Name: iceberg_tables iceberg_tables_catalog_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.iceberg_tables
    ADD CONSTRAINT iceberg_tables_catalog_id_fkey FOREIGN KEY (catalog_id) REFERENCES storage.buckets_analytics(id) ON DELETE CASCADE;


--
-- Name: iceberg_tables iceberg_tables_namespace_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.iceberg_tables
    ADD CONSTRAINT iceberg_tables_namespace_id_fkey FOREIGN KEY (namespace_id) REFERENCES storage.iceberg_namespaces(id) ON DELETE CASCADE;


--
-- Name: objects objects_bucketId_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.objects
    ADD CONSTRAINT "objects_bucketId_fkey" FOREIGN KEY (bucket_id) REFERENCES storage.buckets(id);


--
-- Name: prefixes prefixes_bucketId_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.prefixes
    ADD CONSTRAINT "prefixes_bucketId_fkey" FOREIGN KEY (bucket_id) REFERENCES storage.buckets(id);


--
-- Name: s3_multipart_uploads s3_multipart_uploads_bucket_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads
    ADD CONSTRAINT s3_multipart_uploads_bucket_id_fkey FOREIGN KEY (bucket_id) REFERENCES storage.buckets(id);


--
-- Name: s3_multipart_uploads_parts s3_multipart_uploads_parts_bucket_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads_parts
    ADD CONSTRAINT s3_multipart_uploads_parts_bucket_id_fkey FOREIGN KEY (bucket_id) REFERENCES storage.buckets(id);


--
-- Name: s3_multipart_uploads_parts s3_multipart_uploads_parts_upload_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads_parts
    ADD CONSTRAINT s3_multipart_uploads_parts_upload_id_fkey FOREIGN KEY (upload_id) REFERENCES storage.s3_multipart_uploads(id) ON DELETE CASCADE;


--
-- Name: vector_indexes vector_indexes_bucket_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.vector_indexes
    ADD CONSTRAINT vector_indexes_bucket_id_fkey FOREIGN KEY (bucket_id) REFERENCES storage.buckets_vectors(id);


--
-- Name: audit_log_entries; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.audit_log_entries ENABLE ROW LEVEL SECURITY;

--
-- Name: flow_state; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.flow_state ENABLE ROW LEVEL SECURITY;

--
-- Name: identities; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.identities ENABLE ROW LEVEL SECURITY;

--
-- Name: instances; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.instances ENABLE ROW LEVEL SECURITY;

--
-- Name: mfa_amr_claims; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.mfa_amr_claims ENABLE ROW LEVEL SECURITY;

--
-- Name: mfa_challenges; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.mfa_challenges ENABLE ROW LEVEL SECURITY;

--
-- Name: mfa_factors; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.mfa_factors ENABLE ROW LEVEL SECURITY;

--
-- Name: one_time_tokens; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.one_time_tokens ENABLE ROW LEVEL SECURITY;

--
-- Name: refresh_tokens; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.refresh_tokens ENABLE ROW LEVEL SECURITY;

--
-- Name: saml_providers; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.saml_providers ENABLE ROW LEVEL SECURITY;

--
-- Name: saml_relay_states; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.saml_relay_states ENABLE ROW LEVEL SECURITY;

--
-- Name: schema_migrations; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.schema_migrations ENABLE ROW LEVEL SECURITY;

--
-- Name: sessions; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.sessions ENABLE ROW LEVEL SECURITY;

--
-- Name: sso_domains; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.sso_domains ENABLE ROW LEVEL SECURITY;

--
-- Name: sso_providers; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.sso_providers ENABLE ROW LEVEL SECURITY;

--
-- Name: users; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.users ENABLE ROW LEVEL SECURITY;

--
-- Name: formularios Acceso por asignacion; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Acceso por asignacion" ON public.formularios FOR SELECT TO authenticated USING (((activo = true) OR (EXISTS ( SELECT 1
   FROM public.usuarios_formularios
  WHERE ((usuarios_formularios.user_id = auth.uid()) AND (usuarios_formularios.formulario_id = formularios.id)))) OR public.is_admin()));


--
-- Name: municipios Acceso publico lectura municipios; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Acceso publico lectura municipios" ON public.municipios FOR SELECT USING (true);


--
-- Name: departamentos Departamentos delete service; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Departamentos delete service" ON public.departamentos FOR DELETE USING ((auth.role() = 'service_role'::text));


--
-- Name: departamentos Departamentos insert service; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Departamentos insert service" ON public.departamentos FOR INSERT WITH CHECK ((auth.role() = 'service_role'::text));


--
-- Name: departamentos Departamentos readable; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Departamentos readable" ON public.departamentos FOR SELECT USING (true);


--
-- Name: departamentos Departamentos update service; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Departamentos update service" ON public.departamentos FOR UPDATE USING ((auth.role() = 'service_role'::text));


--
-- Name: perforaciones_registradas Gestion_dueño_o_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_dueño_o_admin" ON public.perforaciones_registradas TO authenticated USING ((public.check_is_admin() OR (auth.uid() = user_id) OR (auth.uid() = created_by)));


--
-- Name: planes_bosques Gestion_dueño_o_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_dueño_o_admin" ON public.planes_bosques TO authenticated USING ((public.check_is_admin() OR (auth.uid() = user_id) OR (auth.uid() = created_by)));


--
-- Name: planilla_auditoria Gestion_dueño_o_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_dueño_o_admin" ON public.planilla_auditoria TO authenticated USING ((public.check_is_admin() OR (auth.uid() = user_id) OR (auth.uid() = created_by)));


--
-- Name: registro_inscripciones_lotes_industrias_martillos Gestion_dueño_o_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_dueño_o_admin" ON public.registro_inscripciones_lotes_industrias_martillos TO authenticated USING ((public.check_is_admin() OR (auth.uid() = user_id) OR (auth.uid() = created_by)));


--
-- Name: rehabilitacion_ingresos Gestion_dueño_o_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_dueño_o_admin" ON public.rehabilitacion_ingresos TO authenticated USING ((public.check_is_admin() OR (auth.uid() = user_id) OR (auth.uid() = created_by)));


--
-- Name: rehabilitacion_plantel_estable Gestion_dueño_o_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_dueño_o_admin" ON public.rehabilitacion_plantel_estable TO authenticated USING ((public.check_is_admin() OR (auth.uid() = user_id) OR (auth.uid() = created_by)));


--
-- Name: residuos_peligrosos Gestion_dueño_o_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_dueño_o_admin" ON public.residuos_peligrosos TO authenticated USING ((public.check_is_admin() OR (auth.uid() = user_id) OR (auth.uid() = created_by)));


--
-- Name: solicitudes_apeo_ejido_urbano Gestion_dueño_o_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_dueño_o_admin" ON public.solicitudes_apeo_ejido_urbano TO authenticated USING ((public.check_is_admin() OR (auth.uid() = user_id) OR (auth.uid() = created_by)));


--
-- Name: tenencia_fauna Gestion_dueño_o_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_dueño_o_admin" ON public.tenencia_fauna TO authenticated USING ((public.check_is_admin() OR (auth.uid() = user_id) OR (auth.uid() = created_by)));


--
-- Name: toma_muestras_arroyos Gestion_dueño_o_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_dueño_o_admin" ON public.toma_muestras_arroyos TO authenticated USING ((public.check_is_admin() OR (auth.uid() = user_id) OR (auth.uid() = created_by)));


--
-- Name: toma_muestras_efluentes_industriales Gestion_dueño_o_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_dueño_o_admin" ON public.toma_muestras_efluentes_industriales TO authenticated USING ((public.check_is_admin() OR (auth.uid() = user_id) OR (auth.uid() = created_by)));


--
-- Name: vista_secuestros Gestion_dueño_o_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_dueño_o_admin" ON public.vista_secuestros TO authenticated USING ((public.check_is_admin() OR (auth.uid() = user_id) OR (auth.uid() = created_by)));


--
-- Name: vivero_el_puma Gestion_dueño_o_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_dueño_o_admin" ON public.vivero_el_puma TO authenticated USING ((public.check_is_admin() OR (auth.uid() = user_id) OR (auth.uid() = created_by)));


--
-- Name: almidoneras Gestion_por_permiso_formulario; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_por_permiso_formulario" ON public.almidoneras TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'almidoneras'::text))))));


--
-- Name: rehabilitacion_plantel_estable Gestion_total_plantel_estable; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_total_plantel_estable" ON public.rehabilitacion_plantel_estable TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'rehabilitacion_plantel_estable'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'rehabilitacion_plantel_estable'::text))))));


--
-- Name: actuaciones_control_guardaparques Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.actuaciones_control_guardaparques TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'actuaciones_control_guardaparques'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'actuaciones_control_guardaparques'::text))))));


--
-- Name: almidoneras Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.almidoneras TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'almidoneras'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'almidoneras'::text))))));


--
-- Name: aprovechamiento_pfnm Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.aprovechamiento_pfnm TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'aprovechamiento_pfnm'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'aprovechamiento_pfnm'::text))))));


--
-- Name: areas_naturales_protegidas Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.areas_naturales_protegidas TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'areas_naturales_protegidas'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'areas_naturales_protegidas'::text))))));


--
-- Name: ataques_grandes_felinos Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.ataques_grandes_felinos TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'ataques_grandes_felinos'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'ataques_grandes_felinos'::text))))));


--
-- Name: atropellamiento_fauna_silvestre Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.atropellamiento_fauna_silvestre TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'atropellamiento_fauna_silvestre'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'atropellamiento_fauna_silvestre'::text))))));


--
-- Name: avistamiento_axis Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.avistamiento_axis TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'avistamiento_axis'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'avistamiento_axis'::text))))));


--
-- Name: camaras_trampas_anp Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.camaras_trampas_anp TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'camaras_trampas_anp'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'camaras_trampas_anp'::text))))));


--
-- Name: carnet_pesca_deportiva Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.carnet_pesca_deportiva TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'carnet_pesca_deportiva'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'carnet_pesca_deportiva'::text))))));


--
-- Name: carnet_pesca_subsistencia_comercial Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.carnet_pesca_subsistencia_comercial TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'carnet_pesca_subsistencia_comercial'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'carnet_pesca_subsistencia_comercial'::text))))));


--
-- Name: caza_furtiva Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.caza_furtiva TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'caza_furtiva'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'caza_furtiva'::text))))));


--
-- Name: centros_manejo_fauna Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.centros_manejo_fauna TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'centros_manejo_fauna'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'centros_manejo_fauna'::text))))));


--
-- Name: control_forestal Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.control_forestal TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'control_forestal'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'control_forestal'::text))))));


--
-- Name: criadero_fauna_silvestre Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.criadero_fauna_silvestre TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'criadero_fauna_silvestre'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'criadero_fauna_silvestre'::text))))));


--
-- Name: entrega_alevines Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.entrega_alevines TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'entrega_alevines'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'entrega_alevines'::text))))));


--
-- Name: exoticas_invasoras Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.exoticas_invasoras TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'exoticas_invasoras'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'exoticas_invasoras'::text))))));


--
-- Name: expedientes_impacto_ambiental Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.expedientes_impacto_ambiental TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'expedientes_impacto_ambiental'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'expedientes_impacto_ambiental'::text))))));


--
-- Name: feedlots Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.feedlots TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'feedlots'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'feedlots'::text))))));


--
-- Name: fitosanitarios_domisanitarios Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.fitosanitarios_domisanitarios TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'fitosanitarios_domisanitarios'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'fitosanitarios_domisanitarios'::text))))));


--
-- Name: frigorificos Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.frigorificos TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'frigorificos'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'frigorificos'::text))))));


--
-- Name: guardafauna_honorario Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.guardafauna_honorario TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'guardafauna_honorario'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'guardafauna_honorario'::text))))));


--
-- Name: mapa_cauciones Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.mapa_cauciones TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'mapa_cauciones'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'mapa_cauciones'::text))))));


--
-- Name: mascotismo_ilegal Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.mascotismo_ilegal TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'mascotismo_ilegal'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'mascotismo_ilegal'::text))))));


--
-- Name: mataderos Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.mataderos TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'mataderos'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'mataderos'::text))))));


--
-- Name: monos_aulladores Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.monos_aulladores TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'monos_aulladores'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'monos_aulladores'::text))))));


--
-- Name: monumentos_naturales_provinciales Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.monumentos_naturales_provinciales TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'monumentos_naturales_provinciales'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'monumentos_naturales_provinciales'::text))))));


--
-- Name: perforaciones_constatadas Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.perforaciones_constatadas TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'perforaciones_constatadas'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'perforaciones_constatadas'::text))))));


--
-- Name: plan_provincial_manejo_fuego Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.plan_provincial_manejo_fuego TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'plan_provincial_manejo_fuego'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'plan_provincial_manejo_fuego'::text))))));


--
-- Name: registros_casos_fiebre_amarilla Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.registros_casos_fiebre_amarilla TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'registros_casos_fiebre_amarilla'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'registros_casos_fiebre_amarilla'::text))))));


--
-- Name: vehiculos_secuestrados Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.vehiculos_secuestrados TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'vehiculos_secuestrados'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'vehiculos_secuestrados'::text))))));


--
-- Name: rehabilitacion_ingresos Gestion_total_rehabilitacion_ingresos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_total_rehabilitacion_ingresos" ON public.rehabilitacion_ingresos TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'rehabilitacion_ingresos'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'rehabilitacion_ingresos'::text))))));


--
-- Name: solicitudes_apeo_ejido_urbano Gestion_total_solicitudes_apeo; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_total_solicitudes_apeo" ON public.solicitudes_apeo_ejido_urbano TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'solicitudes_apeo_ejido_urbano'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'solicitudes_apeo_ejido_urbano'::text))))));


--
-- Name: vista_secuestros Gestion_total_vista_secuestros; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Gestion_total_vista_secuestros" ON public.vista_secuestros TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'vista_secuestros'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'vista_secuestros'::text))))));


--
-- Name: perforaciones_registradas Insert_por_area_o_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Insert_por_area_o_admin" ON public.perforaciones_registradas FOR INSERT TO authenticated WITH CHECK ((public.check_is_admin() OR public.check_user_in_area('8e1fabda-503c-44cf-a170-b8d98138b8fc'::uuid)));


--
-- Name: planes_bosques Insert_por_area_o_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Insert_por_area_o_admin" ON public.planes_bosques FOR INSERT TO authenticated WITH CHECK ((public.check_is_admin() OR public.check_user_in_area('95f26419-138a-460d-9812-496f3688941b'::uuid)));


--
-- Name: planilla_auditoria Insert_por_area_o_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Insert_por_area_o_admin" ON public.planilla_auditoria FOR INSERT TO authenticated WITH CHECK ((public.check_is_admin() OR public.check_user_in_area('472f7188-d9da-494d-bcaf-880b75f5e141'::uuid)));


--
-- Name: registro_inscripciones_lotes_industrias_martillos Insert_por_area_o_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Insert_por_area_o_admin" ON public.registro_inscripciones_lotes_industrias_martillos FOR INSERT TO authenticated WITH CHECK ((public.check_is_admin() OR public.check_user_in_area('2f9d7b61-ef1c-4011-bd87-461da53e20d8'::uuid)));


--
-- Name: rehabilitacion_ingresos Insert_por_area_o_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Insert_por_area_o_admin" ON public.rehabilitacion_ingresos FOR INSERT TO authenticated WITH CHECK ((public.check_is_admin() OR public.check_user_in_area('14249152-7138-46de-8bf4-ae39fbedeecf'::uuid)));


--
-- Name: rehabilitacion_plantel_estable Insert_por_area_o_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Insert_por_area_o_admin" ON public.rehabilitacion_plantel_estable FOR INSERT TO authenticated WITH CHECK ((public.check_is_admin() OR public.check_user_in_area('14249152-7138-46de-8bf4-ae39fbedeecf'::uuid)));


--
-- Name: residuos_peligrosos Insert_por_area_o_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Insert_por_area_o_admin" ON public.residuos_peligrosos FOR INSERT TO authenticated WITH CHECK ((public.check_is_admin() OR public.check_user_in_area('8e1fabda-503c-44cf-a170-b8d98138b8fc'::uuid)));


--
-- Name: solicitudes_apeo_ejido_urbano Insert_por_area_o_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Insert_por_area_o_admin" ON public.solicitudes_apeo_ejido_urbano FOR INSERT TO authenticated WITH CHECK ((public.check_is_admin() OR public.check_user_in_area('3519260d-9301-4765-9e71-f4c7a008810c'::uuid)));


--
-- Name: tenencia_fauna Insert_por_area_o_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Insert_por_area_o_admin" ON public.tenencia_fauna FOR INSERT TO authenticated WITH CHECK ((public.check_is_admin() OR public.check_user_in_area('f61a3f26-52ad-4898-914c-86689e4e3d2c'::uuid)));


--
-- Name: toma_muestras_arroyos Insert_por_area_o_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Insert_por_area_o_admin" ON public.toma_muestras_arroyos FOR INSERT TO authenticated WITH CHECK ((public.check_is_admin() OR public.check_user_in_area('8e1fabda-503c-44cf-a170-b8d98138b8fc'::uuid)));


--
-- Name: toma_muestras_efluentes_industriales Insert_por_area_o_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Insert_por_area_o_admin" ON public.toma_muestras_efluentes_industriales FOR INSERT TO authenticated WITH CHECK ((public.check_is_admin() OR public.check_user_in_area('8e1fabda-503c-44cf-a170-b8d98138b8fc'::uuid)));


--
-- Name: vista_secuestros Insert_por_area_o_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Insert_por_area_o_admin" ON public.vista_secuestros FOR INSERT TO authenticated WITH CHECK ((public.check_is_admin() OR public.check_user_in_area('472f7188-d9da-494d-bcaf-880b75f5e141'::uuid)));


--
-- Name: vivero_el_puma Insert_por_area_o_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Insert_por_area_o_admin" ON public.vivero_el_puma FOR INSERT TO authenticated WITH CHECK ((public.check_is_admin() OR public.check_user_in_area('14249152-7138-46de-8bf4-ae39fbedeecf'::uuid)));


--
-- Name: profiles Perfiles visibles por autenticados; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Perfiles visibles por autenticados" ON public.profiles FOR SELECT TO authenticated USING (true);


--
-- Name: registro_historico_coleccionistas Policy_Gestion_registro_historico_coleccionistas; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Policy_Gestion_registro_historico_coleccionistas" ON public.registro_historico_coleccionistas TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'registro_historico_coleccionistas'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'registro_historico_coleccionistas'::text))))));


--
-- Name: registro_historico_viveros Policy_Gestion_registro_historico_viveros; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Policy_Gestion_registro_historico_viveros" ON public.registro_historico_viveros TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'registro_historico_viveros'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'registro_historico_viveros'::text))))));


--
-- Name: registro_historico_viveros_medicinales Policy_Gestion_registro_historico_viveros_medicinales; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Policy_Gestion_registro_historico_viveros_medicinales" ON public.registro_historico_viveros_medicinales TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'registro_historico_viveros_medicinales'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'registro_historico_viveros_medicinales'::text))))));


--
-- Name: solicitudes_en_tramite Policy_Gestion_solicitudes_en_tramite; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Policy_Gestion_solicitudes_en_tramite" ON public.solicitudes_en_tramite TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'solicitudes_en_tramite'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'solicitudes_en_tramite'::text))))));


--
-- Name: areas Politica_Universal_Update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Politica_Universal_Update" ON public.areas FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM (public.usuarios_rol ur
     JOIN public.roles r ON ((ur.rol_id = r.id)))
  WHERE ((((ur.user_id)::text)::uuid = auth.uid()) AND (r.key = ANY (ARRAY['admin'::text, 'superadmin'::text]))))));


--
-- Name: aspectos_sanitarios Read universal aspectos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Read universal aspectos" ON public.aspectos_sanitarios FOR SELECT USING (true);


--
-- Name: procedencia_tipo Read universal procedencia; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Read universal procedencia" ON public.procedencia_tipo FOR SELECT USING (true);


--
-- Name: roles Roles legibles por autenticados; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Roles legibles por autenticados" ON public.roles FOR SELECT TO authenticated USING (true);


--
-- Name: perforaciones_registradas Select_autenticados; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Select_autenticados" ON public.perforaciones_registradas FOR SELECT TO authenticated USING (true);


--
-- Name: planes_bosques Select_autenticados; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Select_autenticados" ON public.planes_bosques FOR SELECT TO authenticated USING (true);


--
-- Name: planilla_auditoria Select_autenticados; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Select_autenticados" ON public.planilla_auditoria FOR SELECT TO authenticated USING (true);


--
-- Name: registro_inscripciones_lotes_industrias_martillos Select_autenticados; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Select_autenticados" ON public.registro_inscripciones_lotes_industrias_martillos FOR SELECT TO authenticated USING (true);


--
-- Name: rehabilitacion_ingresos Select_autenticados; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Select_autenticados" ON public.rehabilitacion_ingresos FOR SELECT TO authenticated USING (true);


--
-- Name: rehabilitacion_plantel_estable Select_autenticados; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Select_autenticados" ON public.rehabilitacion_plantel_estable FOR SELECT TO authenticated USING (true);


--
-- Name: residuos_peligrosos Select_autenticados; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Select_autenticados" ON public.residuos_peligrosos FOR SELECT TO authenticated USING (true);


--
-- Name: solicitudes_apeo_ejido_urbano Select_autenticados; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Select_autenticados" ON public.solicitudes_apeo_ejido_urbano FOR SELECT TO authenticated USING (true);


--
-- Name: tenencia_fauna Select_autenticados; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Select_autenticados" ON public.tenencia_fauna FOR SELECT TO authenticated USING (true);


--
-- Name: toma_muestras_arroyos Select_autenticados; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Select_autenticados" ON public.toma_muestras_arroyos FOR SELECT TO authenticated USING (true);


--
-- Name: toma_muestras_efluentes_industriales Select_autenticados; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Select_autenticados" ON public.toma_muestras_efluentes_industriales FOR SELECT TO authenticated USING (true);


--
-- Name: vista_secuestros Select_autenticados; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Select_autenticados" ON public.vista_secuestros FOR SELECT TO authenticated USING (true);


--
-- Name: vivero_el_puma Select_autenticados; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Select_autenticados" ON public.vivero_el_puma FOR SELECT TO authenticated USING (true);


--
-- Name: ataques_grandes_felinos Select_por_permiso_formulario; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Select_por_permiso_formulario" ON public.ataques_grandes_felinos FOR SELECT TO authenticated USING (true);


--
-- Name: usuarios_areas SuperAdmins_Full_Access_Areas; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "SuperAdmins_Full_Access_Areas" ON public.usuarios_areas TO authenticated USING (public.check_is_superadmin()) WITH CHECK (public.check_is_superadmin());


--
-- Name: usuarios_rol SuperAdmins_Full_Access_Roles; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "SuperAdmins_Full_Access_Roles" ON public.usuarios_rol TO authenticated USING (public.check_is_superadmin()) WITH CHECK (public.check_is_superadmin());


--
-- Name: usuarios_rol Usuarios pueden ver su propio rol; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Usuarios pueden ver su propio rol" ON public.usuarios_rol FOR SELECT TO authenticated USING ((auth.uid() = user_id));


--
-- Name: usuarios_formularios Usuarios ven sus asignaciones; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Usuarios ven sus asignaciones" ON public.usuarios_formularios FOR SELECT TO authenticated USING (((user_id = auth.uid()) OR public.is_admin()));


--
-- Name: actuaciones_control_guardaparques; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.actuaciones_control_guardaparques ENABLE ROW LEVEL SECURITY;

--
-- Name: solicitudes admin_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY admin_insert ON public.solicitudes FOR INSERT TO authenticated WITH CHECK ((solicitante_id = auth.uid()));


--
-- Name: solicitudes admin_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY admin_select_own ON public.solicitudes FOR SELECT TO authenticated USING ((solicitante_id = auth.uid()));


--
-- Name: usuarios_rol admins_ver_roles; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY admins_ver_roles ON public.usuarios_rol FOR SELECT TO authenticated USING (true);


--
-- Name: almidoneras; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.almidoneras ENABLE ROW LEVEL SECURITY;

--
-- Name: aprovechamiento_pfnm; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.aprovechamiento_pfnm ENABLE ROW LEVEL SECURITY;

--
-- Name: areas; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.areas ENABLE ROW LEVEL SECURITY;

--
-- Name: areas areas_delete_superadmin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY areas_delete_superadmin ON public.areas FOR DELETE USING (public.is_superadmin());


--
-- Name: areas areas_lectura_autenticados; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY areas_lectura_autenticados ON public.areas FOR SELECT TO authenticated USING (true);


--
-- Name: areas_naturales_protegidas; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.areas_naturales_protegidas ENABLE ROW LEVEL SECURITY;

--
-- Name: aspectos_sanitarios; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.aspectos_sanitarios ENABLE ROW LEVEL SECURITY;

--
-- Name: ataques_grandes_felinos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ataques_grandes_felinos ENABLE ROW LEVEL SECURITY;

--
-- Name: atropellamiento_fauna_silvestre; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.atropellamiento_fauna_silvestre ENABLE ROW LEVEL SECURITY;

--
-- Name: avistamiento_axis; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.avistamiento_axis ENABLE ROW LEVEL SECURITY;

--
-- Name: camaras_trampas_anp; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.camaras_trampas_anp ENABLE ROW LEVEL SECURITY;

--
-- Name: carnet_pesca_deportiva; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.carnet_pesca_deportiva ENABLE ROW LEVEL SECURITY;

--
-- Name: carnet_pesca_subsistencia_comercial; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.carnet_pesca_subsistencia_comercial ENABLE ROW LEVEL SECURITY;

--
-- Name: caza_furtiva; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.caza_furtiva ENABLE ROW LEVEL SECURITY;

--
-- Name: centros_manejo_fauna; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.centros_manejo_fauna ENABLE ROW LEVEL SECURITY;

--
-- Name: control_forestal; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.control_forestal ENABLE ROW LEVEL SECURITY;

--
-- Name: criadero_fauna_silvestre; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.criadero_fauna_silvestre ENABLE ROW LEVEL SECURITY;

--
-- Name: departamentos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.departamentos ENABLE ROW LEVEL SECURITY;

--
-- Name: entrega_alevines; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.entrega_alevines ENABLE ROW LEVEL SECURITY;

--
-- Name: exoticas_invasoras; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.exoticas_invasoras ENABLE ROW LEVEL SECURITY;

--
-- Name: expedientes_impacto_ambiental; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.expedientes_impacto_ambiental ENABLE ROW LEVEL SECURITY;

--
-- Name: feedlots; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.feedlots ENABLE ROW LEVEL SECURITY;

--
-- Name: fitosanitarios_domisanitarios; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.fitosanitarios_domisanitarios ENABLE ROW LEVEL SECURITY;

--
-- Name: formularios; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.formularios ENABLE ROW LEVEL SECURITY;

--
-- Name: formularios formularios_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY formularios_delete ON public.formularios FOR DELETE USING (public.is_superadmin());


--
-- Name: formularios formularios_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY formularios_insert ON public.formularios FOR INSERT WITH CHECK (public.is_admin());


--
-- Name: frigorificos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.frigorificos ENABLE ROW LEVEL SECURITY;

--
-- Name: guardafauna_honorario; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.guardafauna_honorario ENABLE ROW LEVEL SECURITY;

--
-- Name: mapa_cauciones; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.mapa_cauciones ENABLE ROW LEVEL SECURITY;

--
-- Name: mascotismo_ilegal; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.mascotismo_ilegal ENABLE ROW LEVEL SECURITY;

--
-- Name: mataderos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.mataderos ENABLE ROW LEVEL SECURITY;

--
-- Name: municipios modify_municipios; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY modify_municipios ON public.municipios USING ((EXISTS ( SELECT 1
   FROM (public.usuarios_rol ur
     JOIN public.roles r ON ((r.id = ur.rol_id)))
  WHERE ((ur.user_id = auth.uid()) AND (r.nombre = ANY (ARRAY['admin'::text, 'superadmin'::text])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM (public.usuarios_rol ur
     JOIN public.roles r ON ((r.id = ur.rol_id)))
  WHERE ((ur.user_id = auth.uid()) AND (r.nombre = ANY (ARRAY['admin'::text, 'superadmin'::text]))))));


--
-- Name: monos_aulladores; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.monos_aulladores ENABLE ROW LEVEL SECURITY;

--
-- Name: monumentos_naturales_provinciales; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.monumentos_naturales_provinciales ENABLE ROW LEVEL SECURITY;

--
-- Name: perforaciones_constatadas; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.perforaciones_constatadas ENABLE ROW LEVEL SECURITY;

--
-- Name: perforaciones_registradas; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.perforaciones_registradas ENABLE ROW LEVEL SECURITY;

--
-- Name: plan_provincial_manejo_fuego; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.plan_provincial_manejo_fuego ENABLE ROW LEVEL SECURITY;

--
-- Name: planes_bosques; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.planes_bosques ENABLE ROW LEVEL SECURITY;

--
-- Name: planilla_auditoria; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.planilla_auditoria ENABLE ROW LEVEL SECURITY;

--
-- Name: procedencia_tipo; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.procedencia_tipo ENABLE ROW LEVEL SECURITY;

--
-- Name: profiles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

--
-- Name: registro_historico_coleccionistas; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.registro_historico_coleccionistas ENABLE ROW LEVEL SECURITY;

--
-- Name: registro_historico_viveros; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.registro_historico_viveros ENABLE ROW LEVEL SECURITY;

--
-- Name: registro_historico_viveros_medicinales; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.registro_historico_viveros_medicinales ENABLE ROW LEVEL SECURITY;

--
-- Name: registro_inscripciones_lotes_industrias_martillos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.registro_inscripciones_lotes_industrias_martillos ENABLE ROW LEVEL SECURITY;

--
-- Name: registros_casos_fiebre_amarilla; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.registros_casos_fiebre_amarilla ENABLE ROW LEVEL SECURITY;

--
-- Name: rehabilitacion_ingresos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.rehabilitacion_ingresos ENABLE ROW LEVEL SECURITY;

--
-- Name: rehabilitacion_plantel_estable; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.rehabilitacion_plantel_estable ENABLE ROW LEVEL SECURITY;

--
-- Name: residuos_peligrosos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.residuos_peligrosos ENABLE ROW LEVEL SECURITY;

--
-- Name: roles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;

--
-- Name: municipios select_municipios; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY select_municipios ON public.municipios FOR SELECT USING ((auth.uid() IS NOT NULL));


--
-- Name: solicitudes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.solicitudes ENABLE ROW LEVEL SECURITY;

--
-- Name: solicitudes_apeo_ejido_urbano; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.solicitudes_apeo_ejido_urbano ENABLE ROW LEVEL SECURITY;

--
-- Name: solicitudes_en_tramite; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.solicitudes_en_tramite ENABLE ROW LEVEL SECURITY;

--
-- Name: solicitudes superadmin_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY superadmin_all ON public.solicitudes TO authenticated USING ((EXISTS ( SELECT 1
   FROM (public.usuarios_rol ur
     JOIN public.roles r ON ((r.id = ur.rol_id)))
  WHERE ((ur.user_id = auth.uid()) AND (r.key = 'superadmin'::text)))));


--
-- Name: usuarios_areas superadmin_full_usuarios_areas; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY superadmin_full_usuarios_areas ON public.usuarios_areas USING ((EXISTS ( SELECT 1
   FROM (public.usuarios_rol ur
     JOIN public.roles r ON ((r.id = ur.rol_id)))
  WHERE ((ur.user_id = auth.uid()) AND (r.nombre = 'superadmin'::text)))));


--
-- Name: tenencia_fauna; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.tenencia_fauna ENABLE ROW LEVEL SECURITY;

--
-- Name: toma_muestras_arroyos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.toma_muestras_arroyos ENABLE ROW LEVEL SECURITY;

--
-- Name: toma_muestras_efluentes_industriales; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.toma_muestras_efluentes_industriales ENABLE ROW LEVEL SECURITY;

--
-- Name: usuarios_areas usuario_ve_sus_areas_rel; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY usuario_ve_sus_areas_rel ON public.usuarios_areas FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: usuarios_areas; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.usuarios_areas ENABLE ROW LEVEL SECURITY;

--
-- Name: usuarios_formularios; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.usuarios_formularios ENABLE ROW LEVEL SECURITY;

--
-- Name: usuarios_rol; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.usuarios_rol ENABLE ROW LEVEL SECURITY;

--
-- Name: vehiculos_secuestrados; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.vehiculos_secuestrados ENABLE ROW LEVEL SECURITY;

--
-- Name: vista_secuestros; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.vista_secuestros ENABLE ROW LEVEL SECURITY;

--
-- Name: vivero_el_puma; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.vivero_el_puma ENABLE ROW LEVEL SECURITY;

--
-- Name: objects Acceso autenticado audios; Type: POLICY; Schema: storage; Owner: -
--

CREATE POLICY "Acceso autenticado audios" ON storage.objects TO authenticated USING ((bucket_id = 'audios_incendios'::text)) WITH CHECK ((bucket_id = 'audios_incendios'::text));


--
-- Name: objects Acceso autenticado fotos; Type: POLICY; Schema: storage; Owner: -
--

CREATE POLICY "Acceso autenticado fotos" ON storage.objects TO authenticated USING ((bucket_id = 'fotos_incendios'::text)) WITH CHECK ((bucket_id = 'fotos_incendios'::text));


--
-- Name: objects Anonimos pueden subir fotos; Type: POLICY; Schema: storage; Owner: -
--

CREATE POLICY "Anonimos pueden subir fotos" ON storage.objects FOR INSERT TO anon WITH CHECK ((bucket_id = 'fotos_incendios'::text));


--
-- Name: objects Autenticados pueden leer audios; Type: POLICY; Schema: storage; Owner: -
--

CREATE POLICY "Autenticados pueden leer audios" ON storage.objects FOR SELECT TO authenticated USING ((bucket_id = 'audios_incendios'::text));


--
-- Name: objects Autenticados pueden leer fotos; Type: POLICY; Schema: storage; Owner: -
--

CREATE POLICY "Autenticados pueden leer fotos" ON storage.objects FOR SELECT TO authenticated USING ((bucket_id = 'fotos_incendios'::text));


--
-- Name: objects Autenticados pueden subir audios; Type: POLICY; Schema: storage; Owner: -
--

CREATE POLICY "Autenticados pueden subir audios" ON storage.objects FOR INSERT TO authenticated WITH CHECK ((bucket_id = 'audios_incendios'::text));


--
-- Name: objects Autenticados pueden subir fotos; Type: POLICY; Schema: storage; Owner: -
--

CREATE POLICY "Autenticados pueden subir fotos" ON storage.objects FOR INSERT TO authenticated WITH CHECK ((bucket_id = 'fotos_incendios'::text));


--
-- Name: objects Service role puede borrar reportes; Type: POLICY; Schema: storage; Owner: -
--

CREATE POLICY "Service role puede borrar reportes" ON storage.objects FOR DELETE TO service_role USING ((bucket_id = 'reportes'::text));


--
-- Name: objects Service role puede leer reportes; Type: POLICY; Schema: storage; Owner: -
--

CREATE POLICY "Service role puede leer reportes" ON storage.objects FOR SELECT TO service_role USING ((bucket_id = 'reportes'::text));


--
-- Name: objects Usuarios pueden subir reportes; Type: POLICY; Schema: storage; Owner: -
--

CREATE POLICY "Usuarios pueden subir reportes" ON storage.objects FOR INSERT TO authenticated WITH CHECK ((bucket_id = 'reportes'::text));


--
-- Name: objects Usuarios pueden ver sus reportes; Type: POLICY; Schema: storage; Owner: -
--

CREATE POLICY "Usuarios pueden ver sus reportes" ON storage.objects FOR SELECT TO authenticated USING (((bucket_id = 'reportes'::text) AND ((auth.uid())::text = (storage.foldername(name))[1])));


--
-- Name: buckets; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.buckets ENABLE ROW LEVEL SECURITY;

--
-- Name: buckets_analytics; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.buckets_analytics ENABLE ROW LEVEL SECURITY;

--
-- Name: buckets_vectors; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.buckets_vectors ENABLE ROW LEVEL SECURITY;

--
-- Name: iceberg_namespaces; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.iceberg_namespaces ENABLE ROW LEVEL SECURITY;

--
-- Name: iceberg_tables; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.iceberg_tables ENABLE ROW LEVEL SECURITY;

--
-- Name: migrations; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.migrations ENABLE ROW LEVEL SECURITY;

--
-- Name: objects; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

--
-- Name: prefixes; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.prefixes ENABLE ROW LEVEL SECURITY;

--
-- Name: s3_multipart_uploads; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.s3_multipart_uploads ENABLE ROW LEVEL SECURITY;

--
-- Name: s3_multipart_uploads_parts; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.s3_multipart_uploads_parts ENABLE ROW LEVEL SECURITY;

--
-- Name: vector_indexes; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.vector_indexes ENABLE ROW LEVEL SECURITY;

--
-- Name: supabase_realtime; Type: PUBLICATION; Schema: -; Owner: -
--

CREATE PUBLICATION supabase_realtime FOR ALL TABLES WITH (publish = 'insert, update, delete, truncate');


--
-- Name: supabase_realtime_messages_publication; Type: PUBLICATION; Schema: -; Owner: -
--

CREATE PUBLICATION supabase_realtime_messages_publication WITH (publish = 'insert, update, delete, truncate');


--
-- Name: issue_graphql_placeholder; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER issue_graphql_placeholder ON sql_drop
         WHEN TAG IN ('DROP EXTENSION')
   EXECUTE FUNCTION extensions.set_graphql_placeholder();


--
-- Name: issue_pg_cron_access; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER issue_pg_cron_access ON ddl_command_end
         WHEN TAG IN ('CREATE EXTENSION')
   EXECUTE FUNCTION extensions.grant_pg_cron_access();


--
-- Name: issue_pg_graphql_access; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER issue_pg_graphql_access ON ddl_command_end
         WHEN TAG IN ('CREATE FUNCTION')
   EXECUTE FUNCTION extensions.grant_pg_graphql_access();


--
-- Name: issue_pg_net_access; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER issue_pg_net_access ON ddl_command_end
         WHEN TAG IN ('CREATE EXTENSION')
   EXECUTE FUNCTION extensions.grant_pg_net_access();


--
-- Name: pgrst_ddl_watch; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER pgrst_ddl_watch ON ddl_command_end
   EXECUTE FUNCTION extensions.pgrst_ddl_watch();


--
-- Name: pgrst_drop_watch; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER pgrst_drop_watch ON sql_drop
   EXECUTE FUNCTION extensions.pgrst_drop_watch();


--
-- PostgreSQL database dump complete
--

