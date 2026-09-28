-- Expone el log de nginx como tabla SQL para Grafana
CREATE EXTENSION IF NOT EXISTS file_fdw;

CREATE SERVER IF NOT EXISTS logs_srv FOREIGN DATA WRAPPER file_fdw;

CREATE FOREIGN TABLE IF NOT EXISTS nginx_accesos_raw (
    ts text, ip text, servicio text, metodo text,
    uri text, status text, bytes text, tiempo text
) SERVER logs_srv
  OPTIONS (filename '/logs/nginx/accesos.log', format 'text', delimiter '|');

CREATE OR REPLACE VIEW nginx_accesos AS
SELECT ts::timestamptz    AS ts,
       ip,
       servicio,
       metodo,
       uri,
       status::int        AS status,
       bytes::bigint      AS bytes,
       tiempo::numeric    AS tiempo_resp
FROM nginx_accesos_raw;