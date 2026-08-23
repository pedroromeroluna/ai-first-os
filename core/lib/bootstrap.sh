#!/usr/bin/env bash
# Parte determinística de `bootstrap`: escribe el brain mínimo con las respuestas de la entrevista.
# La entrevista la conduce core/skills/bootstrap.md. Interno: no es invocable.
#
# Uso: bootstrap.sh --brain DIR --answers ARCHIVO
#
# Formato del archivo de respuestas — una clave por línea, `clave: valor` (spec 021):
#   language: idioma de todo lo que se escribe: `en` o `es`. Primera clave; sin ella, `en`.
#   name:     nombre del operador
#   profile:  el rol en una línea ("Senior PM en una fintech")
#   voice:    una línea por ítem de la voz (se repite; la entrevista la declara opcional)
#   org:      Nombre | título | dueño | archivo-de-identidad   (se repite; los dos últimos, opcionales)
#             El título es identidad —"qué hacés ahí"— y va al cuerpo de la cabeza, nunca a
#             `role:` (spec 020): ese campo activa un oficio del pack y nace vacío.
# `reply:` no existe más (spec 021): "cómo querés que te conteste" no se pregunta, y el default vive
# en el template de `operator.md` marcado como sección que se aprende con el uso. Sin
# retrocompatibilidad: un archivo viejo con `reply:` frena con el motivo.
# Las líneas vacías y las que empiezan con `#` se ignoran.
#
# El respaldo tiene dos mitades (spec 021). Acá va la local, que corre siempre y sin preguntar: `git
# init` + primer commit. La remota —crear el repo y pushear, o dejar la tarea guiada en el backlog de
# la raíz— es `remote-backup.sh`, que la sesión corre después y que cualquier sesión posterior puede
# volver a correr.

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

# git es requisito duro (spec 024): la primera verificación del script, antes de crear ningún
# archivo. Reemplaza la decisión 3 de la spec 023, que dejaba nacer un brain sin versionar. Sin
# git no se escribe nada — ni siquiera la carpeta del brain — y el mensaje dice de dónde
# instalarlo y que este mismo comando se re-corre solo.
command -v git > /dev/null 2>&1 \
  || os_die "falta git: instalalo desde el canal oficial (macOS: correr \`xcode-select --install\`; Windows: bajarlo de git-scm.com — lo instala el operador, nunca el agente) y volvé a correr este mismo comando — el bootstrap no escribió nada"

# python3 es requisito duro junto a git (spec 030): mount-repo lo necesita para autorizar el
# checkout que monta. Mismo patrón y mismo momento que el chequeo de git — la segunda verificación,
# todavía antes de crear ningún archivo. Con git ausente el mensaje de arriba ya frenó, así que este
# chequeo solo se alcanza con git presente.
command -v python3 > /dev/null 2>&1 \
  || os_die "falta python3: instalalo desde el canal oficial (macOS: correr \`xcode-select --install\`, el mismo comando que trae git; Windows: bajarlo de python.org; Linux: el gestor de paquetes de la distro) y volvé a correr este mismo comando — el bootstrap no escribió nada"

name=""
language=""
profile=""
voice=""
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

# os_append_kv ACUMULADO CLAVE ITEM -> acumulado con `clave: item` en su línea. El registro de la
# voz queda con el mismo vocabulario que la entrevista lo trajo — nunca se renderiza a prosa — para
# que quede greppeable como lo que es: un dato, no una sección narrada.
os_append_kv() {
  if [ -z "$1" ]; then
    printf '%s: %s' "$2" "$3"
  else
    printf '%s%s%s: %s' "$1" "$nl" "$2" "$3"
  fi
}

