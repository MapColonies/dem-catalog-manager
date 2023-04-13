CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS postgis;

-- Table: public.records
-- DROP TABLE public.records;
CREATE TABLE public.records
(
    identifier text COLLATE pg_catalog."default" NOT NULL DEFAULT uuid_generate_v4(),
    typename text COLLATE pg_catalog."default" NOT NULL DEFAULT 'mc:MCDEMRecord',
    schema text COLLATE pg_catalog."default" NOT NULL DEFAULT 'mc_dem',
    mdsource text COLLATE pg_catalog."default" NOT NULL,
    insert_date timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    xml character varying COLLATE pg_catalog."default" NOT NULL,
    anytext text COLLATE pg_catalog."default" NOT NULL,
    wkt_geometry text COLLATE pg_catalog."default",
    wkb_geometry geometry(Geometry,4326),
    anytext_tsvector tsvector,
    links text COLLATE pg_catalog."default" NOT NULL,

    imaging_sortie_accuracy_cep_90 numeric,
    resolution_meter numeric NOT NULL,
    height_range_from numeric NOT NULL,
    height_range_to numeric NOT NULL,
    geographic_area text COLLATE pg_catalog."default",
    undulation_model text COLLATE pg_catalog."default" NOT NULL,
    data_type text COLLATE pg_catalog."default" NOT NULL,
    no_data_value text COLLATE pg_catalog."default" NOT NULL,
    resolution_degree numeric,
    layer_polygon_parts text COLLATE pg_catalog."default",
    absolute_accuracy_lep_90 numeric NOT NULL,
    relative_accuracy_lep_90 numeric NOT NULL,
    product_bbox text COLLATE pg_catalog."default",

    product_id text COLLATE pg_catalog."default" NOT NULL,
    product_name text COLLATE pg_catalog."default" NOT NULL,
    product_type text COLLATE pg_catalog."default" NOT NULL,
    description text COLLATE pg_catalog."default",
    producer_name text COLLATE pg_catalog."default" DEFAULT 'IDFMU',
    update_date timestamp with time zone NOT NULL,
    source_start_date timestamp with time zone NOT NULL,
    source_end_date timestamp with time zone NOT NULL,
    sensor_type text COLLATE pg_catalog."default",
    srs text COLLATE pg_catalog."default" DEFAULT '4326',
    srs_name text COLLATE pg_catalog."default" NOT NULL DEFAULT 'WGS84GEO',
    region text COLLATE pg_catalog."default",
    classification text COLLATE pg_catalog."default" NOT NULL,
    type text COLLATE pg_catalog."default" NOT NULL,
    footprint_geojson text COLLATE pg_catalog."default" NOT NULL,
    keywords text COLLATE pg_catalog."default",

    product_status text COLLATE pg_catalog."default" NOT NULL DEFAULT 'UNPUBLISHED',
    has_terrain boolean NOT NULL DEFAULT FALSE,

    CONSTRAINT records_pkey PRIMARY KEY (identifier),
);


-- Index: ix_product_id
-- DROP INDEX IF EXISTS public.ix_product_id;
CREATE INDEX ix_product_id
     ON public.records USING btree
     (product_id COLLATE pg_catalog."default" ASC NULLS LAST);

-- -- Index: ix_product_name
-- DROP INDEX IF EXISTS public.ix_product_name;
CREATE INDEX ix_product_name
    ON public.records USING btree
    (product_name COLLATE pg_catalog."default" ASC NULLS LAST);

-- Index: ix_product_type
-- DROP INDEX IF EXISTS public.ix_product_type;
CREATE INDEX ix_product_type
    ON public.records USING btree
    (product_type COLLATE pg_catalog."default" ASC NULLS LAST);

-- Index: ix_update_date
-- DROP INDEX IF EXISTS public.ix_update_date;
CREATE INDEX ix_update_date
    ON public.records USING btree
    (update_date ASC NULLS LAST);

-- Index: ix_source_start_date
-- DROP INDEX IF EXISTS public.ix_source_start_date;
CREATE INDEX ix_source_start_date
    ON public.records USING btree
    (source_start_date ASC NULLS LAST);

-- Index: ix_source_end_date
-- DROP INDEX IF EXISTS public.ix_source_end_date;
CREATE INDEX ix_source_end_date
     ON public.records USING btree
     (source_end_date ASC NULLS LAST);

-- Index: ix_resolution_meter
-- DROP INDEX IF EXISTS public.ix_resolution_meter;
CREATE INDEX ix_resolution_meter
     ON public.records USING btree
     (resolution_meter ASC NULLS LAST);

