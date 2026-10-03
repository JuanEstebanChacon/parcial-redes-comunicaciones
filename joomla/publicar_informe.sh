#!/bin/sh
# Publica el informe del parcial como artículo destacado en la página de inicio de Joomla.
# Lo ejecuta el servicio joomla-init cuando Joomla ya está instalado (depends_on: service_healthy).
# Es idempotente: si el artículo ya existe, solo actualiza su contenido con informe.html.
set -eu

export PGHOST=database
export PGUSER="$POSTGRES_USER"
export PGPASSWORD="$POSTGRES_PASSWORD"
export PGDATABASE="$POSTGRES_DB"
export PGCLIENTENCODING=UTF8

ALIAS="informe-parcial-2"
TITULO="Informe – Parcial 2 Comunicaciones"

# El instalador de Joomla crea las tablas con un prefijo (por ejemplo "joom_"); se detecta solo.
P=$(psql -tAc "SELECT left(table_name, length(table_name) - length('content_frontpage')) FROM information_schema.tables WHERE table_schema = 'public' AND table_name LIKE '%content_frontpage' LIMIT 1")

if [ -z "$P" ]; then
  echo "No se encontraron las tablas de Joomla. ¿Terminó la instalación?" >&2
  exit 1
fi
echo "Prefijo de las tablas de Joomla: $P"

psql -v ON_ERROR_STOP=1 -q \
  -v t_content="${P}content" \
  -v t_front="${P}content_frontpage" \
  -v t_wa="${P}workflow_associations" \
  -v t_ws="${P}workflow_stages" \
  -v t_users="${P}users" \
  -v t_cat="${P}categories" \
  -v alias="$ALIAS" \
  -v titulo="$TITULO" <<'SQL'
\set informe `cat /informe/informe.html`
BEGIN;

-- 1. Crear el artículo si no existe (autor: el administrador; categoría: Uncategorised)
INSERT INTO :"t_content" (asset_id, title, alias, introtext, "fulltext", state, catid,
                          created, created_by, created_by_alias, modified, modified_by, publish_up,
                          images, urls, attribs, version, ordering, metakey, metadesc,
                          access, hits, metadata, featured, language, note)
SELECT 0, :'titulo', :'alias', :'informe', '', 1,
       (SELECT id FROM :"t_cat" WHERE extension = 'com_content' AND alias = 'uncategorised' LIMIT 1),
       NOW(), u.id, '', NOW(), u.id, NOW(),
       '{}', '{}', '{}', 1, 0, '', '',
       1, 0, '{}', 1, '*', ''
FROM (SELECT id FROM :"t_users" ORDER BY id LIMIT 1) AS u
WHERE NOT EXISTS (SELECT 1 FROM :"t_content" WHERE alias = :'alias');

-- 2. Si ya existía, actualizar el contenido con la versión actual de informe.html
UPDATE :"t_content"
   SET introtext = :'informe', title = :'titulo', state = 1, featured = 1, modified = NOW()
 WHERE alias = :'alias';

-- 3. Marcarlo como destacado: la página de inicio de Joomla muestra los artículos destacados
INSERT INTO :"t_front" (content_id, ordering)
SELECT c.id, 1 FROM :"t_content" c
 WHERE c.alias = :'alias'
   AND NOT EXISTS (SELECT 1 FROM :"t_front" f WHERE f.content_id = c.id);

-- 4. Asociarlo al flujo de publicación por defecto de Joomla
INSERT INTO :"t_wa" (item_id, stage_id, extension)
SELECT c.id, (SELECT id FROM :"t_ws" ORDER BY id LIMIT 1), 'com_content.article'
  FROM :"t_content" c
 WHERE c.alias = :'alias'
   AND NOT EXISTS (SELECT 1 FROM :"t_wa" w WHERE w.item_id = c.id AND w.extension = 'com_content.article');

COMMIT;
SQL

echo "Informe publicado en la página de inicio de Joomla."