# respaldo_local BRAIN IDIOMA
# `git init` + primer commit. git ya está garantizado en el PATH — el chequeo duro corre al
# principio del script, antes de escribir nada (spec 024) — así que acá no queda rama por su
# ausencia. Dos cosas se declaran en vez de hacerse en silencio:
#   - un brain adentro de otro repo git NO se inicializa: un repo anidado adentro del árbol de
#     trabajo de otro es una trampa —el de afuera lo ve como una carpeta sin seguimiento y el
#     respaldo del brain queda a merced de esa confusión—, así que se nombra el repo de afuera y lo
#     resuelve el operador;
#   - sin identidad de git configurada, el commit se firma con una identidad genérica del producto y
#     se avisa: el respaldo vale más que la firma.
respaldo_local() {
  local brain="$1" lang="$2" top rc
  os_lang_load "$lang"
  top=$(git -C "$brain" rev-parse --show-toplevel 2>/dev/null) || top=""
  if [ -n "$top" ] && [ "$top" != "$brain" ]; then
    printf 'sin respaldo: el brain vive adentro del repo %s — un repo anidado no se crea solo; moverlo afuera o versionarlo a mano lo elige el operador\n' "$top"
    return 0
  fi
  [ -n "$top" ] || git -C "$brain" init -q
  git -C "$brain" add -A
  if git -C "$brain" commit -q -m "$S_FIRST_COMMIT" > /dev/null 2>&1; then
    printf 'respaldo local: git init + primer commit\n'
    return 0
  fi
  if git -C "$brain" -c user.name="AI First OS" -c user.email="bootstrap@ai-first-os.local" \
       commit -q -m "$S_FIRST_COMMIT" > /dev/null 2>&1; then
    printf 'respaldo local: git init + primer commit, firmado con una identidad genérica — configurá git (user.name, user.email) para los que siguen\n'
    return 0
  fi
  printf 'sin respaldo: el primer commit falló — el brain quedó versionado sin commits\n'
  return 0
}

while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in
    ''|'#'*) continue ;;
  esac
  key="${line%%:*}"
  value=$(os_trim "${line#*:}")
  case "$key" in
    name) name="$value" ;;
    language) language=$(os_lower "$value") ;;
    profile) profile=$(os_append "$profile" "$value") ;;
    voice) voice=$(os_append_kv "$voice" "voice" "$value") ;;
    reply) os_die "la clave reply: no existe desde la spec 021: el default de cómo se contesta vive en el template de operator.md" ;;
    org) orgs="$orgs$value$nl" ;;
    *) os_die "clave desconocida en las respuestas: $key" ;;
  esac
done < "$answers"

[ -n "$name" ] || os_die "falta la clave name: en las respuestas"

# El idioma es la primera pregunta de la entrevista y gobierna todo lo que se escribe. Sin dato, se
# escribe en inglés y el hueco se declara abajo: elegir por el operador en silencio le deja un brain
# en un idioma que no eligió.
sin_language=0
if [ -z "$language" ]; then
  language="en"
  sin_language=1
elif ! os_language_valido "$language"; then
  os_die "idioma no soportado: $language — hoy: $OS_LANGUAGES"
fi

templates="$here/../templates"
mkdir -p "$brain"
# Ruta física: `git rev-parse --show-toplevel` la devuelve resuelta, y comparar contra una ruta con
# symlinks adentro (`/var` → `/private/var` en macOS) hace ver como repo ajeno al repo propio.
brain=$(cd "$brain" && pwd -P)

# El bootstrap crea; no rehace. Si las piezas de la raíz ya están, frena: reescribirlas borraría lo
# que el operador haya escrito encima, y eso es pérdida silenciosa. Agregar espacios de trabajo a un
# brain que ya existe es trabajo de new-workspace.
existing=""
for f in operator.md voice.md resolver.md tree.md; do
  if [ -e "$brain/$f" ]; then
    existing="$existing $f"
  fi
done
if [ -n "$existing" ]; then
  os_die "el brain ya tiene:$existing — el bootstrap no los reescribe. Para sumar un espacio de trabajo, new-workspace."
fi

