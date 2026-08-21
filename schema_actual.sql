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
-- Name: public; Type: SCHEMA; Schema: -; Owner: pg_database_owner
--

CREATE SCHEMA public;


ALTER SCHEMA public OWNER TO pg_database_owner;

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: pg_database_owner
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: check_is_admin(); Type: FUNCTION; Schema: public; Owner: postgres
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


ALTER FUNCTION public.check_is_admin() OWNER TO postgres;

--
-- Name: check_is_area_admin(); Type: FUNCTION; Schema: public; Owner: postgres
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


ALTER FUNCTION public.check_is_area_admin() OWNER TO postgres;

--
-- Name: check_is_superadmin(); Type: FUNCTION; Schema: public; Owner: postgres
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


ALTER FUNCTION public.check_is_superadmin() OWNER TO postgres;

--
-- Name: check_tables_exist(); Type: FUNCTION; Schema: public; Owner: postgres
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


ALTER FUNCTION public.check_tables_exist() OWNER TO postgres;

--
-- Name: check_user_in_area(uuid); Type: FUNCTION; Schema: public; Owner: postgres
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


ALTER FUNCTION public.check_user_in_area(target_area_id uuid) OWNER TO postgres;

--
-- Name: desvincular_usuario_registros(uuid); Type: FUNCTION; Schema: public; Owner: postgres
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


ALTER FUNCTION public.desvincular_usuario_registros(target_id uuid) OWNER TO postgres;

