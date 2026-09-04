#!/usr/bin/env bash
# Deterministic half of `new-product`: writes the head of a product node.
# The interview is conducted by core/skills/new-product.md. Internal: not invocable.
#
# Usage: new-product.sh --brain DIR --org SLUG --name NAME --owner PERSON
#                       [--slug SLUG] [--identity-file FILE]
# `--workspace` is an exact synonym of `--org` (spec 039).
#
# A product node is memory — what it is, for whom, what is known — never state: it never gets
# `role:` (that activates an oficio per organization, spec 009) and never `repo:` (mount-repo writes
# that once a body exists, and mount-repo mounts onto an initiative, never onto a product). Only the
# head is born here: `context/`, `resolver.md` and `decisions.md` are born with their first piece of
# data, same as every other canonical file in this product.

set -eu

here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"

brain=""
org=""
workspace=""
name=""
owner=""
slug=""
identity_file=""

while [ $# -gt 0 ]; do
  case "$1" in
    --brain) brain="$2"; shift 2 ;;
    --org) org="$2"; shift 2 ;;
    --workspace) workspace="$2"; shift 2 ;;
    --name) name="$2"; shift 2 ;;
    --owner) owner="$2"; shift 2 ;;
    --slug) slug="$2"; shift 2 ;;
    --identity-file) identity_file="$2"; shift 2 ;;
    *) os_die "argumento desconocido: $1" ;;
  esac
done

# `--workspace` es sinónimo exacto de `--org` (P3, spec 039).
if [ -n "$org" ] && [ -n "$workspace" ] && [ "$org" != "$workspace" ]; then
  os_die "--org y --workspace con valores distintos: $org / $workspace"
fi
[ -n "$org" ] || org="$workspace"

[ -n "$brain" ] || os_die "falta --brain"
[ -n "$org" ] || os_die "falta --org o --workspace"
[ -n "$name" ] || os_die "falta --name"
[ -n "$owner" ] || os_die "falta --owner"
[ -d "$brain" ] || os_die "no existe el brain: $brain"

# Layout inválido frena acá, antes de cualquier $(...) que arme una ruta con el nombre de la
# carpeta (P2, spec 039).
os_ws_check "$brain"
wsdir=$(os_ws_dir "$brain")

# El idioma es dato de la raíz (spec 021): lo declara `operator.md` y no se vuelve a preguntar.
language=$(os_language "$brain")
os_lang_load "$language"

# El ámbito se valida contra el listado real de la carpeta de espacios de trabajo, byte a byte —
# mismo criterio que `session-start.sh` (spec 002/003): sin el espacio de trabajo, el comando no
# escribe nada y lista los que hay, con el mismo par de claves del catálogo que ya usa el arranque
# de sesión.
if ! os_org_existe "$brain" "$org"; then
  printf "$S_SESSION_ORG_NOT_FOUND\n" "$org" >&2
  found=0
  while IFS= read -r s || [ -n "$s" ]; do
    [ -n "$s" ] || continue
    found=1
    printf '  %s\n' "$s" >&2
  done <<SLUGS
$(os_org_slugs "$brain")
SLUGS
  [ "$found" = "1" ] || printf '  %s\n' "$S_SESSION_NO_ORGS" >&2
  exit 2
fi

[ -n "$slug" ] || slug=$(os_slugify "$name")
[ -n "$slug" ] || os_die "el nombre no produce un slug utilizable: $name"

dir="$brain/$wsdir/$org/products/$slug"
if [ -e "$dir" ]; then
  os_die "ya existe: $wsdir/$org/products/$slug"
fi

identity="$S_PRODUCT_IDENTITY_PLACEHOLDER"
if [ -n "$identity_file" ]; then
  [ -f "$identity_file" ] || os_die "no existe el archivo de identidad: $identity_file"
  identity=$(cat "$identity_file")
fi

templates="$here/../templates/node-product"
today=$(date +%Y-%m-%d)

mkdir -p "$dir"

# El nombre de la cabeza es dato del brain (spec 040), igual que en `new-workspace`.
head=$(os_head_file "$brain") || true
os_render_lang "$templates/README.md" "$language" \
  "NAME=$name" "OWNER=$owner" "DATE=$today" "IDENTITY=$identity" \
  > "$dir/$head"

os_check_identity_cap "$dir/$head"

# Los tres globs del nivel llegan de fábrica en `core/templates/tree.md`; acá se agregan a un brain
# que ya existía antes de esta spec, sin duplicar (mismo patrón que `capture.sh`/`close-session.sh`
# con los archivos que nacen con su primer dato).
os_tree_ensure "$brain" "$wsdir/*/products/*/$head" || true
os_tree_ensure "$brain" "$wsdir/*/products/*/resolver.md" || true
os_tree_ensure "$brain" "$wsdir/*/products/*/decisions.md" || true

# Las dos carpetas de un producto nacen con su primer dato y son contenido, nunca cabeza: `context/`
# es la capa estratégica y `research/` todo documento fechado (spec 040). Se declaran acá para que el
# primer archivo que el operador escriba adentro no aparezca como "ningún glob alcanza".
os_tree_ensure "$brain" "$wsdir/*/products/*/context/*.md" content || true
os_tree_ensure "$brain" "$wsdir/*/products/*/research/*.md" content || true

printf '%s/%s/products/%s — %s\n' "$wsdir" "$org" "$slug" "$head"
