CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS postgis;


-- DROP TABLE public.records;

CREATE TABLE public.records (
  identifier text DEFAULT public.uuid_generate_v4() NOT NULL,
  typename text DEFAULT 'mc:MCDEMRecord'::text NOT NULL,
  schema text DEFAULT 'mc_dem'::text NOT NULL,
  mdsource text NOT NULL,
  insert_date timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
  xml character varying NOT NULL,
  anytext text NOT NULL,
  wkt_geometry text,
  wkb_geometry public.geometry(Geometry,4326),
  anytext_tsvector tsvector,
  links text NOT NULL,
  imaging_sortie_accuracy_cep_90 numeric,
  resolution_meter numeric NOT NULL,
  height_range_from numeric NOT NULL,
  height_range_to numeric NOT NULL,
  geographic_area text,
  undulation_model text NOT NULL,
  data_type text NOT NULL,
  resolution_degree numeric,
  layer_polygon_parts text,
  absolute_accuracy_lep_90 numeric NOT NULL,
  relative_accuracy_lep_90 numeric NOT NULL,
  product_bbox text,
  product_id text NOT NULL,
  product_name text NOT NULL,
  product_type text NOT NULL,
  description text,
  producer_name text DEFAULT 'IDFMU'::text,
  update_date timestamp with time zone NOT NULL,
  source_start_date timestamp with time zone NOT NULL,
  source_end_date timestamp with time zone NOT NULL,
  sensor_type text,
  srs text DEFAULT '4326'::text,
  srs_name text DEFAULT 'WGS84GEO'::text NOT NULL,
  region text,
  classification text NOT NULL,
  type text NOT NULL,
  footprint_geojson text NOT NULL,
  keywords text,
  product_status text DEFAULT 'UNPUBLISHED'::text NOT NULL,
  has_terrain boolean DEFAULT false NOT NULL,
  no_data_value text DEFAULT '-999'::text NOT NULL
);

ALTER TABLE ONLY public.records
  ADD CONSTRAINT records_pkey PRIMARY KEY (identifier);


-- DROP INDEX IF EXISTS public.ix_product_id;
CREATE INDEX ix_product_id
  ON public.records USING btree
  (product_id COLLATE pg_catalog."default" ASC NULLS LAST);

-- DROP INDEX IF EXISTS public.ix_product_name;
CREATE INDEX ix_product_name
  ON public.records USING btree
  (product_name COLLATE pg_catalog."default" ASC NULLS LAST);

-- DROP INDEX IF EXISTS public.ix_product_type;
CREATE INDEX ix_product_type
  ON public.records USING btree
  (product_type COLLATE pg_catalog."default" ASC NULLS LAST);

-- DROP INDEX IF EXISTS public.ix_update_date;
CREATE INDEX ix_update_date
  ON public.records USING btree
  (update_date ASC NULLS LAST);

-- DROP INDEX IF EXISTS public.ix_source_start_date;
CREATE INDEX ix_source_start_date
  ON public.records USING btree
  (source_start_date ASC NULLS LAST);

-- DROP INDEX IF EXISTS public.ix_source_end_date;
CREATE INDEX ix_source_end_date
  ON public.records USING btree
  (source_end_date ASC NULLS LAST);

-- DROP INDEX IF EXISTS public.ix_resolution_meter;
CREATE INDEX ix_resolution_meter
  ON public.records USING btree
  (resolution_meter ASC NULLS LAST);

-- DROP INDEX IF EXISTS public.ix_imaging_sortie_accuracy_cep_90;
CREATE INDEX ix_imaging_sortie_accuracy_cep_90
  ON public.records USING btree
  (imaging_sortie_accuracy_cep_90 ASC NULLS LAST);

-- DROP INDEX IF EXISTS public.ix_srs_id;
CREATE INDEX ix_max_srs_id
  ON public.records USING btree
  (srs COLLATE pg_catalog."default" ASC NULLS LAST);

-- DROP INDEX IF EXISTS public.ix_classification;
CREATE INDEX ix_classification
  ON public.records USING btree
  (classification COLLATE pg_catalog."default" ASC NULLS LAST);

-- DROP INDEX IF EXISTS public.ix_product_status;
CREATE INDEX ix_product_status
  ON public.records USING btree
  (product_status COLLATE pg_catalog."default" ASC NULLS LAST);

-- DROP INDEX IF EXISTS public.ix_has_terrain;
CREATE INDEX ix_has_terrain
  ON public.records USING btree
  (has_terrain ASC NULLS LAST);

-- DROP INDEX IF EXISTS public.records_wkb_geometry_idx;
CREATE INDEX records_wkb_geometry_idx
  ON public.records USING gist
  (wkb_geometry);

-- DROP INDEX IF EXISTS public.fts_gin_idx;
-- DO NOT CHANGE THIS INDEX NAME --
-- changing its name will disable pycsw full text index
CREATE INDEX fts_gin_idx
  ON public.records USING gin
  (anytext_tsvector);