--
-- Name: exec_sql(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.exec_sql(sql_query text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  EXECUTE sql_query;
END;
$$;


ALTER FUNCTION public.exec_sql(sql_query text) OWNER TO postgres;

--
-- Name: fn_fill_geometry(); Type: FUNCTION; Schema: public; Owner: postgres
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


ALTER FUNCTION public.fn_fill_geometry() OWNER TO postgres;

--
-- Name: get_orphans_report(); Type: FUNCTION; Schema: public; Owner: postgres
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


ALTER FUNCTION public.get_orphans_report() OWNER TO postgres;

--
-- Name: get_orphans_report(uuid); Type: FUNCTION; Schema: public; Owner: postgres
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


ALTER FUNCTION public.get_orphans_report(p_area_id uuid) OWNER TO postgres;

--
-- Name: get_table_columns(text); Type: FUNCTION; Schema: public; Owner: supabase_admin
--

CREATE FUNCTION public.get_table_columns(p_table_name text) RETURNS TABLE(column_name text)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY 
  SELECT c.column_name::TEXT  -- Cast explícito para evitar mismatch de tipos
  FROM information_schema.columns c 
  WHERE c.table_name = p_table_name  -- Parámetro renombrado para evitar conflicto
    AND c.table_schema = 'public'
  ORDER BY c.ordinal_position;
END;
$$;


ALTER FUNCTION public.get_table_columns(p_table_name text) OWNER TO supabase_admin;

--
-- Name: get_table_metadata(text); Type: FUNCTION; Schema: public; Owner: supabase_admin
--

CREATE FUNCTION public.get_table_metadata(p_table_name text) RETURNS TABLE(column_name text, data_type text, is_nullable text, foreign_table text, foreign_column text)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.column_name::text,
        c.data_type::text,
        c.is_nullable::text,
        (
            SELECT ccu.table_name::text
            FROM information_schema.key_column_usage kcu
            JOIN information_schema.table_constraints tc 
                ON kcu.constraint_name = tc.constraint_name
                AND tc.table_schema = 'public'
            JOIN information_schema.constraint_column_usage ccu 
                ON tc.constraint_name = ccu.constraint_name
            WHERE kcu.table_schema = 'public'
              AND kcu.table_name = p_table_name
              AND kcu.column_name = c.column_name
              AND tc.constraint_type = 'FOREIGN KEY'
            LIMIT 1
        ) as foreign_table,
        (
            SELECT ccu.column_name::text
            FROM information_schema.key_column_usage kcu
            JOIN information_schema.table_constraints tc 
                ON kcu.constraint_name = tc.constraint_name
                AND tc.table_schema = 'public'
            JOIN information_schema.constraint_column_usage ccu 
                ON tc.constraint_name = ccu.constraint_name
            WHERE kcu.table_schema = 'public'
              AND kcu.table_name = p_table_name
              AND kcu.column_name = c.column_name
              AND tc.constraint_type = 'FOREIGN KEY'
            LIMIT 1
        ) as foreign_column
    FROM 
        information_schema.columns c
    WHERE 
        c.table_name = p_table_name
        AND c.table_schema = 'public'
    ORDER BY c.ordinal_position;
END;
$$;


ALTER FUNCTION public.get_table_metadata(p_table_name text) OWNER TO supabase_admin;

--
-- Name: get_usuarios_por_area(uuid); Type: FUNCTION; Schema: public; Owner: postgres
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


ALTER FUNCTION public.get_usuarios_por_area(p_area_id uuid) OWNER TO postgres;

--
-- Name: handle_new_user(); Type: FUNCTION; Schema: public; Owner: postgres
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


ALTER FUNCTION public.handle_new_user() OWNER TO postgres;

--
-- Name: is_admin(); Type: FUNCTION; Schema: public; Owner: postgres
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


ALTER FUNCTION public.is_admin() OWNER TO postgres;

--
-- Name: is_superadmin(); Type: FUNCTION; Schema: public; Owner: postgres
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


ALTER FUNCTION public.is_superadmin() OWNER TO postgres;

--
-- Name: orphan_records_from_user(uuid); Type: FUNCTION; Schema: public; Owner: postgres
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


ALTER FUNCTION public.orphan_records_from_user(target_user_id uuid) OWNER TO postgres;

--
-- Name: tiene_rol(text); Type: FUNCTION; Schema: public; Owner: postgres
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


ALTER FUNCTION public.tiene_rol(_rol text) OWNER TO postgres;

--
-- Name: update_geom_ataques_felinos(); Type: FUNCTION; Schema: public; Owner: postgres
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


ALTER FUNCTION public.update_geom_ataques_felinos() OWNER TO postgres;

--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_updated_at_column() OWNER TO postgres;

--
-- Name: usuario_en_area(uuid); Type: FUNCTION; Schema: public; Owner: postgres
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


ALTER FUNCTION public.usuario_en_area(_area_id uuid) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: actuaciones_control_guardaparques; Type: TABLE; Schema: public; Owner: postgres
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
    observaciones text,
    created_at timestamp with time zone DEFAULT now(),
    created_by uuid DEFAULT auth.uid(),
    user_id uuid DEFAULT auth.uid(),
    formulario_id uuid DEFAULT '48efcd89-3298-4951-8648-1263ed85b4a2'::uuid,
    activo boolean DEFAULT true,
    geom public.geometry(Point,4326),
    updated_at timestamp with time zone DEFAULT now(),
    actividad_id uuid
);

ALTER TABLE ONLY public.actuaciones_control_guardaparques REPLICA IDENTITY FULL;


ALTER TABLE public.actuaciones_control_guardaparques OWNER TO postgres;

--
-- Name: almidoneras; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.almidoneras OWNER TO postgres;

--
-- Name: aprovechamiento_pfnm; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.aprovechamiento_pfnm OWNER TO postgres;

--
-- Name: areas; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.areas OWNER TO postgres;

--
-- Name: areas_naturales_protegidas; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.areas_naturales_protegidas OWNER TO postgres;

--
-- Name: aspectos_sanitarios; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.aspectos_sanitarios (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre text NOT NULL,
    activo boolean DEFAULT true,
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.aspectos_sanitarios OWNER TO postgres;

--
-- Name: ataques_grandes_felinos; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.ataques_grandes_felinos OWNER TO postgres;

--
-- Name: atropellamiento_fauna_silvestre; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.atropellamiento_fauna_silvestre OWNER TO postgres;

--
-- Name: avistamiento_axis; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.avistamiento_axis OWNER TO postgres;

--
-- Name: bomberos_policia; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bomberos_policia (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    created_by uuid DEFAULT auth.uid(),
    user_id uuid DEFAULT auth.uid(),
    formulario_id uuid DEFAULT 'e4f40236-fb1d-4fa5-bbe0-9184caee2dcf'::uuid,
    activo boolean DEFAULT true,
    departamento_id uuid,
    municipio_id uuid,
    latitud_decimal numeric,
    longitud_decimal numeric,
    latitud_dms text,
    longitud_dms text,
    geom public.geometry(Point,4326),
    codigo text,
    fecha date,
    hora_inicio text,
    lugar_inf_minima text,
    acta_constatacion text,
    hectareas numeric,
    tipo_intervencion text
);


ALTER TABLE public.bomberos_policia OWNER TO postgres;

--
-- Name: camaras_trampas_anp; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.camaras_trampas_anp OWNER TO postgres;

--
-- Name: carnet_pesca_deportiva; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.carnet_pesca_deportiva OWNER TO postgres;

--
-- Name: carnet_pesca_subsistencia_comercial; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.carnet_pesca_subsistencia_comercial OWNER TO postgres;

--
-- Name: categorias_carnet_pesca_deportiva; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.categorias_carnet_pesca_deportiva (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre text NOT NULL,
    activo boolean DEFAULT true
);


ALTER TABLE public.categorias_carnet_pesca_deportiva OWNER TO postgres;

--
-- Name: caza_furtiva; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.caza_furtiva OWNER TO postgres;

--
-- Name: centros_manejo_fauna; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.centros_manejo_fauna OWNER TO postgres;

--
-- Name: control_forestal; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.control_forestal OWNER TO postgres;

--
-- Name: criadero_fauna_silvestre; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.criadero_fauna_silvestre OWNER TO postgres;

--
-- Name: departamentos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.departamentos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    codigo integer NOT NULL,
    nombre text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    activo boolean DEFAULT true,
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.departamentos OWNER TO postgres;

--
-- Name: destino_rehabilitacion; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.destino_rehabilitacion (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre text NOT NULL
);


ALTER TABLE public.destino_rehabilitacion OWNER TO postgres;

--
-- Name: entrega_alevines; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.entrega_alevines OWNER TO postgres;

--
-- Name: entrega_alevines_n_orden_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.entrega_alevines_n_orden_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.entrega_alevines_n_orden_seq OWNER TO postgres;

--
-- Name: entrega_alevines_n_orden_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.entrega_alevines_n_orden_seq OWNED BY public.entrega_alevines.n_orden;


--
-- Name: estados_aprovechamiento; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.estados_aprovechamiento (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre text NOT NULL,
    activo boolean DEFAULT true
);


ALTER TABLE public.estados_aprovechamiento OWNER TO postgres;

--
-- Name: estados_carnet_pesca; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.estados_carnet_pesca (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre text NOT NULL,
    activo boolean DEFAULT true
);


ALTER TABLE public.estados_carnet_pesca OWNER TO postgres;

--
-- Name: estados_conservacion; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.estados_conservacion (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre text NOT NULL,
    activo boolean DEFAULT true
);


ALTER TABLE public.estados_conservacion OWNER TO postgres;

--
-- Name: estados_tramite_honorario; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.estados_tramite_honorario (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre text NOT NULL,
    activo boolean DEFAULT true
);


ALTER TABLE public.estados_tramite_honorario OWNER TO postgres;

--
-- Name: exoticas_invasoras; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.exoticas_invasoras OWNER TO postgres;

--
-- Name: expedientes_impacto_ambiental; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.expedientes_impacto_ambiental (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    codigo_organismo text,
    nro_expte text,
    anio_expte integer,
    fecha_creacion_expte date,
    proponente text,
    cuit_cuil text,
    asunto text,
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
    departamento_id uuid,
    tipo_actividad_id uuid
);

ALTER TABLE ONLY public.expedientes_impacto_ambiental REPLICA IDENTITY FULL;


ALTER TABLE public.expedientes_impacto_ambiental OWNER TO postgres;

--
-- Name: feedlots; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.feedlots OWNER TO postgres;

--
-- Name: fitosanitarios_domisanitarios; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.fitosanitarios_domisanitarios OWNER TO postgres;

--
-- Name: formularios; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.formularios OWNER TO postgres;

--
-- Name: frigorificos; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.frigorificos OWNER TO postgres;

--
-- Name: guardafauna_honorario; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.guardafauna_honorario OWNER TO postgres;

--
-- Name: maestro_especies_tipo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.maestro_especies_tipo (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre text NOT NULL
);


ALTER TABLE public.maestro_especies_tipo OWNER TO postgres;

--
-- Name: maestro_meses; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.maestro_meses (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre text NOT NULL,
    orden integer
);


ALTER TABLE public.maestro_meses OWNER TO postgres;

--
-- Name: mapa_cauciones; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.mapa_cauciones OWNER TO postgres;

--
-- Name: mascotismo_ilegal; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.mascotismo_ilegal OWNER TO postgres;

--
-- Name: mataderos; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.mataderos OWNER TO postgres;

--
-- Name: mobile_apps; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.mobile_apps OWNER TO postgres;

--
-- Name: monos_aulladores; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.monos_aulladores OWNER TO postgres;

--
-- Name: monumentos_naturales_provinciales; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.monumentos_naturales_provinciales OWNER TO postgres;

--
-- Name: municipios; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.municipios OWNER TO postgres;

--
-- Name: origen_rehabilitacion; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.origen_rehabilitacion (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre text NOT NULL
);


ALTER TABLE public.origen_rehabilitacion OWNER TO postgres;

--
-- Name: perforaciones_constatadas; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.perforaciones_constatadas OWNER TO postgres;

--
-- Name: perforaciones_registradas; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.perforaciones_registradas OWNER TO postgres;

--
-- Name: plan_provincial_manejo_fuego; Type: TABLE; Schema: public; Owner: postgres
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
    latitud_gms text,
    longitud_gms text,
    geom public.geometry(Point,4326),
    ciudad_temp text
);


ALTER TABLE public.plan_provincial_manejo_fuego OWNER TO postgres;

--
-- Name: planes_bosques; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.planes_bosques OWNER TO postgres;

--
-- Name: planilla_auditoria; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.planilla_auditoria OWNER TO postgres;

--
-- Name: procedencia_tipo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.procedencia_tipo (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre text NOT NULL,
    activo boolean DEFAULT true,
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.procedencia_tipo OWNER TO postgres;

--
-- Name: profiles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.profiles (
    id uuid NOT NULL,
    full_name text,
    email text,
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.profiles OWNER TO postgres;

--
-- Name: registro_historico_coleccionistas; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.registro_historico_coleccionistas OWNER TO postgres;

--
-- Name: registro_historico_viveros; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.registro_historico_viveros OWNER TO postgres;

--
-- Name: registro_historico_viveros_medicinales; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.registro_historico_viveros_medicinales OWNER TO postgres;

--
-- Name: registro_inscripciones_lotes_industrias_martillos; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.registro_inscripciones_lotes_industrias_martillos OWNER TO postgres;

--
-- Name: registros_casos_fiebre_amarilla; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.registros_casos_fiebre_amarilla OWNER TO postgres;

--
-- Name: rehabilitacion_ingresos; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.rehabilitacion_ingresos OWNER TO postgres;

--
-- Name: rehabilitacion_plantel_estable; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.rehabilitacion_plantel_estable OWNER TO postgres;

--
-- Name: residuos_peligrosos; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.residuos_peligrosos OWNER TO postgres;

--
-- Name: roles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.roles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    key text NOT NULL,
    nombre text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    activo boolean DEFAULT true,
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.roles OWNER TO postgres;

--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone,
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.schema_migrations OWNER TO postgres;

--
-- Name: sectores_rehabilitacion; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sectores_rehabilitacion (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre text NOT NULL,
    activo boolean DEFAULT true
);


ALTER TABLE public.sectores_rehabilitacion OWNER TO postgres;

--
-- Name: situacion_expedientes_vehiculos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.situacion_expedientes_vehiculos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre text NOT NULL,
    activo boolean DEFAULT true
);


ALTER TABLE public.situacion_expedientes_vehiculos OWNER TO postgres;

--
-- Name: solicitudes; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.solicitudes OWNER TO postgres;

--
-- Name: COLUMN solicitudes.tipo; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.solicitudes.tipo IS 'Puede ser "registro" para nuevos o "update" para cambios de permisos';


--
-- Name: solicitudes_apeo_ejido_urbano; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.solicitudes_apeo_ejido_urbano OWNER TO postgres;

--
-- Name: solicitudes_en_tramite; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.solicitudes_en_tramite OWNER TO postgres;

--
-- Name: tenencia_fauna; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.tenencia_fauna OWNER TO postgres;

--
-- Name: tipo_actividad_guardaparques; Type: TABLE; Schema: public; Owner: supabase_admin
--

CREATE TABLE public.tipo_actividad_guardaparques (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre text,
    activo boolean,
    created_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.tipo_actividad_guardaparques OWNER TO supabase_admin;

--
-- Name: tipo_actividad_impacto_ambiental; Type: TABLE; Schema: public; Owner: supabase_admin
--

CREATE TABLE public.tipo_actividad_impacto_ambiental (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre text NOT NULL,
    activo boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.tipo_actividad_impacto_ambiental OWNER TO supabase_admin;

--
-- Name: tipo_intervencion; Type: TABLE; Schema: public; Owner: supabase_admin
--

CREATE TABLE public.tipo_intervencion (
    id bigint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    nombre text
);


ALTER TABLE public.tipo_intervencion OWNER TO supabase_admin;

--
-- Name: tipo_intervencion_id_seq; Type: SEQUENCE; Schema: public; Owner: supabase_admin
--

ALTER TABLE public.tipo_intervencion ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.tipo_intervencion_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tipos_fito_domi; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tipos_fito_domi (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre text NOT NULL,
    activo boolean DEFAULT true
);


ALTER TABLE public.tipos_fito_domi OWNER TO postgres;

--
-- Name: toma_muestras_arroyos; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.toma_muestras_arroyos OWNER TO postgres;

--
-- Name: toma_muestras_efluentes_industriales; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.toma_muestras_efluentes_industriales OWNER TO postgres;

--
-- Name: unidades_medida_aprovechamiento; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.unidades_medida_aprovechamiento (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre text NOT NULL,
    activo boolean DEFAULT true
);


ALTER TABLE public.unidades_medida_aprovechamiento OWNER TO postgres;

--
-- Name: usuarios_areas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.usuarios_areas (
    user_id uuid NOT NULL,
    area_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    activo boolean DEFAULT true,
    updated_at timestamp with time zone DEFAULT now(),
    es_editor boolean DEFAULT true
);


ALTER TABLE public.usuarios_areas OWNER TO postgres;

--
-- Name: COLUMN usuarios_areas.es_editor; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.usuarios_areas.es_editor IS 'Si es false, el usuario solo puede ver los datos del área sin modificarlos';


--
-- Name: usuarios_formularios; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.usuarios_formularios (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    formulario_id uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    es_editor boolean DEFAULT true
);


ALTER TABLE public.usuarios_formularios OWNER TO postgres;

--
-- Name: usuarios_rol; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.usuarios_rol (
    user_id uuid NOT NULL,
    rol_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    activo boolean DEFAULT true,
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.usuarios_rol OWNER TO postgres;

--
-- Name: v_formulario_impacto_ambiental; Type: VIEW; Schema: public; Owner: postgres
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


ALTER TABLE public.v_formulario_impacto_ambiental OWNER TO postgres;

--
-- Name: v_formulario_tenencia_fauna; Type: VIEW; Schema: public; Owner: postgres
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


ALTER TABLE public.v_formulario_tenencia_fauna OWNER TO postgres;

--
-- Name: vehiculos_secuestrados; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.vehiculos_secuestrados OWNER TO postgres;

--
-- Name: vista_secuestros; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.vista_secuestros OWNER TO postgres;

--
-- Name: vivero_el_puma; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.vivero_el_puma OWNER TO postgres;

--
-- Name: entrega_alevines n_orden; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.entrega_alevines ALTER COLUMN n_orden SET DEFAULT nextval('public.entrega_alevines_n_orden_seq'::regclass);


--
-- Name: actuaciones_control_guardaparques actuaciones_control_guardaparques_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actuaciones_control_guardaparques
    ADD CONSTRAINT actuaciones_control_guardaparques_pkey PRIMARY KEY (id);


--
-- Name: almidoneras almidoneras_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.almidoneras
    ADD CONSTRAINT almidoneras_pkey PRIMARY KEY (id);


--
-- Name: aprovechamiento_pfnm aprovechamiento_pfnm_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aprovechamiento_pfnm
    ADD CONSTRAINT aprovechamiento_pfnm_pkey PRIMARY KEY (id);


--
-- Name: areas areas_key_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.areas
    ADD CONSTRAINT areas_key_key UNIQUE (key);


--
-- Name: areas_naturales_protegidas areas_naturales_protegidas_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.areas_naturales_protegidas
    ADD CONSTRAINT areas_naturales_protegidas_pkey PRIMARY KEY (id);


--
-- Name: areas areas_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.areas
    ADD CONSTRAINT areas_pkey PRIMARY KEY (id);


--
-- Name: aspectos_sanitarios aspectos_sanitarios_nombre_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aspectos_sanitarios
    ADD CONSTRAINT aspectos_sanitarios_nombre_key UNIQUE (nombre);


--
-- Name: aspectos_sanitarios aspectos_sanitarios_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aspectos_sanitarios
    ADD CONSTRAINT aspectos_sanitarios_pkey PRIMARY KEY (id);


--
-- Name: ataques_grandes_felinos ataques_grandes_felinos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ataques_grandes_felinos
    ADD CONSTRAINT ataques_grandes_felinos_pkey PRIMARY KEY (id);


--
-- Name: atropellamiento_fauna_silvestre atropellamiento_fauna_silvestre_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.atropellamiento_fauna_silvestre
    ADD CONSTRAINT atropellamiento_fauna_silvestre_pkey PRIMARY KEY (id);


--
-- Name: avistamiento_axis avistamiento_axis_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.avistamiento_axis
    ADD CONSTRAINT avistamiento_axis_pkey PRIMARY KEY (id);


--
-- Name: bomberos_policia bomberos_policia_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bomberos_policia
    ADD CONSTRAINT bomberos_policia_pkey PRIMARY KEY (id);


--
-- Name: camaras_trampas_anp camaras_trampas_anp_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.camaras_trampas_anp
    ADD CONSTRAINT camaras_trampas_anp_pkey PRIMARY KEY (id);


--
-- Name: carnet_pesca_deportiva carnet_pesca_deportiva_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.carnet_pesca_deportiva
    ADD CONSTRAINT carnet_pesca_deportiva_pkey PRIMARY KEY (id);


--
-- Name: carnet_pesca_subsistencia_comercial carnet_pesca_subsistencia_comercial_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.carnet_pesca_subsistencia_comercial
    ADD CONSTRAINT carnet_pesca_subsistencia_comercial_pkey PRIMARY KEY (id);


--
-- Name: categorias_carnet_pesca_deportiva categorias_carnet_pesca_deportiva_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categorias_carnet_pesca_deportiva
    ADD CONSTRAINT categorias_carnet_pesca_deportiva_pkey PRIMARY KEY (id);


--
-- Name: caza_furtiva caza_furtiva_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.caza_furtiva
    ADD CONSTRAINT caza_furtiva_pkey PRIMARY KEY (id);


--
-- Name: centros_manejo_fauna centros_manejo_fauna_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.centros_manejo_fauna
    ADD CONSTRAINT centros_manejo_fauna_pkey PRIMARY KEY (id);


--
-- Name: control_forestal control_forestal_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.control_forestal
    ADD CONSTRAINT control_forestal_pkey PRIMARY KEY (id);


--
-- Name: criadero_fauna_silvestre criadero_fauna_silvestre_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.criadero_fauna_silvestre
    ADD CONSTRAINT criadero_fauna_silvestre_pkey PRIMARY KEY (id);


--
-- Name: departamentos departamentos_codigo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.departamentos
    ADD CONSTRAINT departamentos_codigo_key UNIQUE (codigo);


--
-- Name: departamentos departamentos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.departamentos
    ADD CONSTRAINT departamentos_pkey PRIMARY KEY (id);


--
-- Name: destino_rehabilitacion destino_rehabilitacion_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.destino_rehabilitacion
    ADD CONSTRAINT destino_rehabilitacion_pkey PRIMARY KEY (id);


--
-- Name: entrega_alevines entrega_alevines_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.entrega_alevines
    ADD CONSTRAINT entrega_alevines_pkey PRIMARY KEY (id);


--
-- Name: estados_aprovechamiento estados_aprovechamiento_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estados_aprovechamiento
    ADD CONSTRAINT estados_aprovechamiento_pkey PRIMARY KEY (id);


--
-- Name: estados_carnet_pesca estados_carnet_pesca_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estados_carnet_pesca
    ADD CONSTRAINT estados_carnet_pesca_pkey PRIMARY KEY (id);


--
-- Name: estados_conservacion estados_conservacion_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estados_conservacion
    ADD CONSTRAINT estados_conservacion_pkey PRIMARY KEY (id);


--
-- Name: estados_tramite_honorario estados_tramite_honorario_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estados_tramite_honorario
    ADD CONSTRAINT estados_tramite_honorario_pkey PRIMARY KEY (id);


--
-- Name: exoticas_invasoras exoticas_invasoras_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.exoticas_invasoras
    ADD CONSTRAINT exoticas_invasoras_pkey PRIMARY KEY (id);


--
-- Name: feedlots feedlots_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.feedlots
    ADD CONSTRAINT feedlots_pkey PRIMARY KEY (id);


--
-- Name: fitosanitarios_domisanitarios fitosanitarios_domisanitarios_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fitosanitarios_domisanitarios
    ADD CONSTRAINT fitosanitarios_domisanitarios_pkey PRIMARY KEY (id);


--
-- Name: formularios formularios_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.formularios
    ADD CONSTRAINT formularios_pkey PRIMARY KEY (id);


--
-- Name: formularios formularios_slug_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.formularios
    ADD CONSTRAINT formularios_slug_key UNIQUE (slug);


--
-- Name: frigorificos frigorificos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.frigorificos
    ADD CONSTRAINT frigorificos_pkey PRIMARY KEY (id);


--
-- Name: guardafauna_honorario guardafauna_honorario_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.guardafauna_honorario
    ADD CONSTRAINT guardafauna_honorario_pkey PRIMARY KEY (id);


--
-- Name: expedientes_impacto_ambiental impacto_ambiental_expedientes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.expedientes_impacto_ambiental
    ADD CONSTRAINT impacto_ambiental_expedientes_pkey PRIMARY KEY (id);


--
-- Name: maestro_especies_tipo maestro_especies_tipo_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.maestro_especies_tipo
    ADD CONSTRAINT maestro_especies_tipo_pkey PRIMARY KEY (id);


--
-- Name: maestro_meses maestro_meses_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.maestro_meses
    ADD CONSTRAINT maestro_meses_pkey PRIMARY KEY (id);


--
-- Name: mapa_cauciones mapa_cauciones_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mapa_cauciones
    ADD CONSTRAINT mapa_cauciones_pkey PRIMARY KEY (id);


--
-- Name: mascotismo_ilegal mascotismo_ilegal_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mascotismo_ilegal
    ADD CONSTRAINT mascotismo_ilegal_pkey PRIMARY KEY (id);


--
-- Name: mataderos mataderos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mataderos
    ADD CONSTRAINT mataderos_pkey PRIMARY KEY (id);


--
-- Name: mobile_apps mobile_apps_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mobile_apps
    ADD CONSTRAINT mobile_apps_pkey PRIMARY KEY (id);


--
-- Name: monos_aulladores monos_aulladores_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.monos_aulladores
    ADD CONSTRAINT monos_aulladores_pkey PRIMARY KEY (id);


--
-- Name: monumentos_naturales_provinciales monumentos_naturales_provinciales_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.monumentos_naturales_provinciales
    ADD CONSTRAINT monumentos_naturales_provinciales_pkey PRIMARY KEY (id);


--
-- Name: municipios municipios_nombre_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.municipios
    ADD CONSTRAINT municipios_nombre_key UNIQUE (nombre);


--
-- Name: municipios municipios_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.municipios
    ADD CONSTRAINT municipios_pkey PRIMARY KEY (id);


--
-- Name: origen_rehabilitacion origen_rehabilitacion_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.origen_rehabilitacion
    ADD CONSTRAINT origen_rehabilitacion_pkey PRIMARY KEY (id);


--
-- Name: perforaciones_constatadas perforaciones_constatadas_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.perforaciones_constatadas
    ADD CONSTRAINT perforaciones_constatadas_pkey PRIMARY KEY (id);


--
-- Name: perforaciones_registradas perforaciones_registradas_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.perforaciones_registradas
    ADD CONSTRAINT perforaciones_registradas_pkey PRIMARY KEY (id);


--
-- Name: plan_provincial_manejo_fuego plan_provincial_manejo_fuego_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.plan_provincial_manejo_fuego
    ADD CONSTRAINT plan_provincial_manejo_fuego_pkey PRIMARY KEY (id);


--
-- Name: planes_bosques planes_bosques_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.planes_bosques
    ADD CONSTRAINT planes_bosques_pkey PRIMARY KEY (id);


--
-- Name: planilla_auditoria planilla_auditoria_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.planilla_auditoria
    ADD CONSTRAINT planilla_auditoria_pkey PRIMARY KEY (id);


--
-- Name: procedencia_tipo procedencia_tipo_nombre_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.procedencia_tipo
    ADD CONSTRAINT procedencia_tipo_nombre_key UNIQUE (nombre);


--
-- Name: procedencia_tipo procedencia_tipo_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.procedencia_tipo
    ADD CONSTRAINT procedencia_tipo_pkey PRIMARY KEY (id);


--
-- Name: profiles profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);


--
-- Name: registro_historico_coleccionistas registro_historico_coleccionistas_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.registro_historico_coleccionistas
    ADD CONSTRAINT registro_historico_coleccionistas_pkey PRIMARY KEY (id);


--
-- Name: registro_historico_viveros_medicinales registro_historico_viveros_medicinales_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.registro_historico_viveros_medicinales
    ADD CONSTRAINT registro_historico_viveros_medicinales_pkey PRIMARY KEY (id);


--
-- Name: registro_historico_viveros registro_historico_viveros_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.registro_historico_viveros
    ADD CONSTRAINT registro_historico_viveros_pkey PRIMARY KEY (id);


--
-- Name: registro_inscripciones_lotes_industrias_martillos registro_inscripciones_lotes_industrias_martillos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.registro_inscripciones_lotes_industrias_martillos
    ADD CONSTRAINT registro_inscripciones_lotes_industrias_martillos_pkey PRIMARY KEY (id);


--
-- Name: registros_casos_fiebre_amarilla registros_casos_fiebre_amarilla_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.registros_casos_fiebre_amarilla
    ADD CONSTRAINT registros_casos_fiebre_amarilla_pkey PRIMARY KEY (id);


--
-- Name: rehabilitacion_ingresos rehabilitacion_ingresos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rehabilitacion_ingresos
    ADD CONSTRAINT rehabilitacion_ingresos_pkey PRIMARY KEY (id);


--
-- Name: rehabilitacion_plantel_estable rehabilitacion_plantel_estable_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rehabilitacion_plantel_estable
    ADD CONSTRAINT rehabilitacion_plantel_estable_pkey PRIMARY KEY (id);


--
-- Name: residuos_peligrosos residuos_peligrosos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.residuos_peligrosos
    ADD CONSTRAINT residuos_peligrosos_pkey PRIMARY KEY (id);


--
-- Name: roles roles_key_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_key_key UNIQUE (key);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: sectores_rehabilitacion sectores_rehabilitacion_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sectores_rehabilitacion
    ADD CONSTRAINT sectores_rehabilitacion_pkey PRIMARY KEY (id);


--
-- Name: situacion_expedientes_vehiculos situacion_expedientes_vehiculos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.situacion_expedientes_vehiculos
    ADD CONSTRAINT situacion_expedientes_vehiculos_pkey PRIMARY KEY (id);


--
-- Name: solicitudes_apeo_ejido_urbano solicitudes_apeo_ejido_urbano_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.solicitudes_apeo_ejido_urbano
    ADD CONSTRAINT solicitudes_apeo_ejido_urbano_pkey PRIMARY KEY (id);


--
-- Name: solicitudes_en_tramite solicitudes_en_tramite_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.solicitudes_en_tramite
    ADD CONSTRAINT solicitudes_en_tramite_pkey PRIMARY KEY (id);


--
-- Name: solicitudes solicitudes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.solicitudes
    ADD CONSTRAINT solicitudes_pkey PRIMARY KEY (id);


--
-- Name: tenencia_fauna tenencia_fauna_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tenencia_fauna
    ADD CONSTRAINT tenencia_fauna_pkey PRIMARY KEY (id);


--
-- Name: tipo_actividad_guardaparques tipo_actividad_guardaparques_pkey; Type: CONSTRAINT; Schema: public; Owner: supabase_admin
--

ALTER TABLE ONLY public.tipo_actividad_guardaparques
    ADD CONSTRAINT tipo_actividad_guardaparques_pkey PRIMARY KEY (id);


--
-- Name: tipo_actividad_impacto_ambiental tipo_actividad_impacto_ambiental_pkey; Type: CONSTRAINT; Schema: public; Owner: supabase_admin
--

ALTER TABLE ONLY public.tipo_actividad_impacto_ambiental
    ADD CONSTRAINT tipo_actividad_impacto_ambiental_pkey PRIMARY KEY (id);


--
-- Name: tipo_intervencion tipo_intervencion_nombre_key; Type: CONSTRAINT; Schema: public; Owner: supabase_admin
--

ALTER TABLE ONLY public.tipo_intervencion
    ADD CONSTRAINT tipo_intervencion_nombre_key UNIQUE (nombre);


--
-- Name: tipo_intervencion tipo_intervencion_pkey; Type: CONSTRAINT; Schema: public; Owner: supabase_admin
--

ALTER TABLE ONLY public.tipo_intervencion
    ADD CONSTRAINT tipo_intervencion_pkey PRIMARY KEY (id);


--
-- Name: tipos_fito_domi tipos_fito_domi_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipos_fito_domi
    ADD CONSTRAINT tipos_fito_domi_pkey PRIMARY KEY (id);


--
-- Name: toma_muestras_arroyos toma_muestras_arroyos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.toma_muestras_arroyos
    ADD CONSTRAINT toma_muestras_arroyos_pkey PRIMARY KEY (id);


--
-- Name: toma_muestras_efluentes_industriales toma_muestras_efluentes_industriales_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.toma_muestras_efluentes_industriales
    ADD CONSTRAINT toma_muestras_efluentes_industriales_pkey PRIMARY KEY (id);


--
-- Name: unidades_medida_aprovechamiento unidades_medida_aprovechamiento_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.unidades_medida_aprovechamiento
    ADD CONSTRAINT unidades_medida_aprovechamiento_pkey PRIMARY KEY (id);


--
-- Name: expedientes_impacto_ambiental unique_expediente; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.expedientes_impacto_ambiental
    ADD CONSTRAINT unique_expediente UNIQUE (nro_expte, anio_expte, formulario_id);


--
-- Name: usuarios_areas usuarios_areas_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios_areas
    ADD CONSTRAINT usuarios_areas_pkey PRIMARY KEY (user_id, area_id);


--
-- Name: usuarios_formularios usuarios_formularios_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios_formularios
    ADD CONSTRAINT usuarios_formularios_pkey PRIMARY KEY (id);


--
-- Name: usuarios_formularios usuarios_formularios_user_id_formulario_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios_formularios
    ADD CONSTRAINT usuarios_formularios_user_id_formulario_id_key UNIQUE (user_id, formulario_id);


--
-- Name: usuarios_rol usuarios_rol_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios_rol
    ADD CONSTRAINT usuarios_rol_pkey PRIMARY KEY (user_id);


--
-- Name: vehiculos_secuestrados vehiculos_secuestrados_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vehiculos_secuestrados
    ADD CONSTRAINT vehiculos_secuestrados_pkey PRIMARY KEY (id);


--
-- Name: vista_secuestros vista_secuestros_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vista_secuestros
    ADD CONSTRAINT vista_secuestros_pkey PRIMARY KEY (id);


--
-- Name: vivero_el_puma vivero_el_puma_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vivero_el_puma
    ADD CONSTRAINT vivero_el_puma_pkey PRIMARY KEY (id);


--
-- Name: areas_nombre_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX areas_nombre_idx ON public.areas USING btree (nombre);


--
-- Name: formularios_activo_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX formularios_activo_idx ON public.formularios USING btree (activo);


--
-- Name: formularios_area_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX formularios_area_id_idx ON public.formularios USING btree (area_id);


--
-- Name: formularios_area_id_idx1; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX formularios_area_id_idx1 ON public.formularios USING btree (area_id);


--
-- Name: formularios_slug_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX formularios_slug_idx ON public.formularios USING btree (slug);


--
-- Name: idx_departamentos_codigo; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_departamentos_codigo ON public.departamentos USING btree (codigo);


--
-- Name: idx_expedientes_geom; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_expedientes_geom ON public.expedientes_impacto_ambiental USING gist (geom);


--
-- Name: idx_impacto_expte_codigo_municipio; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_impacto_expte_codigo_municipio ON public.expedientes_impacto_ambiental USING btree (codigo_municipio);


--
-- Name: idx_impacto_expte_created_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_impacto_expte_created_at ON public.expedientes_impacto_ambiental USING btree (created_at);


--
-- Name: idx_impacto_expte_created_by; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_impacto_expte_created_by ON public.expedientes_impacto_ambiental USING btree (created_by);


--
-- Name: idx_impacto_expte_formulario; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_impacto_expte_formulario ON public.expedientes_impacto_ambiental USING btree (formulario_id);


--
-- Name: idx_impacto_expte_municipio; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_impacto_expte_municipio ON public.expedientes_impacto_ambiental USING btree (municipio_id);


--
-- Name: idx_impacto_expte_nro; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_impacto_expte_nro ON public.expedientes_impacto_ambiental USING btree (nro_expte, anio_expte);


--
-- Name: idx_mobile_apps_slug; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_mobile_apps_slug ON public.mobile_apps USING btree (formulario_slug);


--
-- Name: idx_municipios_codigo_municipio; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_municipios_codigo_municipio ON public.municipios USING btree (codigo_municipio);


--
-- Name: idx_municipios_departamento_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_municipios_departamento_id ON public.municipios USING btree (departamento_id);


--
-- Name: idx_user_form_form; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_form_form ON public.usuarios_formularios USING btree (formulario_id);


--
-- Name: idx_user_form_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_form_user ON public.usuarios_formularios USING btree (user_id);


--
-- Name: idx_usuarios_rol_rol; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_usuarios_rol_rol ON public.usuarios_rol USING btree (rol_id);


--
-- Name: municipios_nombre_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX municipios_nombre_idx ON public.municipios USING btree (nombre);


--
-- Name: actuaciones_control_guardaparques tr_auto_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.actuaciones_control_guardaparques FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: almidoneras tr_auto_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.almidoneras FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: aprovechamiento_pfnm tr_auto_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.aprovechamiento_pfnm FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: areas_naturales_protegidas tr_auto_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.areas_naturales_protegidas FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: ataques_grandes_felinos tr_auto_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.ataques_grandes_felinos FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: atropellamiento_fauna_silvestre tr_auto_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.atropellamiento_fauna_silvestre FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: avistamiento_axis tr_auto_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.avistamiento_axis FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: camaras_trampas_anp tr_auto_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.camaras_trampas_anp FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: carnet_pesca_deportiva tr_auto_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.carnet_pesca_deportiva FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: carnet_pesca_subsistencia_comercial tr_auto_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.carnet_pesca_subsistencia_comercial FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: caza_furtiva tr_auto_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.caza_furtiva FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: centros_manejo_fauna tr_auto_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.centros_manejo_fauna FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: control_forestal tr_auto_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.control_forestal FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: criadero_fauna_silvestre tr_auto_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.criadero_fauna_silvestre FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: entrega_alevines tr_auto_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.entrega_alevines FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: exoticas_invasoras tr_auto_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.exoticas_invasoras FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: expedientes_impacto_ambiental tr_auto_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.expedientes_impacto_ambiental FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: feedlots tr_auto_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.feedlots FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: fitosanitarios_domisanitarios tr_auto_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.fitosanitarios_domisanitarios FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: frigorificos tr_auto_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.frigorificos FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: guardafauna_honorario tr_auto_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.guardafauna_honorario FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: mapa_cauciones tr_auto_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.mapa_cauciones FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: mascotismo_ilegal tr_auto_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.mascotismo_ilegal FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: mataderos tr_auto_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.mataderos FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: monos_aulladores tr_auto_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.monos_aulladores FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: monumentos_naturales_provinciales tr_auto_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.monumentos_naturales_provinciales FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: perforaciones_constatadas tr_auto_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.perforaciones_constatadas FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: perforaciones_registradas tr_auto_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.perforaciones_registradas FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: planes_bosques tr_auto_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.planes_bosques FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: planilla_auditoria tr_auto_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.planilla_auditoria FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: registro_inscripciones_lotes_industrias_martillos tr_auto_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.registro_inscripciones_lotes_industrias_martillos FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: rehabilitacion_ingresos tr_auto_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.rehabilitacion_ingresos FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: rehabilitacion_plantel_estable tr_auto_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.rehabilitacion_plantel_estable FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: residuos_peligrosos tr_auto_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.residuos_peligrosos FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: solicitudes_apeo_ejido_urbano tr_auto_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.solicitudes_apeo_ejido_urbano FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: tenencia_fauna tr_auto_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.tenencia_fauna FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: toma_muestras_arroyos tr_auto_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.toma_muestras_arroyos FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: toma_muestras_efluentes_industriales tr_auto_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.toma_muestras_efluentes_industriales FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: vista_secuestros tr_auto_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.vista_secuestros FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: vivero_el_puma tr_auto_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_auto_geom BEFORE INSERT OR UPDATE ON public.vivero_el_puma FOR EACH ROW EXECUTE FUNCTION public.fn_fill_geometry();


--
-- Name: registro_historico_coleccionistas tr_upd_hist_coleccionistas; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_upd_hist_coleccionistas BEFORE UPDATE ON public.registro_historico_coleccionistas FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: registro_historico_viveros tr_upd_hist_viveros; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_upd_hist_viveros BEFORE UPDATE ON public.registro_historico_viveros FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: registro_historico_viveros_medicinales tr_upd_hist_viveros_med; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_upd_hist_viveros_med BEFORE UPDATE ON public.registro_historico_viveros_medicinales FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: solicitudes_en_tramite tr_upd_solicitudes_tramite; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_upd_solicitudes_tramite BEFORE UPDATE ON public.solicitudes_en_tramite FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: carnet_pesca_deportiva tr_update_carnet_pesca_deportiva_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_update_carnet_pesca_deportiva_updated_at BEFORE UPDATE ON public.carnet_pesca_deportiva FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: carnet_pesca_subsistencia_comercial tr_update_carnet_pesca_subsistencia_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_update_carnet_pesca_subsistencia_updated_at BEFORE UPDATE ON public.carnet_pesca_subsistencia_comercial FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: centros_manejo_fauna tr_update_centros_manejo_fauna_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_update_centros_manejo_fauna_updated_at BEFORE UPDATE ON public.centros_manejo_fauna FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: exoticas_invasoras tr_update_exoticas_invasoras_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_update_exoticas_invasoras_updated_at BEFORE UPDATE ON public.exoticas_invasoras FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: registros_casos_fiebre_amarilla tr_update_fiebre_amarilla_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_update_fiebre_amarilla_updated_at BEFORE UPDATE ON public.registros_casos_fiebre_amarilla FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: fitosanitarios_domisanitarios tr_update_fitosanitarios_domi_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_update_fitosanitarios_domi_updated_at BEFORE UPDATE ON public.fitosanitarios_domisanitarios FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: guardafauna_honorario tr_update_guardafauna_honorario_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_update_guardafauna_honorario_updated_at BEFORE UPDATE ON public.guardafauna_honorario FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: monos_aulladores tr_update_monos_aulladores_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_update_monos_aulladores_updated_at BEFORE UPDATE ON public.monos_aulladores FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: monumentos_naturales_provinciales tr_update_monumentos_naturales_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_update_monumentos_naturales_updated_at BEFORE UPDATE ON public.monumentos_naturales_provinciales FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: perforaciones_constatadas tr_update_perforaciones_constatadas_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_update_perforaciones_constatadas_updated_at BEFORE UPDATE ON public.perforaciones_constatadas FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: perforaciones_registradas tr_update_perforaciones_registradas_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_update_perforaciones_registradas_updated_at BEFORE UPDATE ON public.perforaciones_registradas FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: plan_provincial_manejo_fuego tr_update_plan_fuego_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_update_plan_fuego_updated_at BEFORE UPDATE ON public.plan_provincial_manejo_fuego FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: planilla_auditoria tr_update_planilla_auditoria_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_update_planilla_auditoria_updated_at BEFORE UPDATE ON public.planilla_auditoria FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: rehabilitacion_plantel_estable tr_update_plantel_estable_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_update_plantel_estable_updated_at BEFORE UPDATE ON public.rehabilitacion_plantel_estable FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: rehabilitacion_ingresos tr_update_rehabilitacion_ingresos_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_update_rehabilitacion_ingresos_updated_at BEFORE UPDATE ON public.rehabilitacion_ingresos FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: solicitudes_apeo_ejido_urbano tr_update_solicitudes_apeo_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_update_solicitudes_apeo_updated_at BEFORE UPDATE ON public.solicitudes_apeo_ejido_urbano FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: vehiculos_secuestrados tr_update_vehiculos_secuestrados_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_update_vehiculos_secuestrados_updated_at BEFORE UPDATE ON public.vehiculos_secuestrados FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: vista_secuestros tr_update_vista_secuestros_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_update_vista_secuestros_updated_at BEFORE UPDATE ON public.vista_secuestros FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: actuaciones_control_guardaparques actuaciones_control_guardaparques_actividad_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actuaciones_control_guardaparques
    ADD CONSTRAINT actuaciones_control_guardaparques_actividad_id_fkey FOREIGN KEY (actividad_id) REFERENCES public.tipo_actividad_guardaparques(id);


--
-- Name: actuaciones_control_guardaparques actuaciones_control_guardaparques_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actuaciones_control_guardaparques
    ADD CONSTRAINT actuaciones_control_guardaparques_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: actuaciones_control_guardaparques actuaciones_control_guardaparques_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actuaciones_control_guardaparques
    ADD CONSTRAINT actuaciones_control_guardaparques_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: actuaciones_control_guardaparques actuaciones_control_guardaparques_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actuaciones_control_guardaparques
    ADD CONSTRAINT actuaciones_control_guardaparques_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: actuaciones_control_guardaparques actuaciones_control_guardaparques_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actuaciones_control_guardaparques
    ADD CONSTRAINT actuaciones_control_guardaparques_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: almidoneras almidoneras_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.almidoneras
    ADD CONSTRAINT almidoneras_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: almidoneras almidoneras_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.almidoneras
    ADD CONSTRAINT almidoneras_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: almidoneras almidoneras_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.almidoneras
    ADD CONSTRAINT almidoneras_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: almidoneras almidoneras_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.almidoneras
    ADD CONSTRAINT almidoneras_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: aprovechamiento_pfnm aprovechamiento_pfnm_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aprovechamiento_pfnm
    ADD CONSTRAINT aprovechamiento_pfnm_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: aprovechamiento_pfnm aprovechamiento_pfnm_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aprovechamiento_pfnm
    ADD CONSTRAINT aprovechamiento_pfnm_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: aprovechamiento_pfnm aprovechamiento_pfnm_estado_tramite_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aprovechamiento_pfnm
    ADD CONSTRAINT aprovechamiento_pfnm_estado_tramite_id_fkey FOREIGN KEY (estado_tramite_id) REFERENCES public.estados_aprovechamiento(id);


--
-- Name: aprovechamiento_pfnm aprovechamiento_pfnm_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aprovechamiento_pfnm
    ADD CONSTRAINT aprovechamiento_pfnm_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: aprovechamiento_pfnm aprovechamiento_pfnm_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aprovechamiento_pfnm
    ADD CONSTRAINT aprovechamiento_pfnm_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: aprovechamiento_pfnm aprovechamiento_pfnm_unidad_medida_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aprovechamiento_pfnm
    ADD CONSTRAINT aprovechamiento_pfnm_unidad_medida_id_fkey FOREIGN KEY (unidad_medida_id) REFERENCES public.unidades_medida_aprovechamiento(id);


--
-- Name: aprovechamiento_pfnm aprovechamiento_pfnm_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aprovechamiento_pfnm
    ADD CONSTRAINT aprovechamiento_pfnm_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: areas_naturales_protegidas areas_naturales_protegidas_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.areas_naturales_protegidas
    ADD CONSTRAINT areas_naturales_protegidas_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: areas_naturales_protegidas areas_naturales_protegidas_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.areas_naturales_protegidas
    ADD CONSTRAINT areas_naturales_protegidas_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: areas_naturales_protegidas areas_naturales_protegidas_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.areas_naturales_protegidas
    ADD CONSTRAINT areas_naturales_protegidas_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: areas_naturales_protegidas areas_naturales_protegidas_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.areas_naturales_protegidas
    ADD CONSTRAINT areas_naturales_protegidas_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: ataques_grandes_felinos ataques_grandes_felinos_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ataques_grandes_felinos
    ADD CONSTRAINT ataques_grandes_felinos_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: ataques_grandes_felinos ataques_grandes_felinos_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ataques_grandes_felinos
    ADD CONSTRAINT ataques_grandes_felinos_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: ataques_grandes_felinos ataques_grandes_felinos_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ataques_grandes_felinos
    ADD CONSTRAINT ataques_grandes_felinos_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: atropellamiento_fauna_silvestre atropellamiento_fauna_silvestre_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.atropellamiento_fauna_silvestre
    ADD CONSTRAINT atropellamiento_fauna_silvestre_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: atropellamiento_fauna_silvestre atropellamiento_fauna_silvestre_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.atropellamiento_fauna_silvestre
    ADD CONSTRAINT atropellamiento_fauna_silvestre_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: atropellamiento_fauna_silvestre atropellamiento_fauna_silvestre_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.atropellamiento_fauna_silvestre
    ADD CONSTRAINT atropellamiento_fauna_silvestre_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: avistamiento_axis avistamiento_axis_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.avistamiento_axis
    ADD CONSTRAINT avistamiento_axis_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: avistamiento_axis avistamiento_axis_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.avistamiento_axis
    ADD CONSTRAINT avistamiento_axis_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: avistamiento_axis avistamiento_axis_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.avistamiento_axis
    ADD CONSTRAINT avistamiento_axis_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: avistamiento_axis avistamiento_axis_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.avistamiento_axis
    ADD CONSTRAINT avistamiento_axis_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: bomberos_policia bomberos_policia_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bomberos_policia
    ADD CONSTRAINT bomberos_policia_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: bomberos_policia bomberos_policia_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bomberos_policia
    ADD CONSTRAINT bomberos_policia_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: bomberos_policia bomberos_policia_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bomberos_policia
    ADD CONSTRAINT bomberos_policia_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: bomberos_policia bomberos_policia_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bomberos_policia
    ADD CONSTRAINT bomberos_policia_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: bomberos_policia bomberos_policia_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bomberos_policia
    ADD CONSTRAINT bomberos_policia_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: camaras_trampas_anp camaras_trampas_anp_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.camaras_trampas_anp
    ADD CONSTRAINT camaras_trampas_anp_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: camaras_trampas_anp camaras_trampas_anp_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.camaras_trampas_anp
    ADD CONSTRAINT camaras_trampas_anp_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: camaras_trampas_anp camaras_trampas_anp_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.camaras_trampas_anp
    ADD CONSTRAINT camaras_trampas_anp_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: carnet_pesca_deportiva carnet_pesca_deportiva_categoria_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.carnet_pesca_deportiva
    ADD CONSTRAINT carnet_pesca_deportiva_categoria_id_fkey FOREIGN KEY (categoria_id) REFERENCES public.categorias_carnet_pesca_deportiva(id);


--
-- Name: carnet_pesca_deportiva carnet_pesca_deportiva_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.carnet_pesca_deportiva
    ADD CONSTRAINT carnet_pesca_deportiva_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: carnet_pesca_deportiva carnet_pesca_deportiva_delegacion_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.carnet_pesca_deportiva
    ADD CONSTRAINT carnet_pesca_deportiva_delegacion_id_fkey FOREIGN KEY (delegacion_id) REFERENCES public.municipios(id);


--
-- Name: carnet_pesca_deportiva carnet_pesca_deportiva_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.carnet_pesca_deportiva
    ADD CONSTRAINT carnet_pesca_deportiva_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: carnet_pesca_deportiva carnet_pesca_deportiva_estado_carnet_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.carnet_pesca_deportiva
    ADD CONSTRAINT carnet_pesca_deportiva_estado_carnet_id_fkey FOREIGN KEY (estado_carnet_id) REFERENCES public.estados_carnet_pesca(id);


--
-- Name: carnet_pesca_deportiva carnet_pesca_deportiva_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.carnet_pesca_deportiva
    ADD CONSTRAINT carnet_pesca_deportiva_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: carnet_pesca_deportiva carnet_pesca_deportiva_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.carnet_pesca_deportiva
    ADD CONSTRAINT carnet_pesca_deportiva_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: carnet_pesca_deportiva carnet_pesca_deportiva_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.carnet_pesca_deportiva
    ADD CONSTRAINT carnet_pesca_deportiva_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: carnet_pesca_subsistencia_comercial carnet_pesca_subsistencia_comercial_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.carnet_pesca_subsistencia_comercial
    ADD CONSTRAINT carnet_pesca_subsistencia_comercial_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: carnet_pesca_subsistencia_comercial carnet_pesca_subsistencia_comercial_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.carnet_pesca_subsistencia_comercial
    ADD CONSTRAINT carnet_pesca_subsistencia_comercial_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: carnet_pesca_subsistencia_comercial carnet_pesca_subsistencia_comercial_estado_carnet_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.carnet_pesca_subsistencia_comercial
    ADD CONSTRAINT carnet_pesca_subsistencia_comercial_estado_carnet_id_fkey FOREIGN KEY (estado_carnet_id) REFERENCES public.estados_carnet_pesca(id);


--
-- Name: carnet_pesca_subsistencia_comercial carnet_pesca_subsistencia_comercial_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.carnet_pesca_subsistencia_comercial
    ADD CONSTRAINT carnet_pesca_subsistencia_comercial_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: carnet_pesca_subsistencia_comercial carnet_pesca_subsistencia_comercial_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.carnet_pesca_subsistencia_comercial
    ADD CONSTRAINT carnet_pesca_subsistencia_comercial_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: carnet_pesca_subsistencia_comercial carnet_pesca_subsistencia_comercial_municipio_relacion_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.carnet_pesca_subsistencia_comercial
    ADD CONSTRAINT carnet_pesca_subsistencia_comercial_municipio_relacion_id_fkey FOREIGN KEY (municipio_relacion_id) REFERENCES public.municipios(id);


--
-- Name: carnet_pesca_subsistencia_comercial carnet_pesca_subsistencia_comercial_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.carnet_pesca_subsistencia_comercial
    ADD CONSTRAINT carnet_pesca_subsistencia_comercial_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: caza_furtiva caza_furtiva_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.caza_furtiva
    ADD CONSTRAINT caza_furtiva_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: caza_furtiva caza_furtiva_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.caza_furtiva
    ADD CONSTRAINT caza_furtiva_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: caza_furtiva caza_furtiva_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.caza_furtiva
    ADD CONSTRAINT caza_furtiva_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: centros_manejo_fauna centros_manejo_fauna_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.centros_manejo_fauna
    ADD CONSTRAINT centros_manejo_fauna_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: centros_manejo_fauna centros_manejo_fauna_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.centros_manejo_fauna
    ADD CONSTRAINT centros_manejo_fauna_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: centros_manejo_fauna centros_manejo_fauna_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.centros_manejo_fauna
    ADD CONSTRAINT centros_manejo_fauna_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: centros_manejo_fauna centros_manejo_fauna_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.centros_manejo_fauna
    ADD CONSTRAINT centros_manejo_fauna_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: centros_manejo_fauna centros_manejo_fauna_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.centros_manejo_fauna
    ADD CONSTRAINT centros_manejo_fauna_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: control_forestal control_forestal_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.control_forestal
    ADD CONSTRAINT control_forestal_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: control_forestal control_forestal_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.control_forestal
    ADD CONSTRAINT control_forestal_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: control_forestal control_forestal_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.control_forestal
    ADD CONSTRAINT control_forestal_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: control_forestal control_forestal_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.control_forestal
    ADD CONSTRAINT control_forestal_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: criadero_fauna_silvestre criadero_fauna_silvestre_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.criadero_fauna_silvestre
    ADD CONSTRAINT criadero_fauna_silvestre_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: criadero_fauna_silvestre criadero_fauna_silvestre_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.criadero_fauna_silvestre
    ADD CONSTRAINT criadero_fauna_silvestre_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: criadero_fauna_silvestre criadero_fauna_silvestre_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.criadero_fauna_silvestre
    ADD CONSTRAINT criadero_fauna_silvestre_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: entrega_alevines entrega_alevines_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.entrega_alevines
    ADD CONSTRAINT entrega_alevines_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: entrega_alevines entrega_alevines_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.entrega_alevines
    ADD CONSTRAINT entrega_alevines_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: entrega_alevines entrega_alevines_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.entrega_alevines
    ADD CONSTRAINT entrega_alevines_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: exoticas_invasoras exoticas_invasoras_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.exoticas_invasoras
    ADD CONSTRAINT exoticas_invasoras_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: exoticas_invasoras exoticas_invasoras_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.exoticas_invasoras
    ADD CONSTRAINT exoticas_invasoras_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: exoticas_invasoras exoticas_invasoras_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.exoticas_invasoras
    ADD CONSTRAINT exoticas_invasoras_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: exoticas_invasoras exoticas_invasoras_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.exoticas_invasoras
    ADD CONSTRAINT exoticas_invasoras_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: exoticas_invasoras exoticas_invasoras_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.exoticas_invasoras
    ADD CONSTRAINT exoticas_invasoras_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: expedientes_impacto_ambiental expedientes_impacto_ambiental_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.expedientes_impacto_ambiental
    ADD CONSTRAINT expedientes_impacto_ambiental_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: expedientes_impacto_ambiental expedientes_impacto_ambiental_tipo_actividad_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.expedientes_impacto_ambiental
    ADD CONSTRAINT expedientes_impacto_ambiental_tipo_actividad_id_fkey FOREIGN KEY (tipo_actividad_id) REFERENCES public.tipo_actividad_impacto_ambiental(id) ON DELETE SET NULL;


--
-- Name: feedlots feedlots_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.feedlots
    ADD CONSTRAINT feedlots_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: feedlots feedlots_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.feedlots
    ADD CONSTRAINT feedlots_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: feedlots feedlots_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.feedlots
    ADD CONSTRAINT feedlots_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: feedlots feedlots_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.feedlots
    ADD CONSTRAINT feedlots_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: fitosanitarios_domisanitarios fitosanitarios_domisanitarios_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fitosanitarios_domisanitarios
    ADD CONSTRAINT fitosanitarios_domisanitarios_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: fitosanitarios_domisanitarios fitosanitarios_domisanitarios_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fitosanitarios_domisanitarios
    ADD CONSTRAINT fitosanitarios_domisanitarios_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: fitosanitarios_domisanitarios fitosanitarios_domisanitarios_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fitosanitarios_domisanitarios
    ADD CONSTRAINT fitosanitarios_domisanitarios_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: fitosanitarios_domisanitarios fitosanitarios_domisanitarios_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fitosanitarios_domisanitarios
    ADD CONSTRAINT fitosanitarios_domisanitarios_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: fitosanitarios_domisanitarios fitosanitarios_domisanitarios_tipo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fitosanitarios_domisanitarios
    ADD CONSTRAINT fitosanitarios_domisanitarios_tipo_id_fkey FOREIGN KEY (tipo_id) REFERENCES public.tipos_fito_domi(id);


--
-- Name: fitosanitarios_domisanitarios fitosanitarios_domisanitarios_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fitosanitarios_domisanitarios
    ADD CONSTRAINT fitosanitarios_domisanitarios_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: municipios fk_municipios_departamento; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.municipios
    ADD CONSTRAINT fk_municipios_departamento FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id) ON DELETE RESTRICT;


--
-- Name: tenencia_fauna fk_tenencia_fauna_created_by; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tenencia_fauna
    ADD CONSTRAINT fk_tenencia_fauna_created_by FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: formularios formularios_area_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.formularios
    ADD CONSTRAINT formularios_area_id_fkey FOREIGN KEY (area_id) REFERENCES public.areas(id) ON DELETE CASCADE;


--
-- Name: frigorificos frigorificos_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.frigorificos
    ADD CONSTRAINT frigorificos_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: frigorificos frigorificos_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.frigorificos
    ADD CONSTRAINT frigorificos_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: frigorificos frigorificos_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.frigorificos
    ADD CONSTRAINT frigorificos_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: frigorificos frigorificos_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.frigorificos
    ADD CONSTRAINT frigorificos_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: guardafauna_honorario guardafauna_honorario_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.guardafauna_honorario
    ADD CONSTRAINT guardafauna_honorario_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: guardafauna_honorario guardafauna_honorario_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.guardafauna_honorario
    ADD CONSTRAINT guardafauna_honorario_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: guardafauna_honorario guardafauna_honorario_estado_tramite_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.guardafauna_honorario
    ADD CONSTRAINT guardafauna_honorario_estado_tramite_id_fkey FOREIGN KEY (estado_tramite_id) REFERENCES public.estados_tramite_honorario(id);


--
-- Name: guardafauna_honorario guardafauna_honorario_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.guardafauna_honorario
    ADD CONSTRAINT guardafauna_honorario_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: guardafauna_honorario guardafauna_honorario_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.guardafauna_honorario
    ADD CONSTRAINT guardafauna_honorario_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: guardafauna_honorario guardafauna_honorario_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.guardafauna_honorario
    ADD CONSTRAINT guardafauna_honorario_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: expedientes_impacto_ambiental impacto_ambiental_expedientes_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.expedientes_impacto_ambiental
    ADD CONSTRAINT impacto_ambiental_expedientes_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: expedientes_impacto_ambiental impacto_ambiental_expedientes_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.expedientes_impacto_ambiental
    ADD CONSTRAINT impacto_ambiental_expedientes_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: expedientes_impacto_ambiental impacto_ambiental_expedientes_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.expedientes_impacto_ambiental
    ADD CONSTRAINT impacto_ambiental_expedientes_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: expedientes_impacto_ambiental impacto_ambiental_expedientes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.expedientes_impacto_ambiental
    ADD CONSTRAINT impacto_ambiental_expedientes_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: mapa_cauciones mapa_cauciones_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mapa_cauciones
    ADD CONSTRAINT mapa_cauciones_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: mapa_cauciones mapa_cauciones_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mapa_cauciones
    ADD CONSTRAINT mapa_cauciones_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: mapa_cauciones mapa_cauciones_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mapa_cauciones
    ADD CONSTRAINT mapa_cauciones_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: mapa_cauciones mapa_cauciones_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mapa_cauciones
    ADD CONSTRAINT mapa_cauciones_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: mapa_cauciones mapa_cauciones_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mapa_cauciones
    ADD CONSTRAINT mapa_cauciones_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: mascotismo_ilegal mascotismo_ilegal_aspecto_sanitario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mascotismo_ilegal
    ADD CONSTRAINT mascotismo_ilegal_aspecto_sanitario_id_fkey FOREIGN KEY (aspecto_sanitario_id) REFERENCES public.aspectos_sanitarios(id);


--
-- Name: mascotismo_ilegal mascotismo_ilegal_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mascotismo_ilegal
    ADD CONSTRAINT mascotismo_ilegal_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: mascotismo_ilegal mascotismo_ilegal_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mascotismo_ilegal
    ADD CONSTRAINT mascotismo_ilegal_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: mascotismo_ilegal mascotismo_ilegal_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mascotismo_ilegal
    ADD CONSTRAINT mascotismo_ilegal_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: mascotismo_ilegal mascotismo_ilegal_procedencia_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mascotismo_ilegal
    ADD CONSTRAINT mascotismo_ilegal_procedencia_id_fkey FOREIGN KEY (procedencia_id) REFERENCES public.procedencia_tipo(id);


--
-- Name: mataderos mataderos_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mataderos
    ADD CONSTRAINT mataderos_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: mataderos mataderos_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mataderos
    ADD CONSTRAINT mataderos_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: mataderos mataderos_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mataderos
    ADD CONSTRAINT mataderos_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: mataderos mataderos_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mataderos
    ADD CONSTRAINT mataderos_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: monos_aulladores monos_aulladores_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.monos_aulladores
    ADD CONSTRAINT monos_aulladores_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: monos_aulladores monos_aulladores_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.monos_aulladores
    ADD CONSTRAINT monos_aulladores_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: monos_aulladores monos_aulladores_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.monos_aulladores
    ADD CONSTRAINT monos_aulladores_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: monos_aulladores monos_aulladores_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.monos_aulladores
    ADD CONSTRAINT monos_aulladores_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: monos_aulladores monos_aulladores_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.monos_aulladores
    ADD CONSTRAINT monos_aulladores_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: monumentos_naturales_provinciales monumentos_naturales_provinci_estado_conservacion_internac_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.monumentos_naturales_provinciales
    ADD CONSTRAINT monumentos_naturales_provinci_estado_conservacion_internac_fkey FOREIGN KEY (estado_conservacion_internacional_id) REFERENCES public.estados_conservacion(id);


--
-- Name: monumentos_naturales_provinciales monumentos_naturales_provinci_estado_conservacion_nacional_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.monumentos_naturales_provinciales
    ADD CONSTRAINT monumentos_naturales_provinci_estado_conservacion_nacional_fkey FOREIGN KEY (estado_conservacion_nacional_id) REFERENCES public.estados_conservacion(id);


--
-- Name: monumentos_naturales_provinciales monumentos_naturales_provinci_estado_conservacion_provinci_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.monumentos_naturales_provinciales
    ADD CONSTRAINT monumentos_naturales_provinci_estado_conservacion_provinci_fkey FOREIGN KEY (estado_conservacion_provincial_id) REFERENCES public.estados_conservacion(id);


--
-- Name: monumentos_naturales_provinciales monumentos_naturales_provinciales_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.monumentos_naturales_provinciales
    ADD CONSTRAINT monumentos_naturales_provinciales_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: monumentos_naturales_provinciales monumentos_naturales_provinciales_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.monumentos_naturales_provinciales
    ADD CONSTRAINT monumentos_naturales_provinciales_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: monumentos_naturales_provinciales monumentos_naturales_provinciales_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.monumentos_naturales_provinciales
    ADD CONSTRAINT monumentos_naturales_provinciales_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: monumentos_naturales_provinciales monumentos_naturales_provinciales_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.monumentos_naturales_provinciales
    ADD CONSTRAINT monumentos_naturales_provinciales_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: monumentos_naturales_provinciales monumentos_naturales_provinciales_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.monumentos_naturales_provinciales
    ADD CONSTRAINT monumentos_naturales_provinciales_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: perforaciones_constatadas perforaciones_constatadas_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.perforaciones_constatadas
    ADD CONSTRAINT perforaciones_constatadas_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: perforaciones_constatadas perforaciones_constatadas_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.perforaciones_constatadas
    ADD CONSTRAINT perforaciones_constatadas_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: perforaciones_constatadas perforaciones_constatadas_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.perforaciones_constatadas
    ADD CONSTRAINT perforaciones_constatadas_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: perforaciones_constatadas perforaciones_constatadas_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.perforaciones_constatadas
    ADD CONSTRAINT perforaciones_constatadas_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: perforaciones_constatadas perforaciones_constatadas_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.perforaciones_constatadas
    ADD CONSTRAINT perforaciones_constatadas_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: perforaciones_registradas perforaciones_registradas_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.perforaciones_registradas
    ADD CONSTRAINT perforaciones_registradas_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: perforaciones_registradas perforaciones_registradas_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.perforaciones_registradas
    ADD CONSTRAINT perforaciones_registradas_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: perforaciones_registradas perforaciones_registradas_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.perforaciones_registradas
    ADD CONSTRAINT perforaciones_registradas_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: perforaciones_registradas perforaciones_registradas_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.perforaciones_registradas
    ADD CONSTRAINT perforaciones_registradas_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: perforaciones_registradas perforaciones_registradas_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.perforaciones_registradas
    ADD CONSTRAINT perforaciones_registradas_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: plan_provincial_manejo_fuego plan_provincial_manejo_fuego_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.plan_provincial_manejo_fuego
    ADD CONSTRAINT plan_provincial_manejo_fuego_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: plan_provincial_manejo_fuego plan_provincial_manejo_fuego_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.plan_provincial_manejo_fuego
    ADD CONSTRAINT plan_provincial_manejo_fuego_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: plan_provincial_manejo_fuego plan_provincial_manejo_fuego_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.plan_provincial_manejo_fuego
    ADD CONSTRAINT plan_provincial_manejo_fuego_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: plan_provincial_manejo_fuego plan_provincial_manejo_fuego_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.plan_provincial_manejo_fuego
    ADD CONSTRAINT plan_provincial_manejo_fuego_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: plan_provincial_manejo_fuego plan_provincial_manejo_fuego_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.plan_provincial_manejo_fuego
    ADD CONSTRAINT plan_provincial_manejo_fuego_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: planes_bosques planes_bosques_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.planes_bosques
    ADD CONSTRAINT planes_bosques_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: planes_bosques planes_bosques_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.planes_bosques
    ADD CONSTRAINT planes_bosques_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: planes_bosques planes_bosques_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.planes_bosques
    ADD CONSTRAINT planes_bosques_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: planes_bosques planes_bosques_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.planes_bosques
    ADD CONSTRAINT planes_bosques_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: planes_bosques planes_bosques_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.planes_bosques
    ADD CONSTRAINT planes_bosques_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: planilla_auditoria planilla_auditoria_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.planilla_auditoria
    ADD CONSTRAINT planilla_auditoria_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: planilla_auditoria planilla_auditoria_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.planilla_auditoria
    ADD CONSTRAINT planilla_auditoria_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: planilla_auditoria planilla_auditoria_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.planilla_auditoria
    ADD CONSTRAINT planilla_auditoria_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: planilla_auditoria planilla_auditoria_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.planilla_auditoria
    ADD CONSTRAINT planilla_auditoria_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: planilla_auditoria planilla_auditoria_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.planilla_auditoria
    ADD CONSTRAINT planilla_auditoria_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: profiles profiles_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: registro_inscripciones_lotes_industrias_martillos registro_inscripciones_lotes_industrias_ma_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.registro_inscripciones_lotes_industrias_martillos
    ADD CONSTRAINT registro_inscripciones_lotes_industrias_ma_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: registro_inscripciones_lotes_industrias_martillos registro_inscripciones_lotes_industrias_mart_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.registro_inscripciones_lotes_industrias_martillos
    ADD CONSTRAINT registro_inscripciones_lotes_industrias_mart_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: registro_inscripciones_lotes_industrias_martillos registro_inscripciones_lotes_industrias_marti_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.registro_inscripciones_lotes_industrias_martillos
    ADD CONSTRAINT registro_inscripciones_lotes_industrias_marti_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: registro_inscripciones_lotes_industrias_martillos registro_inscripciones_lotes_industrias_martill_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.registro_inscripciones_lotes_industrias_martillos
    ADD CONSTRAINT registro_inscripciones_lotes_industrias_martill_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: registro_inscripciones_lotes_industrias_martillos registro_inscripciones_lotes_industrias_martillos_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.registro_inscripciones_lotes_industrias_martillos
    ADD CONSTRAINT registro_inscripciones_lotes_industrias_martillos_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: registros_casos_fiebre_amarilla registros_casos_fiebre_amarilla_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.registros_casos_fiebre_amarilla
    ADD CONSTRAINT registros_casos_fiebre_amarilla_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: registros_casos_fiebre_amarilla registros_casos_fiebre_amarilla_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.registros_casos_fiebre_amarilla
    ADD CONSTRAINT registros_casos_fiebre_amarilla_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: registros_casos_fiebre_amarilla registros_casos_fiebre_amarilla_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.registros_casos_fiebre_amarilla
    ADD CONSTRAINT registros_casos_fiebre_amarilla_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: registros_casos_fiebre_amarilla registros_casos_fiebre_amarilla_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.registros_casos_fiebre_amarilla
    ADD CONSTRAINT registros_casos_fiebre_amarilla_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: registros_casos_fiebre_amarilla registros_casos_fiebre_amarilla_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.registros_casos_fiebre_amarilla
    ADD CONSTRAINT registros_casos_fiebre_amarilla_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: rehabilitacion_ingresos rehabilitacion_ingresos_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rehabilitacion_ingresos
    ADD CONSTRAINT rehabilitacion_ingresos_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: rehabilitacion_ingresos rehabilitacion_ingresos_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rehabilitacion_ingresos
    ADD CONSTRAINT rehabilitacion_ingresos_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: rehabilitacion_ingresos rehabilitacion_ingresos_destino_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rehabilitacion_ingresos
    ADD CONSTRAINT rehabilitacion_ingresos_destino_id_fkey FOREIGN KEY (destino_id) REFERENCES public.destino_rehabilitacion(id);


--
-- Name: rehabilitacion_ingresos rehabilitacion_ingresos_especie_tipo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rehabilitacion_ingresos
    ADD CONSTRAINT rehabilitacion_ingresos_especie_tipo_id_fkey FOREIGN KEY (especie_tipo_id) REFERENCES public.maestro_especies_tipo(id);


--
-- Name: rehabilitacion_ingresos rehabilitacion_ingresos_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rehabilitacion_ingresos
    ADD CONSTRAINT rehabilitacion_ingresos_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: rehabilitacion_ingresos rehabilitacion_ingresos_mes_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rehabilitacion_ingresos
    ADD CONSTRAINT rehabilitacion_ingresos_mes_id_fkey FOREIGN KEY (mes_id) REFERENCES public.maestro_meses(id);


--
-- Name: rehabilitacion_ingresos rehabilitacion_ingresos_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rehabilitacion_ingresos
    ADD CONSTRAINT rehabilitacion_ingresos_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: rehabilitacion_ingresos rehabilitacion_ingresos_origen_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rehabilitacion_ingresos
    ADD CONSTRAINT rehabilitacion_ingresos_origen_id_fkey FOREIGN KEY (origen_id) REFERENCES public.origen_rehabilitacion(id);


--
-- Name: rehabilitacion_ingresos rehabilitacion_ingresos_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rehabilitacion_ingresos
    ADD CONSTRAINT rehabilitacion_ingresos_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: rehabilitacion_plantel_estable rehabilitacion_plantel_estable_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rehabilitacion_plantel_estable
    ADD CONSTRAINT rehabilitacion_plantel_estable_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: rehabilitacion_plantel_estable rehabilitacion_plantel_estable_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rehabilitacion_plantel_estable
    ADD CONSTRAINT rehabilitacion_plantel_estable_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: rehabilitacion_plantel_estable rehabilitacion_plantel_estable_especie_tipo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rehabilitacion_plantel_estable
    ADD CONSTRAINT rehabilitacion_plantel_estable_especie_tipo_id_fkey FOREIGN KEY (especie_tipo_id) REFERENCES public.maestro_especies_tipo(id);


--
-- Name: rehabilitacion_plantel_estable rehabilitacion_plantel_estable_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rehabilitacion_plantel_estable
    ADD CONSTRAINT rehabilitacion_plantel_estable_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: rehabilitacion_plantel_estable rehabilitacion_plantel_estable_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rehabilitacion_plantel_estable
    ADD CONSTRAINT rehabilitacion_plantel_estable_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: rehabilitacion_plantel_estable rehabilitacion_plantel_estable_sector_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rehabilitacion_plantel_estable
    ADD CONSTRAINT rehabilitacion_plantel_estable_sector_id_fkey FOREIGN KEY (sector_id) REFERENCES public.sectores_rehabilitacion(id);


--
-- Name: rehabilitacion_plantel_estable rehabilitacion_plantel_estable_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rehabilitacion_plantel_estable
    ADD CONSTRAINT rehabilitacion_plantel_estable_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: residuos_peligrosos residuos_peligrosos_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.residuos_peligrosos
    ADD CONSTRAINT residuos_peligrosos_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: residuos_peligrosos residuos_peligrosos_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.residuos_peligrosos
    ADD CONSTRAINT residuos_peligrosos_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: residuos_peligrosos residuos_peligrosos_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.residuos_peligrosos
    ADD CONSTRAINT residuos_peligrosos_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: residuos_peligrosos residuos_peligrosos_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.residuos_peligrosos
    ADD CONSTRAINT residuos_peligrosos_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: solicitudes_apeo_ejido_urbano solicitudes_apeo_ejido_urbano_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.solicitudes_apeo_ejido_urbano
    ADD CONSTRAINT solicitudes_apeo_ejido_urbano_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: solicitudes_apeo_ejido_urbano solicitudes_apeo_ejido_urbano_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.solicitudes_apeo_ejido_urbano
    ADD CONSTRAINT solicitudes_apeo_ejido_urbano_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: solicitudes_apeo_ejido_urbano solicitudes_apeo_ejido_urbano_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.solicitudes_apeo_ejido_urbano
    ADD CONSTRAINT solicitudes_apeo_ejido_urbano_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: solicitudes_apeo_ejido_urbano solicitudes_apeo_ejido_urbano_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.solicitudes_apeo_ejido_urbano
    ADD CONSTRAINT solicitudes_apeo_ejido_urbano_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: solicitudes_apeo_ejido_urbano solicitudes_apeo_ejido_urbano_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.solicitudes_apeo_ejido_urbano
    ADD CONSTRAINT solicitudes_apeo_ejido_urbano_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: solicitudes solicitudes_rol_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.solicitudes
    ADD CONSTRAINT solicitudes_rol_id_fkey FOREIGN KEY (rol_id) REFERENCES public.roles(id);


--
-- Name: solicitudes solicitudes_solicitante_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.solicitudes
    ADD CONSTRAINT solicitudes_solicitante_id_fkey FOREIGN KEY (solicitante_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: solicitudes solicitudes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.solicitudes
    ADD CONSTRAINT solicitudes_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: tenencia_fauna tenencia_fauna_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tenencia_fauna
    ADD CONSTRAINT tenencia_fauna_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: tenencia_fauna tenencia_fauna_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tenencia_fauna
    ADD CONSTRAINT tenencia_fauna_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: tenencia_fauna tenencia_fauna_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tenencia_fauna
    ADD CONSTRAINT tenencia_fauna_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: toma_muestras_arroyos toma_muestras_arroyos_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.toma_muestras_arroyos
    ADD CONSTRAINT toma_muestras_arroyos_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: toma_muestras_arroyos toma_muestras_arroyos_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.toma_muestras_arroyos
    ADD CONSTRAINT toma_muestras_arroyos_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: toma_muestras_arroyos toma_muestras_arroyos_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.toma_muestras_arroyos
    ADD CONSTRAINT toma_muestras_arroyos_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: toma_muestras_arroyos toma_muestras_arroyos_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.toma_muestras_arroyos
    ADD CONSTRAINT toma_muestras_arroyos_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: toma_muestras_efluentes_industriales toma_muestras_efluentes_industriales_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.toma_muestras_efluentes_industriales
    ADD CONSTRAINT toma_muestras_efluentes_industriales_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: toma_muestras_efluentes_industriales toma_muestras_efluentes_industriales_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.toma_muestras_efluentes_industriales
    ADD CONSTRAINT toma_muestras_efluentes_industriales_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: toma_muestras_efluentes_industriales toma_muestras_efluentes_industriales_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.toma_muestras_efluentes_industriales
    ADD CONSTRAINT toma_muestras_efluentes_industriales_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: toma_muestras_efluentes_industriales toma_muestras_efluentes_industriales_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.toma_muestras_efluentes_industriales
    ADD CONSTRAINT toma_muestras_efluentes_industriales_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: usuarios_areas usuarios_areas_area_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios_areas
    ADD CONSTRAINT usuarios_areas_area_id_fkey FOREIGN KEY (area_id) REFERENCES public.areas(id) ON DELETE CASCADE;


--
-- Name: usuarios_areas usuarios_areas_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios_areas
    ADD CONSTRAINT usuarios_areas_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: usuarios_formularios usuarios_formularios_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios_formularios
    ADD CONSTRAINT usuarios_formularios_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id) ON DELETE CASCADE;


--
-- Name: usuarios_formularios usuarios_formularios_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios_formularios
    ADD CONSTRAINT usuarios_formularios_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: usuarios_rol usuarios_rol_rol_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios_rol
    ADD CONSTRAINT usuarios_rol_rol_id_fkey FOREIGN KEY (rol_id) REFERENCES public.roles(id) ON DELETE CASCADE;


--
-- Name: usuarios_rol usuarios_rol_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios_rol
    ADD CONSTRAINT usuarios_rol_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: vehiculos_secuestrados vehiculos_secuestrados_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vehiculos_secuestrados
    ADD CONSTRAINT vehiculos_secuestrados_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: vehiculos_secuestrados vehiculos_secuestrados_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vehiculos_secuestrados
    ADD CONSTRAINT vehiculos_secuestrados_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: vehiculos_secuestrados vehiculos_secuestrados_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vehiculos_secuestrados
    ADD CONSTRAINT vehiculos_secuestrados_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: vehiculos_secuestrados vehiculos_secuestrados_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vehiculos_secuestrados
    ADD CONSTRAINT vehiculos_secuestrados_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: vehiculos_secuestrados vehiculos_secuestrados_situacion_expediente_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vehiculos_secuestrados
    ADD CONSTRAINT vehiculos_secuestrados_situacion_expediente_id_fkey FOREIGN KEY (situacion_expediente_id) REFERENCES public.situacion_expedientes_vehiculos(id);


--
-- Name: vehiculos_secuestrados vehiculos_secuestrados_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vehiculos_secuestrados
    ADD CONSTRAINT vehiculos_secuestrados_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: vista_secuestros vista_secuestros_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vista_secuestros
    ADD CONSTRAINT vista_secuestros_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: vista_secuestros vista_secuestros_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vista_secuestros
    ADD CONSTRAINT vista_secuestros_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: vista_secuestros vista_secuestros_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vista_secuestros
    ADD CONSTRAINT vista_secuestros_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: vista_secuestros vista_secuestros_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vista_secuestros
    ADD CONSTRAINT vista_secuestros_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: vista_secuestros vista_secuestros_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vista_secuestros
    ADD CONSTRAINT vista_secuestros_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: vivero_el_puma vivero_el_puma_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vivero_el_puma
    ADD CONSTRAINT vivero_el_puma_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: vivero_el_puma vivero_el_puma_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vivero_el_puma
    ADD CONSTRAINT vivero_el_puma_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);


--
-- Name: vivero_el_puma vivero_el_puma_formulario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vivero_el_puma
    ADD CONSTRAINT vivero_el_puma_formulario_id_fkey FOREIGN KEY (formulario_id) REFERENCES public.formularios(id);


--
-- Name: vivero_el_puma vivero_el_puma_municipio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vivero_el_puma
    ADD CONSTRAINT vivero_el_puma_municipio_id_fkey FOREIGN KEY (municipio_id) REFERENCES public.municipios(id);


--
-- Name: vivero_el_puma vivero_el_puma_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vivero_el_puma
    ADD CONSTRAINT vivero_el_puma_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: formularios Acceso por asignacion; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Acceso por asignacion" ON public.formularios FOR SELECT TO authenticated USING (((activo = true) OR (EXISTS ( SELECT 1
   FROM public.usuarios_formularios
  WHERE ((usuarios_formularios.user_id = auth.uid()) AND (usuarios_formularios.formulario_id = formularios.id)))) OR public.is_admin()));