-- Index: ix_imaging_sortie_accuracy_cep_90
-- DROP INDEX IF EXISTS public.ix_imaging_sortie_accuracy_cep_90;
CREATE INDEX ix_imaging_sortie_accuracy_cep_90
     ON public.records USING btree
     (imaging_sortie_accuracy_cep_90 ASC NULLS LAST);

-- Index: ix_max_srs_id
-- DROP INDEX IF EXISTS public.ix_srs_id;
CREATE INDEX ix_max_srs_id
    ON public.records USING btree
    (srs COLLATE pg_catalog."default" ASC NULLS LAST);

-- Index: ix_classification
-- DROP INDEX IF EXISTS public.ix_classification;
CREATE INDEX ix_classification
    ON public.records USING btree
    (classification COLLATE pg_catalog."default" ASC NULLS LAST);

-- Index: ix_product_status
-- DROP INDEX IF EXISTS public.ix_product_status;
CREATE INDEX ix_product_status
    ON public.records USING btree
    (product_status COLLATE pg_catalog."default" ASC NULLS LAST);

-- Index: ix_has_terrain
-- DROP INDEX IF EXISTS public.ix_has_terrain;
CREATE INDEX ix_has_terrain
    ON public.records USING btree
    (has_terrain ASC NULLS LAST);

-- Index: records_wkb_geometry_idx
-- DROP INDEX IF EXISTS public.records_wkb_geometry_idx;
CREATE INDEX records_wkb_geometry_idx
    ON public.records USING gist
    (wkb_geometry);

-- Index: fts_gin_idx
-- DROP INDEX IF EXISTS public.fts_gin_idx;
-- DO NOT CHANGE THIS INDEX NAME --
-- changing its name will disable pycsw full text index
CREATE INDEX fts_gin_idx
    ON public.records USING gin
    (anytext_tsvector);

-- Trigger function : records_update_anytext
-- DROP FUNCTION IF EXISTS public.records_update_anytext;
CREATE FUNCTION public.records_update_anytext() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN   
  IF TG_OP = 'INSERT' THEN
    NEW.update_date := CURRENT_TIMESTAMP;
    NEW.anytext := CONCAT (
      NEW.product_name,' ',
      NEW.product_type, ' ',
      NEW.description, ' ',
      NEW.sensor_type, ' ',
      NEW.srs_name, ' ',
      NEW.region, ' ',
      NEW.classification, ' ',
      NEW.keywords);
  ELSIF TG_OP = 'UPDATE' THEN
    NEW.update_date := CURRENT_TIMESTAMP;
    NEW.anytext := CONCAT (
      COALESCE(NEW.product_name, OLD.product_name),' ',
      COALESCE(NEW.product_type, OLD.product_type), ' ',
      COALESCE(NEW.description, OLD.description), ' ',
      COALESCE(NEW.sensor_type, OLD.sensor_type), ' ',
      COALESCE(NEW.srs_name, OLD.srs_name), ' ',
      COALESCE(NEW.region, OLD.region), ' ',
      COALESCE(NEW.classification, OLD.classification), ' ',
      COALESCE(NEW.keywords, OLD.keywords));
  END IF;
  NEW.anytext_tsvector = to_tsvector('pg_catalog.english', NEW.anytext);
  RETURN NEW;
END;
$$;

-- Trigger: ftsupdate
-- DROP TRIGGER IF EXISTS ftsupdate ON public.records;
CREATE TRIGGER ftsupdate
    BEFORE INSERT OR UPDATE
    ON public.records
    FOR EACH ROW
    WHEN (NEW.product_name IS NOT NULL 
      OR NEW.product_type IS NOT NULL
      OR NEW.description IS NOT NULL
      OR NEW.sensor_type IS NOT NULL
      OR NEW.srs_name IS NOT NULL
      OR NEW.region IS NOT NULL
      OR NEW.classification IS NOT NULL
      OR NEW.keywords IS NOT NULL)
	 EXECUTE PROCEDURE records_update_anytext();

-- Trigger function : records_update_geometry
-- DROP FUNCTION IF EXISTS public.records_update_geometry;
CREATE FUNCTION public.records_update_geometry() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.wkt_geometry IS NULL THEN
        RETURN NEW;
    END IF;
    NEW.wkb_geometry := ST_GeomFromText(NEW.wkt_geometry,4326);
    RETURN NEW;
END;
$$;

-- Trigger: records_update_geometry
-- DROP TRIGGER IF EXISTS records_update_geometry ON public.records;
CREATE TRIGGER records_update_geometry
    BEFORE INSERT OR UPDATE
    ON public.records
    FOR EACH ROW
    EXECUTE PROCEDURE public.records_update_geometry();