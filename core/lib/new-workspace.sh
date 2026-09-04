#!/usr/bin/env bash
# Parte determinística de `new-workspace`: escribe el nodo del espacio de trabajo.
# La entrevista la conduce core/skills/new-workspace.md. Interno: no es invocable.
#
# Uso: new-workspace.sh --brain DIR --name NOMBRE --role ROL --owner PERSONA
#                       [--title TITULO] [--slug SLUG] [--identity-file ARCHIVO]
#
# `--role` activa un oficio de posición del pack (spec 009) y nace vacío (spec 020): es un acto
# deliberado, aparte de la entrevista, nombrar ahí el slug de un oficio instalado (hoy: `cpo`).
# `--title` es identidad —"qué hacés en esta organización", en palabras del operador— y va al
# cuerpo de la cabeza, nunca al frontmatter: no activa nada.

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

# Layout inválido frena acá, antes de cualquier $(...) que arme una ruta con el nombre de la
# carpeta (P2, spec 039): un `os_die` adentro de una subshell mata solo la subshell.
os_ws_check "$brain"
wsdir=$(os_ws_dir "$brain")

dir="$brain/$wsdir/$slug"
if [ -e "$dir" ]; then
  os_die "ya existe: $wsdir/$slug"
fi

# El idioma es dato de la raíz (spec 021): lo declara `operator.md` y no se vuelve a preguntar. Un
# espacio de trabajo sumado meses después nace en el mismo idioma que el resto del brain.
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

# El nombre de la cabeza es dato del brain (spec 040): la forma nueva es `README.md` y un brain que
# todavía no la adoptó recibe su nodo nuevo en la forma que ya tiene — mezclar las dos en el mismo
# brain es el layout que `rename-heads` existe para reparar.
head=$(os_head_file "$brain") || true
os_render_lang "$templates/README.md" "$language" \
  "NAME=$name" "ROLE=$role" "TITLE=$title" "OWNER=$owner" "DATE=$today" "IDENTITY=$identity" \
  > "$dir/$head"
os_render_lang "$templates/resolver.md" "$language" "NAME=$name" > "$dir/resolver.md"

os_check_identity_cap "$dir/$head"

# La altura del espacio de trabajo queda declarada en el árbol, en la forma con la que este nodo
# acaba de nacer (spec 040). Un brain que no la tenía —uno que hasta hoy solo tuvo trabajo propio de
# la raíz— se quedaba con el nodo nuevo sin que ningún glob lo alcanzara: escrito y ciego para todo
# barrido. Los brains que ya la declaran no cambian: `os_tree_ensure` no duplica.
os_tree_ensure "$brain" "$wsdir/*/$head" || true
os_tree_ensure "$brain" "$wsdir/*/resolver.md" || true
os_tree_ensure "$brain" "$wsdir/*/backlog.md" || true
os_tree_ensure "$brain" "$wsdir/*/decisions.md" || true
os_tree_ensure "$brain" "$wsdir/*/learnings.md" || true
# La altura de las iniciativas de ese nodo, en la forma que el brain tenga para esa altura: el
# glob sale del mismo helper que arma la ruta de una cabeza, con `*` en lugar del slug.
os_tree_ensure "$brain" "$wsdir/*/$(os_head_path "$brain" initiative '*')" || true
os_tree_ensure "$brain" "$wsdir/*/initiatives/*/*.md" content || true

printf '%s/%s — %s · resolver.md · initiatives/\n' "$wsdir" "$slug" "$head"