--
-- Name: municipios Acceso publico lectura municipios; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Acceso publico lectura municipios" ON public.municipios FOR SELECT USING (true);


--
-- Name: departamentos Departamentos delete service; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Departamentos delete service" ON public.departamentos FOR DELETE USING ((auth.role() = 'service_role'::text));


--
-- Name: departamentos Departamentos insert service; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Departamentos insert service" ON public.departamentos FOR INSERT WITH CHECK ((auth.role() = 'service_role'::text));


--
-- Name: departamentos Departamentos readable; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Departamentos readable" ON public.departamentos FOR SELECT USING (true);


--
-- Name: departamentos Departamentos update service; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Departamentos update service" ON public.departamentos FOR UPDATE USING ((auth.role() = 'service_role'::text));


--
-- Name: perforaciones_registradas Gestion_dueño_o_admin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_dueño_o_admin" ON public.perforaciones_registradas TO authenticated USING ((public.check_is_admin() OR (auth.uid() = user_id) OR (auth.uid() = created_by)));


--
-- Name: planes_bosques Gestion_dueño_o_admin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_dueño_o_admin" ON public.planes_bosques TO authenticated USING ((public.check_is_admin() OR (auth.uid() = user_id) OR (auth.uid() = created_by)));


--
-- Name: planilla_auditoria Gestion_dueño_o_admin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_dueño_o_admin" ON public.planilla_auditoria TO authenticated USING ((public.check_is_admin() OR (auth.uid() = user_id) OR (auth.uid() = created_by)));


