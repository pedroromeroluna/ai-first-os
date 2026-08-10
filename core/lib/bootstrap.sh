#!/usr/bin/env bash
# Parte determinística de `bootstrap`: escribe el brain mínimo con las respuestas de la entrevista.
# La entrevista la conduce core/skills/bootstrap.md. Interno: no es invocable.
#
# Uso: bootstrap.sh --brain DIR --answers ARCHIVO
#
# Formato del archivo de respuestas — una clave por línea, `clave: valor`:
#   name:    nombre del operador
#   profile: una línea por ítem del perfil profesional (se repite)
#   voice:   una línea por ítem de la voz (se repite)
#   reply:   una línea por ítem de "cómo se me contesta" (se repite)
#   org:     Nombre | rol | dueño | archivo-de-identidad   (se repite; los dos últimos, opcionales)
# Las líneas vacías y las que empiezan con `#` se ignoran.

set -eu

here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"

brain=""
answers=""

while [ $# -gt 0 ]; do
  case "$1" in
    --brain) brain="$2"; shift 2 ;;
    --answers) answers="$2"; shift 2 ;;
    *) os_die "argumento desconocido: $1" ;;
  esac
done

[ -n "$brain" ] || os_die "falta --brain"
[ -n "$answers" ] || os_die "falta --answers"
[ -f "$answers" ] || os_die "no existe el archivo de respuestas: $answers"

name=""
profile=""
voice=""
reply=""
orgs=""
nl=$(printf '\n.')
nl="${nl%.}"

os_append() {
  # os_append ACUMULADO ITEM -> acumulado con el ítem como viñeta en su línea
  if [ -z "$1" ]; then
    printf -- '- %s' "$2"
  else
    printf -- '%s%s- %s' "$1" "$nl" "$2"
  fi
}

while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in
    ''|'#'*) continue ;;
  esac
  key="${line%%:*}"
  value=$(os_trim "${line#*:}")
  case "$key" in
    name) name="$value" ;;
    profile) profile=$(os_append "$profile" "$value") ;;
    voice) voice=$(os_append "$voice" "$value") ;;
    reply) reply=$(os_append "$reply" "$value") ;;
    org) orgs="$orgs$value$nl" ;;
    *) os_die "clave desconocida en las respuestas: $key" ;;
  esac
done < "$answers"

[ -n "$name" ] || os_die "falta la clave name: en las respuestas"

templates="$here/../templates"
mkdir -p "$brain"

# El bootstrap crea; no rehace. Si las piezas de la raíz ya están, frena: reescribirlas borraría lo
# que el operador haya escrito encima, y eso es pérdida silenciosa. Agregar organizaciones a un
# brain que ya existe es trabajo de new-org.
existing=""
for f in operator.md resolver.md tree.md; do
  if [ -e "$brain/$f" ]; then
    existing="$existing $f"
  fi
done
if [ -n "$existing" ]; then
  os_die "el brain ya tiene:$existing — el bootstrap no los reescribe. Para sumar una organización, new-org."
fi

os_render "$templates/operator.md" \
  "NAME=$name" "PROFILE=$profile" "VOICE=$voice" "REPLY=$reply" > "$brain/operator.md"
os_render "$templates/root-resolver.md" > "$brain/resolver.md"
os_render "$templates/tree.md" > "$brain/tree.md"

os_check_identity_cap "$brain/operator.md"

printf 'operator.md · resolver.md · tree.md\n'

# Lo que la entrevista no trajo se declara. Un hueco silencioso es un hueco que nadie completa.
vacias=""
[ -n "$profile" ] || vacias="$vacias profile"
[ -n "$voice" ] || vacias="$vacias voice"
[ -n "$reply" ] || vacias="$vacias reply"
[ -n "$orgs" ] || vacias="$vacias org"
if [ -n "$vacias" ]; then
  printf 'sin dato:%s — las secciones quedaron vacías y hay que volver a preguntarlas\n' "$vacias"
fi

# Una organización que falla no aborta las demás, y las que no se crearon se nombran.
fallidas=""
while IFS= read -r org; do
  [ -n "$org" ] || continue
  IFS='|' read -r org_name org_role org_owner org_identity <<EOF
$org
EOF
  org_name=$(os_trim "$org_name")
  org_role=$(os_trim "${org_role:-}")
  org_owner=$(os_trim "${org_owner:-}")
  org_identity=$(os_trim "${org_identity:-}")
  # El dueño por omisión es el operador: la organización la crea él.
  [ -n "$org_owner" ] || org_owner="$name"
  set -- --brain "$brain" --name "$org_name" --role "$org_role" --owner "$org_owner"
  if [ -n "$org_identity" ]; then
    set -- "$@" --identity-file "$org_identity"
  fi
  if ! "$here/new-org.sh" "$@"; then
    fallidas="$fallidas $org_name"
  fi
done <<ORGS
$orgs
ORGS

if [ -n "$fallidas" ]; then
  printf 'sin crear:%s — cada una con su error arriba. El resto del brain quedó escrito.\n' "$fallidas" >&2
  exit 1
fi