-- Trigger function: records_update_anytext
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
  EXECUTE FUNCTION public.records_update_anytext();

-- Trigger function: records_update_geometry
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
  EXECUTE FUNCTION public.records_update_geometry();



-- Insert Rows
INSERT INTO public.records (identifier, typename, schema, mdsource, insert_date, xml, anytext, wkt_geometry, wkb_geometry, anytext_tsvector, links, imaging_sortie_accuracy_cep_90, resolution_meter, height_range_from, height_range_to, geographic_area, undulation_model, data_type, resolution_degree, layer_polygon_parts, absolute_accuracy_lep_90, relative_accuracy_lep_90, product_bbox, product_id, product_name, product_type, description, producer_name, update_date, source_start_date, source_end_date, sensor_type, srs, srs_name, region, classification, type, footprint_geojson, keywords, product_status, has_terrain, no_data_value) VALUES ('532af3ae-13c0-4a42-a006-ce1eaf11874f', 'mc_MCDEMRecord', 'mc_dem', '', '2023-03-05 15:02:34+02', '', 'dem__gt30e020n40 DTM  UNDEFINED WGS84GEO Israel 6 Israel, DTM, EPSG:4326', 'POLYGON((20 -10,20 40,60 40,60 -10,20 -10))', '0103000020E61000000100000005000000000000000000344000000000000024C0000000000000344000000000000044400000000000004E4000000000000044400000000000004E4000000000000024C0000000000000344000000000000024C0', '''4326'':11 ''6'':7 ''dem'':1 ''dtm'':3,9 ''epsg'':10 ''gt30e020n40'':2 ''israel'':6,8 ''undefin'':4 ''wgs84geo'':5', 'dem:gt30e020n40,,WMTS_LAYER,https://dem-dev-qgis-server-development-route-dem-dev.apps.j1lk3njp.eastus.aroapp.io/ogc/?SERVICE=WMTS&REQUEST=GetTile&MAP=/io/data/dtm/gt30e020n40/project/gt30e020n40.qgs&LAYER=gt30e020n40_vrt_heat_hill_group&OPACITIES=255&FORMAT=image/png&TILEMATRIXSET=EPSG:4326&TILEMATRIX={TileMatrix}&TILEROW={TileRow}&TILECOL={TileCol}', NULL, 100, -500, 9000, 'Israel', 'ILUM', 'Int16', 0.00833, NULL, 0.0000009, 0.0000009, NULL, 'ext_dem__gt30e020n40', 'dem__gt30e020n40', 'DTM', NULL, 'IDFMU', '2023-06-04 19:55:41.684176+03', '2000-02-10 21:43:00+02', '2000-02-11 21:43:00+02', 'UNDEFINED', 'EPSG:4326', 'WGS84GEO', 'Israel', '6', 'RECORD_DEM', '{"type":"Polygon","coordinates":[[[20,-10],[20,40],[60,40],[60,-10],[20,-10]]]}', 'Israel, DTM, EPSG:4326', 'PUBLISHED', false, '-999');
INSERT INTO public.records (identifier, typename, schema, mdsource, insert_date, xml, anytext, wkt_geometry, wkb_geometry, anytext_tsvector, links, imaging_sortie_accuracy_cep_90, resolution_meter, height_range_from, height_range_to, geographic_area, undulation_model, data_type, resolution_degree, layer_polygon_parts, absolute_accuracy_lep_90, relative_accuracy_lep_90, product_bbox, product_id, product_name, product_type, description, producer_name, update_date, source_start_date, source_end_date, sensor_type, srs, srs_name, region, classification, type, footprint_geojson, keywords, product_status, has_terrain, no_data_value) VALUES ('532af3ae-03c0-4a42-a006-be1edf11874f', 'mc_MCDEMRecord', 'mc_dem', '', '2023-03-05 15:02:34+02', '', 'dem__n31_e035_1arc_v3 DTM  UNDEFINED WGS84GEO Israel 6 Israel, DTM, EPSG:4326', 'POLYGON((34.999861111 30.999861111,34.999861111 32.000138889,36.000138889 32.000138889,36.000138889 30.999861111,34.999861111 30.999861111))', '0103000020E61000000100000005000000C424EA72FB7F41408849D4E5F6FF3E40C424EA72FB7F41403CDB158D040040403CDB158D040042403CDB158D040040403CDB158D040042408849D4E5F6FF3E40C424EA72FB7F41408849D4E5F6FF3E40', '''1arc'':4 ''4326'':14 ''6'':10 ''dem'':1 ''dtm'':6,12 ''e035'':3 ''epsg'':13 ''israel'':9,11 ''n31'':2 ''undefin'':7 ''v3'':5 ''wgs84geo'':8', 'dem:n31_e035_1arc_v3,,WMTS_LAYER,https://dem-dev-qgis-server-development-route-dem-dev.apps.j1lk3njp.eastus.aroapp.io/ogc/?SERVICE=WMTS&REQUEST=GetTile&MAP=/io/data/dtm/n31_e035_1arc_v3/project/n31_e035_1arc_v3.qgs&LAYER=n31_e035_1arc_v3_vrt_heat_hill_group&OPACITIES=255&FORMAT=image/png&TILEMATRIXSET=EPSG:4326&TILEMATRIX={TileMatrix}&TILEROW={TileRow}&TILECOL={TileCol}', NULL, 30, -500, 9000, 'Israel', 'ILUM', 'Int16', 0.000277, NULL, 0.0000009, 0.0000009, NULL, 'ext_dem__n31_e035_1arc_v3', 'dem__n31_e035_1arc_v3', 'DTM', NULL, 'IDFMU', '2023-06-04 19:55:41.684176+03', '2000-02-10 21:43:00+02', '2000-02-11 21:43:00+02', 'UNDEFINED', 'EPSG:4326', 'WGS84GEO', 'Israel', '6', 'RECORD_DEM', '{"type":"Polygon","coordinates":[[[34.999861111,30.999861111],[34.999861111,32.000138889],[36.000138889,32.000138889],[36.000138889,30.999861111],[34.999861111,30.999861111]]]}', 'Israel, DTM, EPSG:4326', 'PUBLISHED', false, '-999');
INSERT INTO public.records (identifier, typename, schema, mdsource, insert_date, xml, anytext, wkt_geometry, wkb_geometry, anytext_tsvector, links, imaging_sortie_accuracy_cep_90, resolution_meter, height_range_from, height_range_to, geographic_area, undulation_model, data_type, resolution_degree, layer_polygon_parts, absolute_accuracy_lep_90, relative_accuracy_lep_90, product_bbox, product_id, product_name, product_type, description, producer_name, update_date, source_start_date, source_end_date, sensor_type, srs, srs_name, region, classification, type, footprint_geojson, keywords, product_status, has_terrain, no_data_value) VALUES ('532af3ae-03c0-4f42-a006-bd1edf11874f', 'mc_MCDEMRecord', 'mc_dem', '', '2023-03-05 15:02:34+02', '', 'dem__n32_e036_1arc_v3 DTM  UNDEFINED WGS84GEO Israel 6 Israel, DTM, EPSG:4326', 'POLYGON((35.999861111 31.999861111,35.999861111 33.000138889,37.000138889 33.000138889,37.000138889 31.999861111,35.999861111 31.999861111))', '0103000020E61000000100000005000000C424EA72FBFF41408849D4E5F6FF3F40C424EA72FBFF41403CDB158D048040403CDB158D048042403CDB158D048040403CDB158D048042408849D4E5F6FF3F40C424EA72FBFF41408849D4E5F6FF3F40', '''1arc'':4 ''4326'':14 ''6'':10 ''dem'':1 ''dtm'':6,12 ''e036'':3 ''epsg'':13 ''israel'':9,11 ''n32'':2 ''undefin'':7 ''v3'':5 ''wgs84geo'':8', 'dem:n32_e036_1arc_v3,,WMTS_LAYER,WMTS_LAYER,https://dem-dev-qgis-server-development-route-dem-dev.apps.j1lk3njp.eastus.aroapp.io/ogc/?SERVICE=WMTS&REQUEST=GetTile&MAP=/io/data/dtm/n32_e036_1arc_v3/project/n32_e036_1arc_v3.qgs&LAYER=n32_e036_1arc_v3_vrt_heat_hill_group&OPACITIES=255&FORMAT=image/png&TILEMATRIXSET=EPSG:4326&TILEMATRIX={TileMatrix}&TILEROW={TileRow}&TILECOL={TileCol}', NULL, 30, -500, 9000, 'Israel', 'ILUM', 'Int16', 0.000277, NULL, 0.0000009, 0.0000009, NULL, 'ext_dem__n32_e036_1arc_v3', 'dem__n32_e036_1arc_v3', 'DTM', NULL, 'IDFMU', '2023-06-04 19:55:41.684176+03', '2000-02-10 21:43:00+02', '2000-02-11 21:43:00+02', 'UNDEFINED', 'EPSG:4326', 'WGS84GEO', 'Israel', '6', 'RECORD_DEM', '{"type":"Polygon","coordinates":[[[35.999861111,31.999861111],[35.999861111,33.000138889],[37.000138889,33.000138889],[37.000138889,31.999861111],[35.999861111,31.999861111]]]}', 'Israel, DTM, EPSG:4326', 'PUBLISHED', false, '-999');
INSERT INTO public.records (identifier, typename, schema, mdsource, insert_date, xml, anytext, wkt_geometry, wkb_geometry, anytext_tsvector, links, imaging_sortie_accuracy_cep_90, resolution_meter, height_range_from, height_range_to, geographic_area, undulation_model, data_type, resolution_degree, layer_polygon_parts, absolute_accuracy_lep_90, relative_accuracy_lep_90, product_bbox, product_id, product_name, product_type, description, producer_name, update_date, source_start_date, source_end_date, sensor_type, srs, srs_name, region, classification, type, footprint_geojson, keywords, product_status, has_terrain, no_data_value) VALUES ('532af3ae-03c0-4f42-a006-be1edf11874f', 'mc_MCDEMRecord', 'mc_dem', '', '2023-03-05 15:02:34+02', '', 'dem__n31_e036_1arc_v3 DTM  UNDEFINED WGS84GEO Israel 6 Israel, DTM, EPSG:4326', 'POLYGON((35.999861111 30.999861111,35.999861111 32.000138889,37.000138889 32.000138889,37.000138889 30.999861111,35.999861111 30.999861111))', '0103000020E61000000100000005000000C424EA72FBFF41408849D4E5F6FF3E40C424EA72FBFF41403CDB158D040040403CDB158D048042403CDB158D040040403CDB158D048042408849D4E5F6FF3E40C424EA72FBFF41408849D4E5F6FF3E40', '''1arc'':4 ''4326'':14 ''6'':10 ''dem'':1 ''dtm'':6,12 ''e036'':3 ''epsg'':13 ''israel'':9,11 ''n31'':2 ''undefin'':7 ''v3'':5 ''wgs84geo'':8', 'dem:n31_e036_1arc_v3,,WMTS_LAYER,https://dem-dev-qgis-server-development-route-dem-dev.apps.j1lk3njp.eastus.aroapp.io/ogc/?SERVICE=WMTS&REQUEST=GetTile&MAP=/io/data/dtm/n31_e036_1arc_v3/project/n31_e036_1arc_v3.qgs&LAYER=n31_e036_1arc_v3_vrt_heat_hill_group&OPACITIES=255&FORMAT=image/png&TILEMATRIXSET=EPSG:4326&TILEMATRIX={TileMatrix}&TILEROW={TileRow}&TILECOL={TileCol}', NULL, 30, -500, 9000, 'Israel', 'ILUM', 'Int16', 0.000277, NULL, 0.0000009, 0.0000009, NULL, 'ext_dem__n31_e036_1arc_v3', 'dem__n31_e036_1arc_v3', 'DTM', NULL, 'IDFMU', '2023-06-04 19:55:41.684176+03', '2000-02-10 21:43:00+02', '2000-02-11 21:43:00+02', 'UNDEFINED', 'EPSG:4326', 'WGS84GEO', 'Israel', '6', 'RECORD_DEM', '{"type":"Polygon","coordinates":[[[35.999861111,30.999861111],[35.999861111,32.000138889],[37.000138889,32.000138889],[37.000138889,30.999861111],[35.999861111,30.999861111]]]}', 'Israel, DTM, EPSG:4326', 'PUBLISHED', false, '-999');
INSERT INTO public.records (identifier, typename, schema, mdsource, insert_date, xml, anytext, wkt_geometry, wkb_geometry, anytext_tsvector, links, imaging_sortie_accuracy_cep_90, resolution_meter, height_range_from, height_range_to, geographic_area, undulation_model, data_type, resolution_degree, layer_polygon_parts, absolute_accuracy_lep_90, relative_accuracy_lep_90, product_bbox, product_id, product_name, product_type, description, producer_name, update_date, source_start_date, source_end_date, sensor_type, srs, srs_name, region, classification, type, footprint_geojson, keywords, product_status, has_terrain, no_data_value) VALUES ('532af3ae-13c0-4a42-a006-ce2edf11874f', 'mc_MCDEMRecord', 'mc_dem', '', '2023-03-05 15:02:34+02', '', 'dem__n30_e035_1arc_v3 DTM  UNDEFINED WGS84GEO Israel 6 Israel, DTM, EPSG:4326', 'POLYGON((34.999861111 29.999861111,34.999861111 31.000138889,36.000138889 31.000138889,36.000138889 29.999861111,34.999861111 29.999861111))', '0103000020E61000000100000005000000C424EA72FB7F41408849D4E5F6FF3D40C424EA72FB7F414078B62B1A09003F403CDB158D0400424078B62B1A09003F403CDB158D040042408849D4E5F6FF3D40C424EA72FB7F41408849D4E5F6FF3D40', '''1arc'':4 ''4326'':14 ''6'':10 ''dem'':1 ''dtm'':6,12 ''e035'':3 ''epsg'':13 ''israel'':9,11 ''n30'':2 ''undefin'':7 ''v3'':5 ''wgs84geo'':8', 'dem:n30_e035_1arc_v3,,WMTS_LAYER,https://dem-dev-qgis-server-development-route-dem-dev.apps.j1lk3njp.eastus.aroapp.io/ogc/?SERVICE=WMTS&REQUEST=GetTile&MAP=/io/data/dtm/n30_e035_1arc_v3/project/n30_e035_1arc_v3.qgs&LAYER=n30_e035_1arc_v3_vrt_heat_hill_group&OPACITIES=255&FORMAT=image/png&TILEMATRIXSET=EPSG:4326&TILEMATRIX={TileMatrix}&TILEROW={TileRow}&TILECOL={TileCol}', NULL, 30, -500, 9000, 'Israel', 'ILUM', 'Int16', 0.000277, NULL, 0.0000009, 0.0000009, NULL, 'ext_dem__n30_e035_1arc_v3', 'dem__n30_e035_1arc_v3', 'DTM', NULL, 'IDFMU', '2023-06-04 19:55:41.684176+03', '2000-02-10 21:43:00+02', '2000-02-11 21:43:00+02', 'UNDEFINED', 'EPSG:4326', 'WGS84GEO', 'Israel', '6', 'RECORD_DEM', '{"type":"Polygon","coordinates":[[[34.999861111,29.999861111],[34.999861111,31.000138889],[36.000138889,31.000138889],[36.000138889,29.999861111],[34.999861111,29.999861111]]]}', 'Israel, DTM, EPSG:4326', 'PUBLISHED', false, '-999');
INSERT INTO public.records (identifier, typename, schema, mdsource, insert_date, xml, anytext, wkt_geometry, wkb_geometry, anytext_tsvector, links, imaging_sortie_accuracy_cep_90, resolution_meter, height_range_from, height_range_to, geographic_area, undulation_model, data_type, resolution_degree, layer_polygon_parts, absolute_accuracy_lep_90, relative_accuracy_lep_90, product_bbox, product_id, product_name, product_type, description, producer_name, update_date, source_start_date, source_end_date, sensor_type, srs, srs_name, region, classification, type, footprint_geojson, keywords, product_status, has_terrain, no_data_value) VALUES ('532af3ae-03c0-4a42-a006-ce1edf11874f', 'mc_MCDEMRecord', 'mc_dem', '', '2023-03-05 15:02:34+02', '', 'dem__n32_e034_1arc_v3 DTM  UNDEFINED WGS84GEO Israel 6 Israel, DTM, EPSG:4326', 'POLYGON((33.999861111 31.999861111,33.999861111 33.000138889,35.000138889 33.000138889,35.000138889 31.999861111,33.999861111 31.999861111))', '0103000020E61000000100000005000000C424EA72FBFF40408849D4E5F6FF3F40C424EA72FBFF40403CDB158D048040403CDB158D048041403CDB158D048040403CDB158D048041408849D4E5F6FF3F40C424EA72FBFF40408849D4E5F6FF3F40', '''1arc'':4 ''4326'':14 ''6'':10 ''dem'':1 ''dtm'':6,12 ''e034'':3 ''epsg'':13 ''israel'':9,11 ''n32'':2 ''undefin'':7 ''v3'':5 ''wgs84geo'':8', 'dem:n32_e034_1arc_v3,,WMTS_LAYER,https://dem-dev-qgis-server-development-route-dem-dev.apps.j1lk3njp.eastus.aroapp.io/ogc/?SERVICE=WMTS&REQUEST=GetTile&MAP=/io/data/dtm/n32_e034_1arc_v3/project/n32_e034_1arc_v3.qgs&LAYER=n32_e034_1arc_v3_vrt_heat_hill_group&OPACITIES=255&FORMAT=image/png&TILEMATRIXSET=EPSG:4326&TILEMATRIX={TileMatrix}&TILEROW={TileRow}&TILECOL={TileCol}', NULL, 30, -500, 9000, 'Israel', 'ILUM', 'Int16', 0.000277, NULL, 0.0000009, 0.0000009, NULL, 'ext_dem__n32_e034_1arc_v3', 'dem__n32_e034_1arc_v3', 'DTM', NULL, 'IDFMU', '2023-06-04 19:55:41.684176+03', '2000-02-10 21:43:00+02', '2000-02-11 21:43:00+02', 'UNDEFINED', 'EPSG:4326', 'WGS84GEO', 'Israel', '6', 'RECORD_DEM', '{"type":"Polygon","coordinates":[[[33.999861111,31.999861111],[33.999861111,33.000138889],[35.000138889,33.000138889],[35.000138889,31.999861111],[33.999861111,31.999861111]]]}', 'Israel, DTM, EPSG:4326', 'PUBLISHED', false, '-999');
INSERT INTO public.records (identifier, typename, schema, mdsource, insert_date, xml, anytext, wkt_geometry, wkb_geometry, anytext_tsvector, links, imaging_sortie_accuracy_cep_90, resolution_meter, height_range_from, height_range_to, geographic_area, undulation_model, data_type, resolution_degree, layer_polygon_parts, absolute_accuracy_lep_90, relative_accuracy_lep_90, product_bbox, product_id, product_name, product_type, description, producer_name, update_date, source_start_date, source_end_date, sensor_type, srs, srs_name, region, classification, type, footprint_geojson, keywords, product_status, has_terrain, no_data_value) VALUES ('532af3ae-13c0-4a42-a006-ce3edf11874f', 'mc_MCDEMRecord', 'mc_dem', '', '2023-03-05 15:02:34+02', '', 'dem__n30_e034_1arc_v3 DTM  UNDEFINED WGS84GEO Israel 6 Israel, DTM, EPSG:4326', 'POLYGON((33.999861111 29.999861111,33.999861111 31.000138889,35.000138889 31.000138889,35.000138889 29.999861111,33.999861111 29.999861111))', '0103000020E61000000100000005000000C424EA72FBFF40408849D4E5F6FF3D40C424EA72FBFF404078B62B1A09003F403CDB158D0480414078B62B1A09003F403CDB158D048041408849D4E5F6FF3D40C424EA72FBFF40408849D4E5F6FF3D40', '''1arc'':4 ''4326'':14 ''6'':10 ''dem'':1 ''dtm'':6,12 ''e034'':3 ''epsg'':13 ''israel'':9,11 ''n30'':2 ''undefin'':7 ''v3'':5 ''wgs84geo'':8', 'dem:n30_e034_1arc_v3,,WMTS_LAYER,https://dem-dev-qgis-server-development-route-dem-dev.apps.j1lk3njp.eastus.aroapp.io/ogc/?SERVICE=WMTS&REQUEST=GetTile&MAP=/io/data/dtm/n30_e034_1arc_v3/project/n30_e034_1arc_v3.qgs&LAYER=n30_e034_1arc_v3_vrt_heat_hill_group&OPACITIES=255&FORMAT=image/png&TILEMATRIXSET=EPSG:4326&TILEMATRIX={TileMatrix}&TILEROW={TileRow}&TILECOL={TileCol}', NULL, 30, -500, 9000, 'Israel', 'ILUM', 'Int16', 0.000277, NULL, 0.0000009, 0.0000009, NULL, 'ext_dem__n30_e034_1arc_v3', 'dem__n30_e034_1arc_v3', 'DTM', NULL, 'IDFMU', '2023-06-04 19:55:41.684176+03', '2000-02-10 21:43:00+02', '2000-02-11 21:43:00+02', 'UNDEFINED', 'EPSG:4326', 'WGS84GEO', 'Israel', '6', 'RECORD_DEM', '{"type":"Polygon","coordinates":[[[33.999861111,29.999861111],[33.999861111,31.000138889],[35.000138889,31.000138889],[35.000138889,29.999861111],[33.999861111,29.999861111]]]}', 'Israel, DTM, EPSG:4326', 'PUBLISHED', false, '-999');
INSERT INTO public.records (identifier, typename, schema, mdsource, insert_date, xml, anytext, wkt_geometry, wkb_geometry, anytext_tsvector, links, imaging_sortie_accuracy_cep_90, resolution_meter, height_range_from, height_range_to, geographic_area, undulation_model, data_type, resolution_degree, layer_polygon_parts, absolute_accuracy_lep_90, relative_accuracy_lep_90, product_bbox, product_id, product_name, product_type, description, producer_name, update_date, source_start_date, source_end_date, sensor_type, srs, srs_name, region, classification, type, footprint_geojson, keywords, product_status, has_terrain, no_data_value) VALUES ('532af3ae-13c0-4a42-a006-ce1edf11874f', 'mc_MCDEMRecord', 'mc_dem', '', '2023-03-05 15:02:34+02', '', 'dem__n31_e034_1arc_v3 DTM  UNDEFINED WGS84GEO Israel 6 Israel, DTM, EPSG:4326', 'POLYGON((33.999861111 30.999861111,33.999861111 32.000138889,35.000138889 32.000138889,35.000138889 30.999861111,33.999861111 30.999861111))', '0103000020E61000000100000005000000C424EA72FBFF40408849D4E5F6FF3E40C424EA72FBFF40403CDB158D040040403CDB158D048041403CDB158D040040403CDB158D048041408849D4E5F6FF3E40C424EA72FBFF40408849D4E5F6FF3E40', '''1arc'':4 ''4326'':14 ''6'':10 ''dem'':1 ''dtm'':6,12 ''e034'':3 ''epsg'':13 ''israel'':9,11 ''n31'':2 ''undefin'':7 ''v3'':5 ''wgs84geo'':8', 'dem:n31_e034_1arc_v3,,WMTS_LAYER,https://dem-dev-qgis-server-development-route-dem-dev.apps.j1lk3njp.eastus.aroapp.io/ogc/?SERVICE=WMTS&REQUEST=GetTile&MAP=/io/data/dtm/n31_e034_1arc_v3/project/n31_e034_1arc_v3.qgs&LAYER=n31_e034_1arc_v3_vrt_heat_hill_group&OPACITIES=255&FORMAT=image/png&TILEMATRIXSET=EPSG:4326&TILEMATRIX={TileMatrix}&TILEROW={TileRow}&TILECOL={TileCol}', NULL, 30, -500, 9000, 'Israel', 'ILUM', 'Int16', 0.000277, NULL, 0.0000009, 0.0000009, NULL, 'ext_dem__n31_e034_1arc_v3', 'dem__n31_e034_1arc_v3', 'DTM', NULL, 'IDFMU', '2023-06-04 19:55:41.684176+03', '2000-02-10 21:43:00+02', '2000-02-11 21:43:00+02', 'UNDEFINED', 'EPSG:4326', 'WGS84GEO', 'Israel', '6', 'RECORD_DEM', '{"type":"Polygon","coordinates":[[[33.999861111,30.999861111],[33.999861111,32.000138889],[35.000138889,32.000138889],[35.000138889,30.999861111],[33.999861111,30.999861111]]]}', 'Israel, DTM, EPSG:4326', 'PUBLISHED', false, '-999');
INSERT INTO public.records (identifier, typename, schema, mdsource, insert_date, xml, anytext, wkt_geometry, wkb_geometry, anytext_tsvector, links, imaging_sortie_accuracy_cep_90, resolution_meter, height_range_from, height_range_to, geographic_area, undulation_model, data_type, resolution_degree, layer_polygon_parts, absolute_accuracy_lep_90, relative_accuracy_lep_90, product_bbox, product_id, product_name, product_type, description, producer_name, update_date, source_start_date, source_end_date, sensor_type, srs, srs_name, region, classification, type, footprint_geojson, keywords, product_status, has_terrain, no_data_value) VALUES ('532afeae-03c0-4f42-a006-bd1edf11874f', 'mc_MCDEMRecord', 'mc_dem', '', '2023-03-05 15:02:34+02', '', 'dem__n32_e035_1arc_v3 DTM  UNDEFINED WGS84GEO Israel 6 Israel, DTM, EPSG:4326', 'POLYGON((34.999861111 31.999861111,34.999861111 33.000138889,36.000138889 33.000138889,36.000138889 31.999861111,34.999861111 31.999861111))', '0103000020E61000000100000005000000C424EA72FB7F41408849D4E5F6FF3F40C424EA72FB7F41403CDB158D048040403CDB158D040042403CDB158D048040403CDB158D040042408849D4E5F6FF3F40C424EA72FB7F41408849D4E5F6FF3F40', '''1arc'':4 ''4326'':14 ''6'':10 ''dem'':1 ''dtm'':6,12 ''e035'':3 ''epsg'':13 ''israel'':9,11 ''n32'':2 ''undefin'':7 ''v3'':5 ''wgs84geo'':8', 'dem:n32_e035_1arc_v3,,WMTS_LAYER,https://dem-dev-qgis-server-development-route-dem-dev.apps.j1lk3njp.eastus.aroapp.io/ogc/?SERVICE=WMTS&REQUEST=GetTile&MAP=/io/data/dtm/n32_e035_1arc_v3/project/n32_e035_1arc_v3.qgs&LAYER=n32_e035_1arc_v3_vrt_heat_hill_group&OPACITIES=255&FORMAT=image/png&TILEMATRIXSET=EPSG:4326&TILEMATRIX={TileMatrix}&TILEROW={TileRow}&TILECOL={TileCol}', NULL, 30, -500, 9000, 'Israel', 'ILUM', 'Int16', 0.000277, NULL, 0.0000009, 0.0000009, NULL, 'ext_dem__n32_e035_1arc_v3', 'dem__n32_e035_1arc_v3', 'DTM', NULL, 'IDFMU', '2023-06-04 19:55:41.684176+03', '2000-02-10 21:43:00+02', '2000-02-11 21:43:00+02', 'UNDEFINED', 'EPSG:4326', 'WGS84GEO', 'Israel', '6', 'RECORD_DEM', '{"type":"Polygon","coordinates":[[[34.999861111,31.999861111],[34.999861111,33.000138889],[36.000138889,33.000138889],[36.000138889,31.999861111],[34.999861111,31.999861111]]]}', 'Israel, DTM, EPSG:4326', 'PUBLISHED', false, '-999');
INSERT INTO public.records (identifier, typename, schema, mdsource, insert_date, xml, anytext, wkt_geometry, wkb_geometry, anytext_tsvector, links, imaging_sortie_accuracy_cep_90, resolution_meter, height_range_from, height_range_to, geographic_area, undulation_model, data_type, resolution_degree, layer_polygon_parts, absolute_accuracy_lep_90, relative_accuracy_lep_90, product_bbox, product_id, product_name, product_type, description, producer_name, update_date, source_start_date, source_end_date, sensor_type, srs, srs_name, region, classification, type, footprint_geojson, keywords, product_status, has_terrain, no_data_value) VALUES ('632afeae-03c0-4f42-a006-bd1edf11874f', 'mc_MCDEMRecord', 'mc_dem', '', '2023-03-05 15:02:34+02', '', 'dem__30n030e_20101117_gmted_min075 DTM  UNDEFINED WGS84GEO Israel 6 Israel, DTM, EPSG:4326', 'POLYGON((29.999861111 29.999861111,29.999861111 49.999861111,59.999861111 49.999861111,59.999861111 29.999861111,29.999861111 29.999861111))', '0103000020E610000001000000050000008849D4E5F6FF3D408849D4E5F6FF3D408849D4E5F6FF3D40C424EA72FBFF4840C424EA72FBFF4D40C424EA72FBFF4840C424EA72FBFF4D408849D4E5F6FF3D408849D4E5F6FF3D408849D4E5F6FF3D40', '''20101117'':3 ''30n030e'':2 ''4326'':14 ''6'':10 ''dem'':1 ''dtm'':6,12 ''epsg'':13 ''gmted'':4 ''israel'':9,11 ''min075'':5 ''undefin'':7 ''wgs84geo'':8', 'dem:30n030e_20101117_gmted_min075,,WMTS_LAYER,https://dem-dev-qgis-server-development-route-dem-dev.apps.j1lk3njp.eastus.aroapp.io/ogc/?SERVICE=WMTS&REQUEST=GetTile&MAP=/io/data/dtm/30n030e_20101117_gmted_min075/project/30n030e_20101117_gmted_min075.qgs&LAYER=30n030e_20101117_gmted_min075_vrt_heat_hill_group&OPACITIES=255&FORMAT=image/png&TILEMATRIXSET=EPSG:4326&TILEMATRIX={TileMatrix}&TILEROW={TileRow}&TILECOL={TileCol}', NULL, 250, -500, 9000, 'Israel', 'ILUM', 'Int16', 0.002, NULL, 0.0000009, 0.0000009, NULL, 'ext_dem__30n030e_20101117_gmted_min075', 'dem__30n030e_20101117_gmted_min075', 'DTM', NULL, 'IDFMU', '2023-06-04 19:55:41.684176+03', '2000-02-10 21:43:00+02', '2000-02-11 21:43:00+02', 'UNDEFINED', 'EPSG:4326', 'WGS84GEO', 'Israel', '6', 'RECORD_DEM', '{"type":"Polygon","coordinates":[[[29.999861111,29.999861111],[29.999861111,49.999861111],[59.999861111,49.999861111],[59.999861111,29.999861111],[29.999861111,29.999861111]]]}', 'Israel, DTM, EPSG:4326', 'PUBLISHED', false, '-999');
INSERT INTO public.records (identifier, typename, schema, mdsource, insert_date, xml, anytext, wkt_geometry, wkb_geometry, anytext_tsvector, links, imaging_sortie_accuracy_cep_90, resolution_meter, height_range_from, height_range_to, geographic_area, undulation_model, data_type, resolution_degree, layer_polygon_parts, absolute_accuracy_lep_90, relative_accuracy_lep_90, product_bbox, product_id, product_name, product_type, description, producer_name, update_date, source_start_date, source_end_date, sensor_type, srs, srs_name, region, classification, type, footprint_geojson, keywords, product_status, has_terrain, no_data_value) VALUES ('11111111-1111-1111-1111-111111111111', 'mc_MCDEMRecord', 'mc_dem', '', '2023-04-21 00:00:00+03', '', 'srtm100 DTM  UNDEFINED WGS84GEO Israel 5 Israel, terrain, EPSG:4326', 'POLYGON((34.999861111 30.999861111,34.999861111 32.000138889,36.000138889 32.000138889,36.000138889 30.999861111,34.999861111 30.999861111))', '0103000020E61000000100000005000000C424EA72FB7F41408849D4E5F6FF3E40C424EA72FB7F41403CDB158D040040403CDB158D040042403CDB158D040040403CDB158D040042408849D4E5F6FF3E40C424EA72FB7F41408849D4E5F6FF3E40', '''4326'':10 ''5'':6 ''dtm'':2 ''epsg'':9 ''israel'':5,7 ''srtm100'':1 ''terrain'':8 ''undefin'':3 ''wgs84geo'':4', ',,TERRAIN_QMESH,https://dem-dev-proxy-development-nginx-s3-gateway-route-dem-dev.apps.j1lk3njp.eastus.aroapp.io/terrains/srtm100', NULL, 100, -500, 9000, 'North', 'ILUM', 'Int16', 0.00833, NULL, 0.0000009, 0.0000009, NULL, '11111111-1111-1111-1111-111111111111', 'srtm100', 'DTM', NULL, 'IDFMU', '2023-04-21 23:45:27.821114+03', '2023-04-21 00:00:00+03', '2023-04-21 00:00:00+03', 'UNDEFINED', 'EPSG:4326', 'WGS84GEO', 'Israel', '5', 'RECORD_DEM', '{"type":"Polygon","coordinates":[[[34.999861111,31.999861111],[34.999861111,33.000138889],[36.000138889,33.000138889],[36.000138889,31.999861111],[34.999861111,31.999861111]]]}', 'Israel, terrain, EPSG:4326', 'PUBLISHED', true, '-999');