--
-- Name: registro_inscripciones_lotes_industrias_martillos Gestion_dueño_o_admin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_dueño_o_admin" ON public.registro_inscripciones_lotes_industrias_martillos TO authenticated USING ((public.check_is_admin() OR (auth.uid() = user_id) OR (auth.uid() = created_by)));


--
-- Name: rehabilitacion_ingresos Gestion_dueño_o_admin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_dueño_o_admin" ON public.rehabilitacion_ingresos TO authenticated USING ((public.check_is_admin() OR (auth.uid() = user_id) OR (auth.uid() = created_by)));


--
-- Name: rehabilitacion_plantel_estable Gestion_dueño_o_admin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_dueño_o_admin" ON public.rehabilitacion_plantel_estable TO authenticated USING ((public.check_is_admin() OR (auth.uid() = user_id) OR (auth.uid() = created_by)));


--
-- Name: residuos_peligrosos Gestion_dueño_o_admin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_dueño_o_admin" ON public.residuos_peligrosos TO authenticated USING ((public.check_is_admin() OR (auth.uid() = user_id) OR (auth.uid() = created_by)));


--
-- Name: solicitudes_apeo_ejido_urbano Gestion_dueño_o_admin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_dueño_o_admin" ON public.solicitudes_apeo_ejido_urbano TO authenticated USING ((public.check_is_admin() OR (auth.uid() = user_id) OR (auth.uid() = created_by)));


