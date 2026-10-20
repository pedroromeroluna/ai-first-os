#!/usr/bin/env bash
# Deterministic half of `new-memory`: writes the head of a memory node, of any type. The interview
# is conducted by core/skills/new-memory.md. Internal: not invocable.
#
# Usage: new-memory.sh --brain DIR --org SLUG --type TYPE --name NAME --owner PERSON
#                      [--slug SLUG] [--identity-file FILE]
# `--workspace` is an exact synonym of `--org` (spec 039), same as every other command that takes a
# workspace.
#
# `--root` no longer creates anything (spec 059): the root of the brain is machinery only, and a
# memory node is content. The flag is still accepted, only to refuse with an error that names the
# operator's own workspace (`personal`) as the destination — never silently "unknown argument".
#
# The carrier of "what kind of thing this is" is the folder, never a field (spec 041 decision): the
# TYPE argument is the name of the sibling folder — `products`, `accounts`, `channels`, or one the
# operator invents. `new-product.sh` is a fixed-type wrapper of this script (`--type products`); its
# own output never changes.
#
# A memory node is memory — what it is, what is known — never state: it never gets `role:` (that
# activates an oficio per organization, spec 009) and never `repo:` (mount-repo writes that once a
# body exists, and mount-repo mounts onto an initiative, never onto a memory node). Only the head is
# born here (spec 076, C15): no resolver and no decisions of its own.

set -eu

here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"

brain=""
org=""
workspace=""
root=0
type=""
name=""
owner=""
slug=""
identity_file=""

while [ $# -gt 0 ]; do
  case "$1" in
    --brain) brain="$2"; shift 2 ;;
    --org) org="$2"; shift 2 ;;
    --workspace) workspace="$2"; shift 2 ;;
    --root) root=1; shift ;;
    --type) type="$2"; shift 2 ;;
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
if [ "$root" = "1" ]; then
  os_die "--root ya no crea nada (spec 059): la raíz solo tiene maquinaria — usá --org $OS_PERSONAL_WORKSPACE_SLUG o --workspace $OS_PERSONAL_WORKSPACE_SLUG, el espacio de trabajo propio del operador"
fi
[ -n "$org" ] || os_die "falta --org o --workspace"
[ -n "$type" ] || os_die "falta --type"
case "$type" in
  */*|.|..) os_die "--type inválido: $type" ;;
esac
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

dir="$brain/$wsdir/$org/$type/$slug"
rel="$wsdir/$org/$type/$slug"
tree_prefix="$wsdir/*/"
if [ -e "$dir" ]; then
  os_die "ya existe: $rel"
fi

# El texto de placeholder es el de `products` cuando el tipo es `products` —la salida de
# `new-product.sh` no cambia, letra por letra— y el genérico de cualquier otro tipo.
if [ "$type" = "products" ]; then
  identity="$S_PRODUCT_IDENTITY_PLACEHOLDER"
else
  identity="$S_MEMORY_IDENTITY_PLACEHOLDER"
fi
if [ -n "$identity_file" ]; then
  [ -f "$identity_file" ] || os_die "no existe el archivo de identidad: $identity_file"
  identity=$(cat "$identity_file")
fi

# La misma plantilla que ya usaba `new-product.sh`: sin campo `role:`, genérica de fábrica —
# NAME/OWNER/DATE/IDENTITY— y por eso sirve para cualquier tipo de nodo de memoria sin tocarla.
templates="$here/../templates/node-product"
today=$(date +%Y-%m-%d)

mkdir -p "$dir"

# El nombre de la cabeza es dato del brain (spec 040), igual que en `new-workspace`.
head=$(os_head_file "$brain") || true
os_render_lang "$templates/README.md" "$language" \
  "NAME=$name" "OWNER=$owner" "DATE=$today" "IDENTITY=$identity" \
  > "$dir/$head"

os_check_identity_cap "$dir/$head"

# The lines of a type (spec 041, revised by spec 076): the head and the hidden `.resolver.md` as
# `glob:`, and as `content:` the generated `index.md` plus `context/`, `research/` and `resources/`.
# No `decisions.md` or `decisions/` of its own: decisions live flat in the workspace with `about:`
# (C17). Idempotent through `os_tree_ensure`, so a second node of the same type duplicates nothing.
os_tree_ensure "$brain" "${tree_prefix}${type}/*/$head" || true
os_tree_ensure "$brain" "${tree_prefix}${type}/*/.resolver.md" || true
os_tree_ensure "$brain" "${tree_prefix}${type}/*/index.md" content || true
os_tree_ensure "$brain" "${tree_prefix}${type}/*/context/*.md" content || true
os_tree_ensure "$brain" "${tree_prefix}${type}/*/research/*.md" content || true
os_tree_ensure "$brain" "${tree_prefix}${type}/*/resources/*.md" content || true
os_tree_ensure "$brain" "${tree_prefix}${type}/*/resources/*/*.md" content || true

printf '%s — %s\n' "$rel" "$head"
