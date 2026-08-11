#!/usr/bin/env bash
# Parte determinística de `new-org`: escribe el nodo de la organización.
# La entrevista la conduce core/skills/new-org.md. Interno: no es invocable.
#
# Uso: new-org.sh --brain DIR --name NOMBRE --role ROL --owner PERSONA
#                 [--title TITULO] [--slug SLUG] [--identity-file ARCHIVO]
#
# `--role` activa un oficio de posición del pack (spec 009) y nace vacío (spec 020): es un acto
# deliberado, aparte de la entrevista, nombrar ahí el slug de un oficio instalado (hoy: `cpo`).
# `--title` es identidad —"qué hacés en esta organización", en palabras del operador— y va al
# cuerpo de `context.md`, nunca al frontmatter: no activa nada.

set -eu

here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"

brain=""
name=""
role=""
role_given=0
title=""
owner=""
slug=""
identity_file=""

while [ $# -gt 0 ]; do
  case "$1" in
    --brain) brain="$2"; shift 2 ;;
    --name) name="$2"; shift 2 ;;
    --role) role="$2"; role_given=1; shift 2 ;;
    --title) title="$2"; shift 2 ;;
    --owner) owner="$2"; shift 2 ;;
    --slug) slug="$2"; shift 2 ;;
    --identity-file) identity_file="$2"; shift 2 ;;
    *) os_die "argumento desconocido: $1" ;;
  esac
done

[ -n "$brain" ] || os_die "falta --brain"
[ -n "$name" ] || os_die "falta --name"
# El comando escribe `role:`, nunca el humano. Nace vacío (spec 020): --role "" es válido,
# omitir --role no lo es — la misma disciplina de antes, ahora con el valor por omisión en vacío.
[ "$role_given" = "1" ] || os_die "falta --role: el rol lo escribe el comando, no el humano"
[ -n "$owner" ] || os_die "falta --owner"

[ -n "$slug" ] || slug=$(os_slugify "$name")
[ -n "$slug" ] || os_die "el nombre no produce un slug utilizable: $name"

dir="$brain/orgs/$slug"
if [ -e "$dir" ]; then
  os_die "ya existe: orgs/$slug"
fi

# El idioma es dato de la raíz (spec 021): lo declara `operator.md` y no se vuelve a preguntar. Una
# organización sumada meses después nace en el mismo idioma que el resto del brain.
language=$(os_language "$brain")
os_lang_load "$language"

identity="$S_ORG_IDENTITY_PLACEHOLDER"
if [ -n "$identity_file" ]; then
  [ -f "$identity_file" ] || os_die "no existe el archivo de identidad: $identity_file"
  identity=$(cat "$identity_file")
fi

templates="$here/../templates/node-folder"
today=$(date +%Y-%m-%d)

mkdir -p "$dir/initiatives"
os_render_lang "$templates/context.md" "$language" \
  "NAME=$name" "ROLE=$role" "TITLE=$title" "OWNER=$owner" "DATE=$today" "IDENTITY=$identity" \
  > "$dir/context.md"
os_render_lang "$templates/resolver.md" "$language" "NAME=$name" > "$dir/resolver.md"

os_check_identity_cap "$dir/context.md"

printf 'orgs/%s — context.md · resolver.md · initiatives/\n' "$slug"