--
-- Name: tenencia_fauna Gestion_dueño_o_admin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_dueño_o_admin" ON public.tenencia_fauna TO authenticated USING ((public.check_is_admin() OR (auth.uid() = user_id) OR (auth.uid() = created_by)));


--
-- Name: toma_muestras_arroyos Gestion_dueño_o_admin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_dueño_o_admin" ON public.toma_muestras_arroyos TO authenticated USING ((public.check_is_admin() OR (auth.uid() = user_id) OR (auth.uid() = created_by)));


--
-- Name: toma_muestras_efluentes_industriales Gestion_dueño_o_admin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_dueño_o_admin" ON public.toma_muestras_efluentes_industriales TO authenticated USING ((public.check_is_admin() OR (auth.uid() = user_id) OR (auth.uid() = created_by)));


--
-- Name: vista_secuestros Gestion_dueño_o_admin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_dueño_o_admin" ON public.vista_secuestros TO authenticated USING ((public.check_is_admin() OR (auth.uid() = user_id) OR (auth.uid() = created_by)));


--
-- Name: vivero_el_puma Gestion_dueño_o_admin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_dueño_o_admin" ON public.vivero_el_puma TO authenticated USING ((public.check_is_admin() OR (auth.uid() = user_id) OR (auth.uid() = created_by)));


--
-- Name: almidoneras Gestion_por_permiso_formulario; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_por_permiso_formulario" ON public.almidoneras TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'almidoneras'::text))))));


--
-- Name: rehabilitacion_plantel_estable Gestion_total_plantel_estable; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_total_plantel_estable" ON public.rehabilitacion_plantel_estable TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'rehabilitacion_plantel_estable'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'rehabilitacion_plantel_estable'::text))))));