# Una identidad, dos archivos: operator.md contesta quién es y cómo se le contesta; voice.md, cómo
# escribe. La voz sale de operator.md desde la spec 018 — nunca las dos cosas a la vez, o la misma
# frase termina viviendo en dos lugares.
# La prosa fija sale del catálogo `templates/strings.md` en el idioma elegido: un solo template por
# archivo, una traducción por string (spec 021). Nunca un árbol de templates por idioma.
os_render_lang "$templates/operator.md" "$language" \
  "NAME=$name" "LANGUAGE=$language" "PROFILE=$profile" > "$brain/operator.md"
# La voz es opcional: sin dato, el archivo lo dice en vez de nacer con una sección en blanco.
voice_body="$voice"
[ -n "$voice_body" ] || voice_body="$S_VOICE_PENDING"
os_render_lang "$templates/voice.md" "$language" \
  "NAME=$name" "VOICE=$voice_body" > "$brain/voice.md"
os_render_lang "$templates/root-resolver.md" "$language" > "$brain/resolver.md"
# El manual de usuario es del idioma del brain, y su nombre lo enuncia `os_manual_file` una sola vez
# (spec 022). El árbol lo declara como contenido: se ve en la raíz y ningún barrido lo lee como
# trabajo.
manual=$(os_manual_file "$language")
os_render "$templates/tree.md" "MANUAL=$manual" > "$brain/tree.md"

os_check_identity_cap "$brain/operator.md"

printf 'operator.md · voice.md · resolver.md · tree.md\n'

# El manual se engancha por symlink al del producto: nace con el brain y se actualiza con el
# producto, sin volver a correr nada.
"$here/manual-link.sh" --brain "$brain" --language "$language" || true

# Lo que la entrevista no trajo se declara. Un hueco silencioso es un hueco que nadie completa.
vacias=""
[ "$sin_language" = "0" ] || vacias="$vacias language"
[ -n "$profile" ] || vacias="$vacias profile"
[ -n "$voice" ] || vacias="$vacias voice"
[ -n "$orgs" ] || vacias="$vacias org"
if [ -n "$vacias" ]; then
  printf 'sin dato:%s — las secciones quedaron vacías y hay que volver a preguntarlas\n' "$vacias"
fi

# Una organización que falla no aborta las demás, y las que no se crearon se nombran.
fallidas=""
while IFS= read -r org; do
  [ -n "$org" ] || continue
  IFS='|' read -r org_name org_title org_owner org_identity <<EOF
$org
EOF
  org_name=$(os_trim "$org_name")
  org_title=$(os_trim "${org_title:-}")
  org_owner=$(os_trim "${org_owner:-}")
  org_identity=$(os_trim "${org_identity:-}")
  # El dueño por omisión es el operador: la organización la crea él.
  [ -n "$org_owner" ] || org_owner="$name"
  # El segundo campo es identidad —"qué hacés ahí"—, no activación (spec 020): va al cuerpo vía
  # --title, nunca a --role. `role:` nace vacío; completarlo con el slug de un oficio del pack es
  # un acto aparte, posterior.
  set -- --brain "$brain" --name "$org_name" --role "" --title "$org_title" --owner "$org_owner"
  if [ -n "$org_identity" ]; then
    set -- "$@" --identity-file "$org_identity"
  fi
  if ! "$here/new-workspace.sh" "$@"; then
    fallidas="$fallidas $org_name"
  fi
done <<ORGS
$orgs
ORGS

# ---------------------------------------------------------------- la mitad local del respaldo
# Corre siempre, sin cuenta ni pregunta (spec 021, decisión 3). Es la única mitad que no depende de
# nada de afuera: el brain nace versionado aunque nunca haya un remoto.
respaldo_local "$brain" "$language"

if [ -n "$fallidas" ]; then
  printf 'sin crear:%s — cada una con su error arriba. El resto del brain quedó escrito.\n' "$fallidas" >&2
  exit 1
fi
