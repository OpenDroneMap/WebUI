-- Enable PostGIS extensions on template1 so all new databases inherit them
\c template1

-- Enable PostGIS extensions (required for PostgreSQL 14+)
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_raster;
CREATE EXTENSION IF NOT EXISTS postgis_topology;

-- Create the production database
CREATE DATABASE webui_dev;

-- Connect to webui_dev to enable extensions
\c webui_dev


-- Configure PostGIS settings
ALTER DATABASE webui_dev SET postgis.gdal_enabled_drivers TO 'GTiff';
ALTER DATABASE webui_dev SET postgis.enable_outdb_rasters TO True;