--
-- Name: actuaciones_control_guardaparques Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.actuaciones_control_guardaparques TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'actuaciones_control_guardaparques'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'actuaciones_control_guardaparques'::text))))));


--
-- Name: almidoneras Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.almidoneras TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'almidoneras'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'almidoneras'::text))))));


--
-- Name: aprovechamiento_pfnm Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.aprovechamiento_pfnm TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'aprovechamiento_pfnm'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'aprovechamiento_pfnm'::text))))));


--
-- Name: areas_naturales_protegidas Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.areas_naturales_protegidas TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'areas_naturales_protegidas'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'areas_naturales_protegidas'::text))))));


--
-- Name: ataques_grandes_felinos Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.ataques_grandes_felinos TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'ataques_grandes_felinos'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'ataques_grandes_felinos'::text))))));


--
-- Name: atropellamiento_fauna_silvestre Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.atropellamiento_fauna_silvestre TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'atropellamiento_fauna_silvestre'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'atropellamiento_fauna_silvestre'::text))))));


--
-- Name: avistamiento_axis Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.avistamiento_axis TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'avistamiento_axis'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'avistamiento_axis'::text))))));


--
-- Name: camaras_trampas_anp Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.camaras_trampas_anp TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'camaras_trampas_anp'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'camaras_trampas_anp'::text))))));


--
-- Name: carnet_pesca_deportiva Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.carnet_pesca_deportiva TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'carnet_pesca_deportiva'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'carnet_pesca_deportiva'::text))))));


--
-- Name: carnet_pesca_subsistencia_comercial Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.carnet_pesca_subsistencia_comercial TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'carnet_pesca_subsistencia_comercial'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'carnet_pesca_subsistencia_comercial'::text))))));


--
-- Name: caza_furtiva Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.caza_furtiva TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'caza_furtiva'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'caza_furtiva'::text))))));


--
-- Name: centros_manejo_fauna Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.centros_manejo_fauna TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'centros_manejo_fauna'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'centros_manejo_fauna'::text))))));


--
-- Name: control_forestal Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.control_forestal TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'control_forestal'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'control_forestal'::text))))));


--
-- Name: criadero_fauna_silvestre Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.criadero_fauna_silvestre TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'criadero_fauna_silvestre'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'criadero_fauna_silvestre'::text))))));


--
-- Name: entrega_alevines Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.entrega_alevines TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'entrega_alevines'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'entrega_alevines'::text))))));


--
-- Name: exoticas_invasoras Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.exoticas_invasoras TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'exoticas_invasoras'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'exoticas_invasoras'::text))))));


--
-- Name: expedientes_impacto_ambiental Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.expedientes_impacto_ambiental TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'expedientes_impacto_ambiental'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'expedientes_impacto_ambiental'::text))))));


--
-- Name: feedlots Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.feedlots TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'feedlots'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'feedlots'::text))))));


--
-- Name: fitosanitarios_domisanitarios Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.fitosanitarios_domisanitarios TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'fitosanitarios_domisanitarios'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'fitosanitarios_domisanitarios'::text))))));


--
-- Name: frigorificos Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.frigorificos TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'frigorificos'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'frigorificos'::text))))));


--
-- Name: guardafauna_honorario Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.guardafauna_honorario TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'guardafauna_honorario'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'guardafauna_honorario'::text))))));


--
-- Name: mapa_cauciones Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.mapa_cauciones TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'mapa_cauciones'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'mapa_cauciones'::text))))));


--
-- Name: mascotismo_ilegal Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.mascotismo_ilegal TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'mascotismo_ilegal'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'mascotismo_ilegal'::text))))));


--
-- Name: mataderos Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.mataderos TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'mataderos'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'mataderos'::text))))));


--
-- Name: monos_aulladores Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.monos_aulladores TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'monos_aulladores'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'monos_aulladores'::text))))));


--
-- Name: monumentos_naturales_provinciales Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.monumentos_naturales_provinciales TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'monumentos_naturales_provinciales'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'monumentos_naturales_provinciales'::text))))));


--
-- Name: perforaciones_constatadas Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.perforaciones_constatadas TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'perforaciones_constatadas'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'perforaciones_constatadas'::text))))));


--
-- Name: plan_provincial_manejo_fuego Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.plan_provincial_manejo_fuego TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'plan_provincial_manejo_fuego'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'plan_provincial_manejo_fuego'::text))))));


--
-- Name: registros_casos_fiebre_amarilla Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.registros_casos_fiebre_amarilla TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'registros_casos_fiebre_amarilla'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'registros_casos_fiebre_amarilla'::text))))));


--
-- Name: vehiculos_secuestrados Gestion_total_por_permiso_formulario; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_total_por_permiso_formulario" ON public.vehiculos_secuestrados TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'vehiculos_secuestrados'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'vehiculos_secuestrados'::text))))));


--
-- Name: rehabilitacion_ingresos Gestion_total_rehabilitacion_ingresos; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_total_rehabilitacion_ingresos" ON public.rehabilitacion_ingresos TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'rehabilitacion_ingresos'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'rehabilitacion_ingresos'::text))))));


--
-- Name: solicitudes_apeo_ejido_urbano Gestion_total_solicitudes_apeo; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_total_solicitudes_apeo" ON public.solicitudes_apeo_ejido_urbano TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'solicitudes_apeo_ejido_urbano'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'solicitudes_apeo_ejido_urbano'::text))))));


--
-- Name: vista_secuestros Gestion_total_vista_secuestros; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Gestion_total_vista_secuestros" ON public.vista_secuestros TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'vista_secuestros'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'vista_secuestros'::text))))));


--
-- Name: perforaciones_registradas Insert_por_area_o_admin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Insert_por_area_o_admin" ON public.perforaciones_registradas FOR INSERT TO authenticated WITH CHECK ((public.check_is_admin() OR public.check_user_in_area('8e1fabda-503c-44cf-a170-b8d98138b8fc'::uuid)));


--
-- Name: planes_bosques Insert_por_area_o_admin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Insert_por_area_o_admin" ON public.planes_bosques FOR INSERT TO authenticated WITH CHECK ((public.check_is_admin() OR public.check_user_in_area('95f26419-138a-460d-9812-496f3688941b'::uuid)));


--
-- Name: planilla_auditoria Insert_por_area_o_admin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Insert_por_area_o_admin" ON public.planilla_auditoria FOR INSERT TO authenticated WITH CHECK ((public.check_is_admin() OR public.check_user_in_area('472f7188-d9da-494d-bcaf-880b75f5e141'::uuid)));


--
-- Name: registro_inscripciones_lotes_industrias_martillos Insert_por_area_o_admin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Insert_por_area_o_admin" ON public.registro_inscripciones_lotes_industrias_martillos FOR INSERT TO authenticated WITH CHECK ((public.check_is_admin() OR public.check_user_in_area('2f9d7b61-ef1c-4011-bd87-461da53e20d8'::uuid)));


--
-- Name: rehabilitacion_ingresos Insert_por_area_o_admin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Insert_por_area_o_admin" ON public.rehabilitacion_ingresos FOR INSERT TO authenticated WITH CHECK ((public.check_is_admin() OR public.check_user_in_area('14249152-7138-46de-8bf4-ae39fbedeecf'::uuid)));


--
-- Name: rehabilitacion_plantel_estable Insert_por_area_o_admin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Insert_por_area_o_admin" ON public.rehabilitacion_plantel_estable FOR INSERT TO authenticated WITH CHECK ((public.check_is_admin() OR public.check_user_in_area('14249152-7138-46de-8bf4-ae39fbedeecf'::uuid)));


--
-- Name: residuos_peligrosos Insert_por_area_o_admin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Insert_por_area_o_admin" ON public.residuos_peligrosos FOR INSERT TO authenticated WITH CHECK ((public.check_is_admin() OR public.check_user_in_area('8e1fabda-503c-44cf-a170-b8d98138b8fc'::uuid)));


--
-- Name: solicitudes_apeo_ejido_urbano Insert_por_area_o_admin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Insert_por_area_o_admin" ON public.solicitudes_apeo_ejido_urbano FOR INSERT TO authenticated WITH CHECK ((public.check_is_admin() OR public.check_user_in_area('3519260d-9301-4765-9e71-f4c7a008810c'::uuid)));


--
-- Name: tenencia_fauna Insert_por_area_o_admin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Insert_por_area_o_admin" ON public.tenencia_fauna FOR INSERT TO authenticated WITH CHECK ((public.check_is_admin() OR public.check_user_in_area('f61a3f26-52ad-4898-914c-86689e4e3d2c'::uuid)));


--
-- Name: toma_muestras_arroyos Insert_por_area_o_admin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Insert_por_area_o_admin" ON public.toma_muestras_arroyos FOR INSERT TO authenticated WITH CHECK ((public.check_is_admin() OR public.check_user_in_area('8e1fabda-503c-44cf-a170-b8d98138b8fc'::uuid)));


--
-- Name: toma_muestras_efluentes_industriales Insert_por_area_o_admin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Insert_por_area_o_admin" ON public.toma_muestras_efluentes_industriales FOR INSERT TO authenticated WITH CHECK ((public.check_is_admin() OR public.check_user_in_area('8e1fabda-503c-44cf-a170-b8d98138b8fc'::uuid)));


--
-- Name: vista_secuestros Insert_por_area_o_admin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Insert_por_area_o_admin" ON public.vista_secuestros FOR INSERT TO authenticated WITH CHECK ((public.check_is_admin() OR public.check_user_in_area('472f7188-d9da-494d-bcaf-880b75f5e141'::uuid)));


--
-- Name: vivero_el_puma Insert_por_area_o_admin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Insert_por_area_o_admin" ON public.vivero_el_puma FOR INSERT TO authenticated WITH CHECK ((public.check_is_admin() OR public.check_user_in_area('14249152-7138-46de-8bf4-ae39fbedeecf'::uuid)));


--
-- Name: profiles Perfiles visibles por autenticados; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Perfiles visibles por autenticados" ON public.profiles FOR SELECT TO authenticated USING (true);


--
-- Name: registro_historico_coleccionistas Policy_Gestion_registro_historico_coleccionistas; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Policy_Gestion_registro_historico_coleccionistas" ON public.registro_historico_coleccionistas TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'registro_historico_coleccionistas'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'registro_historico_coleccionistas'::text))))));


--
-- Name: registro_historico_viveros Policy_Gestion_registro_historico_viveros; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Policy_Gestion_registro_historico_viveros" ON public.registro_historico_viveros TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'registro_historico_viveros'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'registro_historico_viveros'::text))))));


--
-- Name: registro_historico_viveros_medicinales Policy_Gestion_registro_historico_viveros_medicinales; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Policy_Gestion_registro_historico_viveros_medicinales" ON public.registro_historico_viveros_medicinales TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'registro_historico_viveros_medicinales'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'registro_historico_viveros_medicinales'::text))))));


--
-- Name: solicitudes_en_tramite Policy_Gestion_solicitudes_en_tramite; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Policy_Gestion_solicitudes_en_tramite" ON public.solicitudes_en_tramite TO authenticated USING ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'solicitudes_en_tramite'::text)))))) WITH CHECK ((public.check_is_admin() OR (EXISTS ( SELECT 1
   FROM (public.usuarios_formularios uf
     JOIN public.formularios f ON ((f.id = uf.formulario_id)))
  WHERE ((uf.user_id = auth.uid()) AND (f.slug = 'solicitudes_en_tramite'::text))))));


--
-- Name: areas Politica_Universal_Update; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Politica_Universal_Update" ON public.areas FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM (public.usuarios_rol ur
     JOIN public.roles r ON ((ur.rol_id = r.id)))
  WHERE ((((ur.user_id)::text)::uuid = auth.uid()) AND (r.key = ANY (ARRAY['admin'::text, 'superadmin'::text]))))));


--
-- Name: aspectos_sanitarios Read universal aspectos; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Read universal aspectos" ON public.aspectos_sanitarios FOR SELECT USING (true);


--
-- Name: procedencia_tipo Read universal procedencia; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Read universal procedencia" ON public.procedencia_tipo FOR SELECT USING (true);


--
-- Name: roles Roles legibles por autenticados; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Roles legibles por autenticados" ON public.roles FOR SELECT TO authenticated USING (true);


--
-- Name: perforaciones_registradas Select_autenticados; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Select_autenticados" ON public.perforaciones_registradas FOR SELECT TO authenticated USING (true);


--
-- Name: planes_bosques Select_autenticados; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Select_autenticados" ON public.planes_bosques FOR SELECT TO authenticated USING (true);


--
-- Name: planilla_auditoria Select_autenticados; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Select_autenticados" ON public.planilla_auditoria FOR SELECT TO authenticated USING (true);


--
-- Name: registro_inscripciones_lotes_industrias_martillos Select_autenticados; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Select_autenticados" ON public.registro_inscripciones_lotes_industrias_martillos FOR SELECT TO authenticated USING (true);


--
-- Name: rehabilitacion_ingresos Select_autenticados; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Select_autenticados" ON public.rehabilitacion_ingresos FOR SELECT TO authenticated USING (true);


--
-- Name: rehabilitacion_plantel_estable Select_autenticados; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Select_autenticados" ON public.rehabilitacion_plantel_estable FOR SELECT TO authenticated USING (true);


--
-- Name: residuos_peligrosos Select_autenticados; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Select_autenticados" ON public.residuos_peligrosos FOR SELECT TO authenticated USING (true);


--
-- Name: solicitudes_apeo_ejido_urbano Select_autenticados; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Select_autenticados" ON public.solicitudes_apeo_ejido_urbano FOR SELECT TO authenticated USING (true);


--
-- Name: tenencia_fauna Select_autenticados; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Select_autenticados" ON public.tenencia_fauna FOR SELECT TO authenticated USING (true);


--
-- Name: toma_muestras_arroyos Select_autenticados; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Select_autenticados" ON public.toma_muestras_arroyos FOR SELECT TO authenticated USING (true);


--
-- Name: toma_muestras_efluentes_industriales Select_autenticados; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Select_autenticados" ON public.toma_muestras_efluentes_industriales FOR SELECT TO authenticated USING (true);


--
-- Name: vista_secuestros Select_autenticados; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Select_autenticados" ON public.vista_secuestros FOR SELECT TO authenticated USING (true);


--
-- Name: vivero_el_puma Select_autenticados; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Select_autenticados" ON public.vivero_el_puma FOR SELECT TO authenticated USING (true);


--
-- Name: ataques_grandes_felinos Select_por_permiso_formulario; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Select_por_permiso_formulario" ON public.ataques_grandes_felinos FOR SELECT TO authenticated USING (true);


--
-- Name: usuarios_areas SuperAdmins_Full_Access_Areas; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "SuperAdmins_Full_Access_Areas" ON public.usuarios_areas TO authenticated USING (public.check_is_superadmin()) WITH CHECK (public.check_is_superadmin());


--
-- Name: usuarios_rol SuperAdmins_Full_Access_Roles; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "SuperAdmins_Full_Access_Roles" ON public.usuarios_rol TO authenticated USING (public.check_is_superadmin()) WITH CHECK (public.check_is_superadmin());


--
-- Name: usuarios_rol Usuarios pueden ver su propio rol; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Usuarios pueden ver su propio rol" ON public.usuarios_rol FOR SELECT TO authenticated USING ((auth.uid() = user_id));


--
-- Name: usuarios_formularios Usuarios ven sus asignaciones; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Usuarios ven sus asignaciones" ON public.usuarios_formularios FOR SELECT TO authenticated USING (((user_id = auth.uid()) OR public.is_admin()));


--
-- Name: actuaciones_control_guardaparques; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.actuaciones_control_guardaparques ENABLE ROW LEVEL SECURITY;

--
-- Name: solicitudes admin_insert; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY admin_insert ON public.solicitudes FOR INSERT TO authenticated WITH CHECK ((solicitante_id = auth.uid()));


--
-- Name: solicitudes admin_select_own; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY admin_select_own ON public.solicitudes FOR SELECT TO authenticated USING ((solicitante_id = auth.uid()));


--
-- Name: usuarios_rol admins_ver_roles; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY admins_ver_roles ON public.usuarios_rol FOR SELECT TO authenticated USING (true);


--
-- Name: almidoneras; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.almidoneras ENABLE ROW LEVEL SECURITY;

--
-- Name: aprovechamiento_pfnm; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.aprovechamiento_pfnm ENABLE ROW LEVEL SECURITY;

--
-- Name: areas; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.areas ENABLE ROW LEVEL SECURITY;

--
-- Name: areas areas_delete_superadmin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY areas_delete_superadmin ON public.areas FOR DELETE USING (public.is_superadmin());


--
-- Name: areas areas_lectura_autenticados; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY areas_lectura_autenticados ON public.areas FOR SELECT TO authenticated USING (true);


--
-- Name: areas_naturales_protegidas; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.areas_naturales_protegidas ENABLE ROW LEVEL SECURITY;

--
-- Name: aspectos_sanitarios; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.aspectos_sanitarios ENABLE ROW LEVEL SECURITY;

--
-- Name: ataques_grandes_felinos; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.ataques_grandes_felinos ENABLE ROW LEVEL SECURITY;

--
-- Name: atropellamiento_fauna_silvestre; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.atropellamiento_fauna_silvestre ENABLE ROW LEVEL SECURITY;

--
-- Name: avistamiento_axis; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.avistamiento_axis ENABLE ROW LEVEL SECURITY;

--
-- Name: bomberos_policia; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.bomberos_policia ENABLE ROW LEVEL SECURITY;

--
-- Name: camaras_trampas_anp; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.camaras_trampas_anp ENABLE ROW LEVEL SECURITY;

--
-- Name: carnet_pesca_deportiva; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.carnet_pesca_deportiva ENABLE ROW LEVEL SECURITY;

--
-- Name: carnet_pesca_subsistencia_comercial; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.carnet_pesca_subsistencia_comercial ENABLE ROW LEVEL SECURITY;

--
-- Name: caza_furtiva; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.caza_furtiva ENABLE ROW LEVEL SECURITY;

--
-- Name: centros_manejo_fauna; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.centros_manejo_fauna ENABLE ROW LEVEL SECURITY;

--
-- Name: control_forestal; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.control_forestal ENABLE ROW LEVEL SECURITY;

--
-- Name: criadero_fauna_silvestre; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.criadero_fauna_silvestre ENABLE ROW LEVEL SECURITY;

--
-- Name: departamentos; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.departamentos ENABLE ROW LEVEL SECURITY;

--
-- Name: entrega_alevines; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.entrega_alevines ENABLE ROW LEVEL SECURITY;

--
-- Name: exoticas_invasoras; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.exoticas_invasoras ENABLE ROW LEVEL SECURITY;

--
-- Name: expedientes_impacto_ambiental; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.expedientes_impacto_ambiental ENABLE ROW LEVEL SECURITY;

--
-- Name: feedlots; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.feedlots ENABLE ROW LEVEL SECURITY;

--
-- Name: fitosanitarios_domisanitarios; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.fitosanitarios_domisanitarios ENABLE ROW LEVEL SECURITY;

--
-- Name: formularios; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.formularios ENABLE ROW LEVEL SECURITY;

--
-- Name: formularios formularios_delete; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY formularios_delete ON public.formularios FOR DELETE USING (public.is_superadmin());


--
-- Name: formularios formularios_insert; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY formularios_insert ON public.formularios FOR INSERT WITH CHECK (public.is_admin());


--
-- Name: frigorificos; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.frigorificos ENABLE ROW LEVEL SECURITY;

--
-- Name: guardafauna_honorario; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.guardafauna_honorario ENABLE ROW LEVEL SECURITY;

--
-- Name: mapa_cauciones; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.mapa_cauciones ENABLE ROW LEVEL SECURITY;

--
-- Name: mascotismo_ilegal; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.mascotismo_ilegal ENABLE ROW LEVEL SECURITY;

--
-- Name: mataderos; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.mataderos ENABLE ROW LEVEL SECURITY;

--
-- Name: municipios modify_municipios; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY modify_municipios ON public.municipios USING ((EXISTS ( SELECT 1
   FROM (public.usuarios_rol ur
     JOIN public.roles r ON ((r.id = ur.rol_id)))
  WHERE ((ur.user_id = auth.uid()) AND (r.nombre = ANY (ARRAY['admin'::text, 'superadmin'::text])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM (public.usuarios_rol ur
     JOIN public.roles r ON ((r.id = ur.rol_id)))
  WHERE ((ur.user_id = auth.uid()) AND (r.nombre = ANY (ARRAY['admin'::text, 'superadmin'::text]))))));


--
-- Name: monos_aulladores; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.monos_aulladores ENABLE ROW LEVEL SECURITY;

--
-- Name: monumentos_naturales_provinciales; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.monumentos_naturales_provinciales ENABLE ROW LEVEL SECURITY;

--
-- Name: perforaciones_constatadas; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.perforaciones_constatadas ENABLE ROW LEVEL SECURITY;

--
-- Name: perforaciones_registradas; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.perforaciones_registradas ENABLE ROW LEVEL SECURITY;

--
-- Name: plan_provincial_manejo_fuego; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.plan_provincial_manejo_fuego ENABLE ROW LEVEL SECURITY;

--
-- Name: planes_bosques; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.planes_bosques ENABLE ROW LEVEL SECURITY;

--
-- Name: planilla_auditoria; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.planilla_auditoria ENABLE ROW LEVEL SECURITY;

--
-- Name: bomberos_policia policy_area_access_bomberos_policia; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY policy_area_access_bomberos_policia ON public.bomberos_policia TO authenticated USING (((EXISTS ( SELECT 1
   FROM (public.usuarios_rol ur
     JOIN public.roles r ON ((ur.rol_id = r.id)))
  WHERE ((ur.user_id = auth.uid()) AND (r.key = ANY (ARRAY['admin'::text, 'superadmin'::text])) AND (ur.activo = true)))) OR public.check_user_in_area('a83f1107-16dc-4fce-a724-95109654a4f6'::uuid)));


--
-- Name: procedencia_tipo; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.procedencia_tipo ENABLE ROW LEVEL SECURITY;

--
-- Name: profiles; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

--
-- Name: registro_historico_coleccionistas; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.registro_historico_coleccionistas ENABLE ROW LEVEL SECURITY;

--
-- Name: registro_historico_viveros; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.registro_historico_viveros ENABLE ROW LEVEL SECURITY;

--
-- Name: registro_historico_viveros_medicinales; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.registro_historico_viveros_medicinales ENABLE ROW LEVEL SECURITY;

--
-- Name: registro_inscripciones_lotes_industrias_martillos; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.registro_inscripciones_lotes_industrias_martillos ENABLE ROW LEVEL SECURITY;

--
-- Name: registros_casos_fiebre_amarilla; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.registros_casos_fiebre_amarilla ENABLE ROW LEVEL SECURITY;

--
-- Name: rehabilitacion_ingresos; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.rehabilitacion_ingresos ENABLE ROW LEVEL SECURITY;

--
-- Name: rehabilitacion_plantel_estable; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.rehabilitacion_plantel_estable ENABLE ROW LEVEL SECURITY;

--
-- Name: residuos_peligrosos; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.residuos_peligrosos ENABLE ROW LEVEL SECURITY;

--
-- Name: roles; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;

--
-- Name: municipios select_municipios; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY select_municipios ON public.municipios FOR SELECT USING ((auth.uid() IS NOT NULL));


--
-- Name: solicitudes; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.solicitudes ENABLE ROW LEVEL SECURITY;

--
-- Name: solicitudes_apeo_ejido_urbano; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.solicitudes_apeo_ejido_urbano ENABLE ROW LEVEL SECURITY;

--
-- Name: solicitudes_en_tramite; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.solicitudes_en_tramite ENABLE ROW LEVEL SECURITY;

--
-- Name: solicitudes superadmin_all; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY superadmin_all ON public.solicitudes TO authenticated USING ((EXISTS ( SELECT 1
   FROM (public.usuarios_rol ur
     JOIN public.roles r ON ((r.id = ur.rol_id)))
  WHERE ((ur.user_id = auth.uid()) AND (r.key = 'superadmin'::text)))));


--
-- Name: usuarios_areas superadmin_full_usuarios_areas; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY superadmin_full_usuarios_areas ON public.usuarios_areas USING ((EXISTS ( SELECT 1
   FROM (public.usuarios_rol ur
     JOIN public.roles r ON ((r.id = ur.rol_id)))
  WHERE ((ur.user_id = auth.uid()) AND (r.nombre = 'superadmin'::text)))));


--
-- Name: tenencia_fauna; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.tenencia_fauna ENABLE ROW LEVEL SECURITY;

--
-- Name: tipo_intervencion; Type: ROW SECURITY; Schema: public; Owner: supabase_admin
--

ALTER TABLE public.tipo_intervencion ENABLE ROW LEVEL SECURITY;

--
-- Name: toma_muestras_arroyos; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.toma_muestras_arroyos ENABLE ROW LEVEL SECURITY;

--
-- Name: toma_muestras_efluentes_industriales; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.toma_muestras_efluentes_industriales ENABLE ROW LEVEL SECURITY;

--
-- Name: usuarios_areas usuario_ve_sus_areas_rel; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY usuario_ve_sus_areas_rel ON public.usuarios_areas FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: usuarios_areas; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.usuarios_areas ENABLE ROW LEVEL SECURITY;

--
-- Name: usuarios_formularios; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.usuarios_formularios ENABLE ROW LEVEL SECURITY;

--
-- Name: usuarios_rol; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.usuarios_rol ENABLE ROW LEVEL SECURITY;

--
-- Name: vehiculos_secuestrados; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.vehiculos_secuestrados ENABLE ROW LEVEL SECURITY;

--
-- Name: vista_secuestros; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.vista_secuestros ENABLE ROW LEVEL SECURITY;

--
-- Name: vivero_el_puma; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.vivero_el_puma ENABLE ROW LEVEL SECURITY;

--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: pg_database_owner
--

GRANT USAGE ON SCHEMA public TO postgres;
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO service_role;


--
-- Name: FUNCTION check_is_admin(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.check_is_admin() TO anon;
GRANT ALL ON FUNCTION public.check_is_admin() TO authenticated;
GRANT ALL ON FUNCTION public.check_is_admin() TO service_role;


--
-- Name: FUNCTION check_is_area_admin(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.check_is_area_admin() TO anon;
GRANT ALL ON FUNCTION public.check_is_area_admin() TO authenticated;
GRANT ALL ON FUNCTION public.check_is_area_admin() TO service_role;


--
-- Name: FUNCTION check_is_superadmin(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.check_is_superadmin() TO anon;
GRANT ALL ON FUNCTION public.check_is_superadmin() TO authenticated;
GRANT ALL ON FUNCTION public.check_is_superadmin() TO service_role;


--
-- Name: FUNCTION check_tables_exist(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.check_tables_exist() TO anon;
GRANT ALL ON FUNCTION public.check_tables_exist() TO authenticated;
GRANT ALL ON FUNCTION public.check_tables_exist() TO service_role;


--
-- Name: FUNCTION check_user_in_area(target_area_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.check_user_in_area(target_area_id uuid) TO anon;
GRANT ALL ON FUNCTION public.check_user_in_area(target_area_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.check_user_in_area(target_area_id uuid) TO service_role;


--
-- Name: FUNCTION desvincular_usuario_registros(target_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.desvincular_usuario_registros(target_id uuid) TO anon;
GRANT ALL ON FUNCTION public.desvincular_usuario_registros(target_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.desvincular_usuario_registros(target_id uuid) TO service_role;


--
-- Name: FUNCTION exec_sql(sql_query text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.exec_sql(sql_query text) TO anon;
GRANT ALL ON FUNCTION public.exec_sql(sql_query text) TO authenticated;
GRANT ALL ON FUNCTION public.exec_sql(sql_query text) TO service_role;


--
-- Name: FUNCTION fn_fill_geometry(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.fn_fill_geometry() TO anon;
GRANT ALL ON FUNCTION public.fn_fill_geometry() TO authenticated;
GRANT ALL ON FUNCTION public.fn_fill_geometry() TO service_role;


--
-- Name: FUNCTION get_orphans_report(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_orphans_report() TO anon;
GRANT ALL ON FUNCTION public.get_orphans_report() TO authenticated;
GRANT ALL ON FUNCTION public.get_orphans_report() TO service_role;


--
-- Name: FUNCTION get_orphans_report(p_area_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_orphans_report(p_area_id uuid) TO anon;
GRANT ALL ON FUNCTION public.get_orphans_report(p_area_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_orphans_report(p_area_id uuid) TO service_role;


--
-- Name: FUNCTION get_table_columns(p_table_name text); Type: ACL; Schema: public; Owner: supabase_admin
--

REVOKE ALL ON FUNCTION public.get_table_columns(p_table_name text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.get_table_columns(p_table_name text) TO postgres;
GRANT ALL ON FUNCTION public.get_table_columns(p_table_name text) TO anon;
GRANT ALL ON FUNCTION public.get_table_columns(p_table_name text) TO authenticated;
GRANT ALL ON FUNCTION public.get_table_columns(p_table_name text) TO service_role;


--
-- Name: FUNCTION get_table_metadata(p_table_name text); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION public.get_table_metadata(p_table_name text) TO postgres;
GRANT ALL ON FUNCTION public.get_table_metadata(p_table_name text) TO anon;
GRANT ALL ON FUNCTION public.get_table_metadata(p_table_name text) TO authenticated;
GRANT ALL ON FUNCTION public.get_table_metadata(p_table_name text) TO service_role;


--
-- Name: FUNCTION get_usuarios_por_area(p_area_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_usuarios_por_area(p_area_id uuid) TO anon;
GRANT ALL ON FUNCTION public.get_usuarios_por_area(p_area_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_usuarios_por_area(p_area_id uuid) TO service_role;


--
-- Name: FUNCTION handle_new_user(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.handle_new_user() TO anon;
GRANT ALL ON FUNCTION public.handle_new_user() TO authenticated;
GRANT ALL ON FUNCTION public.handle_new_user() TO service_role;


--
-- Name: FUNCTION is_admin(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.is_admin() TO anon;
GRANT ALL ON FUNCTION public.is_admin() TO authenticated;
GRANT ALL ON FUNCTION public.is_admin() TO service_role;


--
-- Name: FUNCTION is_superadmin(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.is_superadmin() TO anon;
GRANT ALL ON FUNCTION public.is_superadmin() TO authenticated;
GRANT ALL ON FUNCTION public.is_superadmin() TO service_role;


--
-- Name: FUNCTION orphan_records_from_user(target_user_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.orphan_records_from_user(target_user_id uuid) TO anon;
GRANT ALL ON FUNCTION public.orphan_records_from_user(target_user_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.orphan_records_from_user(target_user_id uuid) TO service_role;


--
-- Name: FUNCTION tiene_rol(_rol text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.tiene_rol(_rol text) TO anon;
GRANT ALL ON FUNCTION public.tiene_rol(_rol text) TO authenticated;
GRANT ALL ON FUNCTION public.tiene_rol(_rol text) TO service_role;


--
-- Name: FUNCTION update_geom_ataques_felinos(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.update_geom_ataques_felinos() TO anon;
GRANT ALL ON FUNCTION public.update_geom_ataques_felinos() TO authenticated;
GRANT ALL ON FUNCTION public.update_geom_ataques_felinos() TO service_role;


--
-- Name: FUNCTION update_updated_at_column(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.update_updated_at_column() TO anon;
GRANT ALL ON FUNCTION public.update_updated_at_column() TO authenticated;
GRANT ALL ON FUNCTION public.update_updated_at_column() TO service_role;


--
-- Name: FUNCTION usuario_en_area(_area_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.usuario_en_area(_area_id uuid) TO anon;
GRANT ALL ON FUNCTION public.usuario_en_area(_area_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.usuario_en_area(_area_id uuid) TO service_role;


--
-- Name: TABLE actuaciones_control_guardaparques; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.actuaciones_control_guardaparques TO anon;
GRANT ALL ON TABLE public.actuaciones_control_guardaparques TO authenticated;
GRANT ALL ON TABLE public.actuaciones_control_guardaparques TO service_role;


--
-- Name: TABLE almidoneras; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.almidoneras TO anon;
GRANT ALL ON TABLE public.almidoneras TO authenticated;
GRANT ALL ON TABLE public.almidoneras TO service_role;


--
-- Name: TABLE aprovechamiento_pfnm; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.aprovechamiento_pfnm TO anon;
GRANT ALL ON TABLE public.aprovechamiento_pfnm TO authenticated;
GRANT ALL ON TABLE public.aprovechamiento_pfnm TO service_role;


--
-- Name: TABLE areas; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.areas TO anon;
GRANT ALL ON TABLE public.areas TO authenticated;
GRANT ALL ON TABLE public.areas TO service_role;


--
-- Name: TABLE areas_naturales_protegidas; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.areas_naturales_protegidas TO anon;
GRANT ALL ON TABLE public.areas_naturales_protegidas TO authenticated;
GRANT ALL ON TABLE public.areas_naturales_protegidas TO service_role;


--
-- Name: TABLE aspectos_sanitarios; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.aspectos_sanitarios TO anon;
GRANT ALL ON TABLE public.aspectos_sanitarios TO authenticated;
GRANT ALL ON TABLE public.aspectos_sanitarios TO service_role;


--
-- Name: TABLE ataques_grandes_felinos; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.ataques_grandes_felinos TO anon;
GRANT ALL ON TABLE public.ataques_grandes_felinos TO authenticated;
GRANT ALL ON TABLE public.ataques_grandes_felinos TO service_role;


--
-- Name: TABLE atropellamiento_fauna_silvestre; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.atropellamiento_fauna_silvestre TO anon;
GRANT ALL ON TABLE public.atropellamiento_fauna_silvestre TO authenticated;
GRANT ALL ON TABLE public.atropellamiento_fauna_silvestre TO service_role;


--
-- Name: TABLE avistamiento_axis; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.avistamiento_axis TO anon;
GRANT ALL ON TABLE public.avistamiento_axis TO authenticated;
GRANT ALL ON TABLE public.avistamiento_axis TO service_role;


--
-- Name: TABLE bomberos_policia; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.bomberos_policia TO anon;
GRANT ALL ON TABLE public.bomberos_policia TO authenticated;
GRANT ALL ON TABLE public.bomberos_policia TO service_role;


--
-- Name: TABLE camaras_trampas_anp; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.camaras_trampas_anp TO anon;
GRANT ALL ON TABLE public.camaras_trampas_anp TO authenticated;
GRANT ALL ON TABLE public.camaras_trampas_anp TO service_role;


--
-- Name: TABLE carnet_pesca_deportiva; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.carnet_pesca_deportiva TO anon;
GRANT ALL ON TABLE public.carnet_pesca_deportiva TO authenticated;
GRANT ALL ON TABLE public.carnet_pesca_deportiva TO service_role;


--
-- Name: TABLE carnet_pesca_subsistencia_comercial; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.carnet_pesca_subsistencia_comercial TO anon;
GRANT ALL ON TABLE public.carnet_pesca_subsistencia_comercial TO authenticated;
GRANT ALL ON TABLE public.carnet_pesca_subsistencia_comercial TO service_role;


--
-- Name: TABLE categorias_carnet_pesca_deportiva; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.categorias_carnet_pesca_deportiva TO anon;
GRANT ALL ON TABLE public.categorias_carnet_pesca_deportiva TO authenticated;
GRANT ALL ON TABLE public.categorias_carnet_pesca_deportiva TO service_role;


--
-- Name: TABLE caza_furtiva; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.caza_furtiva TO anon;
GRANT ALL ON TABLE public.caza_furtiva TO authenticated;
GRANT ALL ON TABLE public.caza_furtiva TO service_role;


--
-- Name: TABLE centros_manejo_fauna; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.centros_manejo_fauna TO anon;
GRANT ALL ON TABLE public.centros_manejo_fauna TO authenticated;
GRANT ALL ON TABLE public.centros_manejo_fauna TO service_role;


--
-- Name: TABLE control_forestal; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.control_forestal TO anon;
GRANT ALL ON TABLE public.control_forestal TO authenticated;
GRANT ALL ON TABLE public.control_forestal TO service_role;


--
-- Name: TABLE criadero_fauna_silvestre; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.criadero_fauna_silvestre TO anon;
GRANT ALL ON TABLE public.criadero_fauna_silvestre TO authenticated;
GRANT ALL ON TABLE public.criadero_fauna_silvestre TO service_role;


--
-- Name: TABLE departamentos; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.departamentos TO anon;
GRANT ALL ON TABLE public.departamentos TO authenticated;
GRANT ALL ON TABLE public.departamentos TO service_role;


--
-- Name: TABLE destino_rehabilitacion; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.destino_rehabilitacion TO anon;
GRANT ALL ON TABLE public.destino_rehabilitacion TO authenticated;
GRANT ALL ON TABLE public.destino_rehabilitacion TO service_role;


--
-- Name: TABLE entrega_alevines; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.entrega_alevines TO anon;
GRANT ALL ON TABLE public.entrega_alevines TO authenticated;
GRANT ALL ON TABLE public.entrega_alevines TO service_role;


--
-- Name: SEQUENCE entrega_alevines_n_orden_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.entrega_alevines_n_orden_seq TO anon;
GRANT ALL ON SEQUENCE public.entrega_alevines_n_orden_seq TO authenticated;
GRANT ALL ON SEQUENCE public.entrega_alevines_n_orden_seq TO service_role;


--
-- Name: TABLE estados_aprovechamiento; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.estados_aprovechamiento TO anon;
GRANT ALL ON TABLE public.estados_aprovechamiento TO authenticated;
GRANT ALL ON TABLE public.estados_aprovechamiento TO service_role;


--
-- Name: TABLE estados_carnet_pesca; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.estados_carnet_pesca TO anon;
GRANT ALL ON TABLE public.estados_carnet_pesca TO authenticated;
GRANT ALL ON TABLE public.estados_carnet_pesca TO service_role;


--
-- Name: TABLE estados_conservacion; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.estados_conservacion TO anon;
GRANT ALL ON TABLE public.estados_conservacion TO authenticated;
GRANT ALL ON TABLE public.estados_conservacion TO service_role;


--
-- Name: TABLE estados_tramite_honorario; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.estados_tramite_honorario TO anon;
GRANT ALL ON TABLE public.estados_tramite_honorario TO authenticated;
GRANT ALL ON TABLE public.estados_tramite_honorario TO service_role;


--
-- Name: TABLE exoticas_invasoras; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.exoticas_invasoras TO anon;
GRANT ALL ON TABLE public.exoticas_invasoras TO authenticated;
GRANT ALL ON TABLE public.exoticas_invasoras TO service_role;


--
-- Name: TABLE expedientes_impacto_ambiental; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.expedientes_impacto_ambiental TO anon;
GRANT ALL ON TABLE public.expedientes_impacto_ambiental TO authenticated;
GRANT ALL ON TABLE public.expedientes_impacto_ambiental TO service_role;


--
-- Name: TABLE feedlots; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.feedlots TO anon;
GRANT ALL ON TABLE public.feedlots TO authenticated;
GRANT ALL ON TABLE public.feedlots TO service_role;


--
-- Name: TABLE fitosanitarios_domisanitarios; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.fitosanitarios_domisanitarios TO anon;
GRANT ALL ON TABLE public.fitosanitarios_domisanitarios TO authenticated;
GRANT ALL ON TABLE public.fitosanitarios_domisanitarios TO service_role;


--
-- Name: TABLE formularios; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.formularios TO anon;
GRANT ALL ON TABLE public.formularios TO authenticated;
GRANT ALL ON TABLE public.formularios TO service_role;


--
-- Name: TABLE frigorificos; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.frigorificos TO anon;
GRANT ALL ON TABLE public.frigorificos TO authenticated;
GRANT ALL ON TABLE public.frigorificos TO service_role;


--
-- Name: TABLE guardafauna_honorario; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.guardafauna_honorario TO anon;
GRANT ALL ON TABLE public.guardafauna_honorario TO authenticated;
GRANT ALL ON TABLE public.guardafauna_honorario TO service_role;


--
-- Name: TABLE maestro_especies_tipo; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.maestro_especies_tipo TO anon;
GRANT ALL ON TABLE public.maestro_especies_tipo TO authenticated;
GRANT ALL ON TABLE public.maestro_especies_tipo TO service_role;


--
-- Name: TABLE maestro_meses; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.maestro_meses TO anon;
GRANT ALL ON TABLE public.maestro_meses TO authenticated;
GRANT ALL ON TABLE public.maestro_meses TO service_role;


--
-- Name: TABLE mapa_cauciones; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.mapa_cauciones TO anon;
GRANT ALL ON TABLE public.mapa_cauciones TO authenticated;
GRANT ALL ON TABLE public.mapa_cauciones TO service_role;


--
-- Name: TABLE mascotismo_ilegal; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.mascotismo_ilegal TO anon;
GRANT ALL ON TABLE public.mascotismo_ilegal TO authenticated;
GRANT ALL ON TABLE public.mascotismo_ilegal TO service_role;


--
-- Name: TABLE mataderos; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.mataderos TO anon;
GRANT ALL ON TABLE public.mataderos TO authenticated;
GRANT ALL ON TABLE public.mataderos TO service_role;


--
-- Name: TABLE mobile_apps; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.mobile_apps TO anon;
GRANT ALL ON TABLE public.mobile_apps TO authenticated;
GRANT ALL ON TABLE public.mobile_apps TO service_role;


--
-- Name: TABLE monos_aulladores; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.monos_aulladores TO anon;
GRANT ALL ON TABLE public.monos_aulladores TO authenticated;
GRANT ALL ON TABLE public.monos_aulladores TO service_role;


--
-- Name: TABLE monumentos_naturales_provinciales; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.monumentos_naturales_provinciales TO anon;
GRANT ALL ON TABLE public.monumentos_naturales_provinciales TO authenticated;
GRANT ALL ON TABLE public.monumentos_naturales_provinciales TO service_role;


--
-- Name: TABLE municipios; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.municipios TO anon;
GRANT ALL ON TABLE public.municipios TO authenticated;
GRANT ALL ON TABLE public.municipios TO service_role;


--
-- Name: TABLE origen_rehabilitacion; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.origen_rehabilitacion TO anon;
GRANT ALL ON TABLE public.origen_rehabilitacion TO authenticated;
GRANT ALL ON TABLE public.origen_rehabilitacion TO service_role;


--
-- Name: TABLE perforaciones_constatadas; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.perforaciones_constatadas TO anon;
GRANT ALL ON TABLE public.perforaciones_constatadas TO authenticated;
GRANT ALL ON TABLE public.perforaciones_constatadas TO service_role;


--
-- Name: TABLE perforaciones_registradas; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.perforaciones_registradas TO anon;
GRANT ALL ON TABLE public.perforaciones_registradas TO authenticated;
GRANT ALL ON TABLE public.perforaciones_registradas TO service_role;


--
-- Name: TABLE plan_provincial_manejo_fuego; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.plan_provincial_manejo_fuego TO anon;
GRANT ALL ON TABLE public.plan_provincial_manejo_fuego TO authenticated;
GRANT ALL ON TABLE public.plan_provincial_manejo_fuego TO service_role;


--
-- Name: TABLE planes_bosques; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.planes_bosques TO anon;
GRANT ALL ON TABLE public.planes_bosques TO authenticated;
GRANT ALL ON TABLE public.planes_bosques TO service_role;


--
-- Name: TABLE planilla_auditoria; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.planilla_auditoria TO anon;
GRANT ALL ON TABLE public.planilla_auditoria TO authenticated;
GRANT ALL ON TABLE public.planilla_auditoria TO service_role;


--
-- Name: TABLE procedencia_tipo; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.procedencia_tipo TO anon;
GRANT ALL ON TABLE public.procedencia_tipo TO authenticated;
GRANT ALL ON TABLE public.procedencia_tipo TO service_role;


--
-- Name: TABLE profiles; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.profiles TO anon;
GRANT ALL ON TABLE public.profiles TO authenticated;
GRANT ALL ON TABLE public.profiles TO service_role;


--
-- Name: TABLE registro_historico_coleccionistas; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.registro_historico_coleccionistas TO anon;
GRANT ALL ON TABLE public.registro_historico_coleccionistas TO authenticated;
GRANT ALL ON TABLE public.registro_historico_coleccionistas TO service_role;


--
-- Name: TABLE registro_historico_viveros; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.registro_historico_viveros TO anon;
GRANT ALL ON TABLE public.registro_historico_viveros TO authenticated;
GRANT ALL ON TABLE public.registro_historico_viveros TO service_role;


--
-- Name: TABLE registro_historico_viveros_medicinales; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.registro_historico_viveros_medicinales TO anon;
GRANT ALL ON TABLE public.registro_historico_viveros_medicinales TO authenticated;
GRANT ALL ON TABLE public.registro_historico_viveros_medicinales TO service_role;


--
-- Name: TABLE registro_inscripciones_lotes_industrias_martillos; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.registro_inscripciones_lotes_industrias_martillos TO anon;
GRANT ALL ON TABLE public.registro_inscripciones_lotes_industrias_martillos TO authenticated;
GRANT ALL ON TABLE public.registro_inscripciones_lotes_industrias_martillos TO service_role;


--
-- Name: TABLE registros_casos_fiebre_amarilla; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.registros_casos_fiebre_amarilla TO anon;
GRANT ALL ON TABLE public.registros_casos_fiebre_amarilla TO authenticated;
GRANT ALL ON TABLE public.registros_casos_fiebre_amarilla TO service_role;


--
-- Name: TABLE rehabilitacion_ingresos; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.rehabilitacion_ingresos TO anon;
GRANT ALL ON TABLE public.rehabilitacion_ingresos TO authenticated;
GRANT ALL ON TABLE public.rehabilitacion_ingresos TO service_role;


--
-- Name: TABLE rehabilitacion_plantel_estable; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.rehabilitacion_plantel_estable TO anon;
GRANT ALL ON TABLE public.rehabilitacion_plantel_estable TO authenticated;
GRANT ALL ON TABLE public.rehabilitacion_plantel_estable TO service_role;


--
-- Name: TABLE residuos_peligrosos; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.residuos_peligrosos TO anon;
GRANT ALL ON TABLE public.residuos_peligrosos TO authenticated;
GRANT ALL ON TABLE public.residuos_peligrosos TO service_role;


--
-- Name: TABLE roles; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.roles TO anon;
GRANT ALL ON TABLE public.roles TO authenticated;
GRANT ALL ON TABLE public.roles TO service_role;


--
-- Name: TABLE schema_migrations; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.schema_migrations TO anon;
GRANT ALL ON TABLE public.schema_migrations TO authenticated;
GRANT ALL ON TABLE public.schema_migrations TO service_role;


--
-- Name: TABLE sectores_rehabilitacion; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.sectores_rehabilitacion TO anon;
GRANT ALL ON TABLE public.sectores_rehabilitacion TO authenticated;
GRANT ALL ON TABLE public.sectores_rehabilitacion TO service_role;


--
-- Name: TABLE situacion_expedientes_vehiculos; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.situacion_expedientes_vehiculos TO anon;
GRANT ALL ON TABLE public.situacion_expedientes_vehiculos TO authenticated;
GRANT ALL ON TABLE public.situacion_expedientes_vehiculos TO service_role;


--
-- Name: TABLE solicitudes; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.solicitudes TO anon;
GRANT ALL ON TABLE public.solicitudes TO authenticated;
GRANT ALL ON TABLE public.solicitudes TO service_role;


--
-- Name: TABLE solicitudes_apeo_ejido_urbano; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.solicitudes_apeo_ejido_urbano TO anon;
GRANT ALL ON TABLE public.solicitudes_apeo_ejido_urbano TO authenticated;
GRANT ALL ON TABLE public.solicitudes_apeo_ejido_urbano TO service_role;


--
-- Name: TABLE solicitudes_en_tramite; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.solicitudes_en_tramite TO anon;
GRANT ALL ON TABLE public.solicitudes_en_tramite TO authenticated;
GRANT ALL ON TABLE public.solicitudes_en_tramite TO service_role;


--
-- Name: TABLE tenencia_fauna; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.tenencia_fauna TO anon;
GRANT ALL ON TABLE public.tenencia_fauna TO authenticated;
GRANT ALL ON TABLE public.tenencia_fauna TO service_role;


--
-- Name: TABLE tipo_actividad_guardaparques; Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON TABLE public.tipo_actividad_guardaparques TO postgres;
GRANT ALL ON TABLE public.tipo_actividad_guardaparques TO anon;
GRANT ALL ON TABLE public.tipo_actividad_guardaparques TO authenticated;
GRANT ALL ON TABLE public.tipo_actividad_guardaparques TO service_role;


--
-- Name: TABLE tipo_actividad_impacto_ambiental; Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON TABLE public.tipo_actividad_impacto_ambiental TO postgres;
GRANT ALL ON TABLE public.tipo_actividad_impacto_ambiental TO anon;
GRANT ALL ON TABLE public.tipo_actividad_impacto_ambiental TO authenticated;
GRANT ALL ON TABLE public.tipo_actividad_impacto_ambiental TO service_role;


--
-- Name: TABLE tipo_intervencion; Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON TABLE public.tipo_intervencion TO postgres;
GRANT ALL ON TABLE public.tipo_intervencion TO anon;
GRANT ALL ON TABLE public.tipo_intervencion TO authenticated;
GRANT ALL ON TABLE public.tipo_intervencion TO service_role;


--
-- Name: SEQUENCE tipo_intervencion_id_seq; Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON SEQUENCE public.tipo_intervencion_id_seq TO postgres;
GRANT ALL ON SEQUENCE public.tipo_intervencion_id_seq TO anon;
GRANT ALL ON SEQUENCE public.tipo_intervencion_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.tipo_intervencion_id_seq TO service_role;


--
-- Name: TABLE tipos_fito_domi; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.tipos_fito_domi TO anon;
GRANT ALL ON TABLE public.tipos_fito_domi TO authenticated;
GRANT ALL ON TABLE public.tipos_fito_domi TO service_role;


--
-- Name: TABLE toma_muestras_arroyos; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.toma_muestras_arroyos TO anon;
GRANT ALL ON TABLE public.toma_muestras_arroyos TO authenticated;
GRANT ALL ON TABLE public.toma_muestras_arroyos TO service_role;


--
-- Name: TABLE toma_muestras_efluentes_industriales; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.toma_muestras_efluentes_industriales TO anon;
GRANT ALL ON TABLE public.toma_muestras_efluentes_industriales TO authenticated;
GRANT ALL ON TABLE public.toma_muestras_efluentes_industriales TO service_role;


--
-- Name: TABLE unidades_medida_aprovechamiento; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.unidades_medida_aprovechamiento TO anon;
GRANT ALL ON TABLE public.unidades_medida_aprovechamiento TO authenticated;
GRANT ALL ON TABLE public.unidades_medida_aprovechamiento TO service_role;


--
-- Name: TABLE usuarios_areas; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.usuarios_areas TO anon;
GRANT ALL ON TABLE public.usuarios_areas TO authenticated;
GRANT ALL ON TABLE public.usuarios_areas TO service_role;


--
-- Name: TABLE usuarios_formularios; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.usuarios_formularios TO anon;
GRANT ALL ON TABLE public.usuarios_formularios TO authenticated;
GRANT ALL ON TABLE public.usuarios_formularios TO service_role;


--
-- Name: TABLE usuarios_rol; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.usuarios_rol TO anon;
GRANT ALL ON TABLE public.usuarios_rol TO authenticated;
GRANT ALL ON TABLE public.usuarios_rol TO service_role;


--
-- Name: TABLE v_formulario_impacto_ambiental; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.v_formulario_impacto_ambiental TO anon;
GRANT ALL ON TABLE public.v_formulario_impacto_ambiental TO authenticated;
GRANT ALL ON TABLE public.v_formulario_impacto_ambiental TO service_role;


--
-- Name: TABLE v_formulario_tenencia_fauna; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.v_formulario_tenencia_fauna TO anon;
GRANT ALL ON TABLE public.v_formulario_tenencia_fauna TO authenticated;
GRANT ALL ON TABLE public.v_formulario_tenencia_fauna TO service_role;


--
-- Name: TABLE vehiculos_secuestrados; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vehiculos_secuestrados TO anon;
GRANT ALL ON TABLE public.vehiculos_secuestrados TO authenticated;
GRANT ALL ON TABLE public.vehiculos_secuestrados TO service_role;


--
-- Name: TABLE vista_secuestros; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vista_secuestros TO anon;
GRANT ALL ON TABLE public.vista_secuestros TO authenticated;
GRANT ALL ON TABLE public.vista_secuestros TO service_role;


--
-- Name: TABLE vivero_el_puma; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vivero_el_puma TO anon;
GRANT ALL ON TABLE public.vivero_el_puma TO authenticated;
GRANT ALL ON TABLE public.vivero_el_puma TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES  TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES  TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES  TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: supabase_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES  TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES  TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES  TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS  TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS  TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS  TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: supabase_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS  TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS  TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS  TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES  TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES  TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES  TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: supabase_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES  TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES  TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES  TO service_role;


--
-- PostgreSQL database dump complete
--

