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
#   workspace: Nombre | título | dueño | archivo-de-identidad  (se repite; los dos últimos,
#             opcionales). El cerebro nace siempre con `workspaces/personal` — "My workspace" / "Mi
#             workspace" — sin que la entrevista lo pregunte (spec 059, decisión 3): esta clave ya
#             no es una pregunta de la entrevista, pero sigue siendo la forma de sumar, en el mismo
#             acto, uno o más espacios de trabajo con nombre — lo que antes hacía nacer un brain con
#             "una persona, un empleador"; después de este bootstrap eso mismo es `new-workspace`,
#             corrido aparte. El título es identidad —"qué hacés ahí"— y va al cuerpo de la cabeza,
#             nunca a `role:` (spec 020): ese campo activa un oficio del pack y nace vacío.
#   skipped:  el nombre de una pregunta opcional que el operador dejó vacía a propósito: hoy, solo
#             `voice` (se repite). Es la diferencia entre "no contestó" y "contestó que no tiene"
#             (spec 052): lo declarado vacío no se vuelve a preguntar. `skipped: workspace` ya no
#             existe (spec 059): la pregunta que declaraba desapareció de la entrevista entera, así
#             que no hay una respuesta vacía que declarar — frena con el motivo, igual que `org:`.
# `org:` no existe más (spec 052): el espacio de trabajo se declara con `workspace:`, que es el
# nombre que el usuario ve desde la spec 039. Sin retrocompatibilidad: un archivo de respuestas
# viejo con `org:` frena con el motivo.
# `reply:` no existe más (spec 021): "cómo querés que te conteste" no se pregunta, y el default vive
# en el template de `operator.md` marcado como sección que se aprende con el uso. Sin
# retrocompatibilidad: un archivo viejo con `reply:` frena con el motivo.
# Las líneas vacías y las que empiezan con `#` se ignoran.
#
# El respaldo tiene dos mitades (spec 021). Acá va la local, que corre siempre y sin preguntar: `git
# init` + primer commit. La remota —crear el repo y pushear, o preguntar si se anota la tarea guiada en
# el espacio de trabajo `personal` y anotarla solo con el sí— es `remote-backup.sh`, que la sesión corre
# después y que cualquier sesión posterior puede volver a correr.

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

name=""
language=""
profile=""
voice=""
workspaces=""
skipped=""
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
  local brain="$1" lang="$2" state
  os_lang_load "$lang"
  state=$(os_brain_repo_state "$brain")
  case "$state" in
    inside\ *)
      printf 'sin respaldo: el brain vive adentro del repo %s — un repo anidado no se crea solo; moverlo afuera o versionarlo a mano lo elige el operador\n' "${state#inside }"
      return 0
      ;;
    none) git -C "$brain" init -q ;;
  esac
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
    org) os_die "la clave org: no existe desde la spec 052: el espacio de trabajo se declara con workspace:" ;;
    workspace) workspaces="$workspaces$value$nl" ;;
    skipped) skipped="$skipped $value" ;;
    *) os_die "clave desconocida en las respuestas: $key" ;;
  esac
done < "$answers"

[ -n "$name" ] || os_die "falta la clave name: en las respuestas"

# `skipped:` solo nombra preguntas opcionales de la entrevista, y nunca convive con la respuesta que
# dice vacía: las dos cosas juntas son un error de quien escribió el archivo, no un caso a resolver.
os_skipped() {
  case " $skipped " in
    *" $1 "*) return 0 ;;
    *) return 1 ;;
  esac
}
for k in $skipped; do
  case "$k" in
    voice) ;;
    workspace) os_die "skipped: workspace no existe desde la spec 059: la pregunta desapareció de la entrevista entera, así que no hay una respuesta vacía que declarar" ;;
    *) os_die "skipped: solo nombra una pregunta opcional de la entrevista (voice): $k" ;;
  esac
done
if os_skipped voice && [ -n "$voice" ]; then
  os_die "skipped: voice junto con líneas voice: en el mismo archivo — o la voz se declaró vacía, o se contestó"
fi

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
os_lang_load "$language"

# Python 3 es recomendado, no obligatorio (spec 080; reemplaza el requisito duro de la spec 030). Se
# busca por sus tres nombres (`os_python_find`). Sin él el cerebro nace completo y el aviso dice, en el
# idioma del cerebro, qué dos funcionalidades no van a estar. La persona lo ve una sola vez por
# instalación: si el lanzador `npx` ya lo imprimió (antes de que existiera un cerebro, en los dos
# idiomas) dejó `.python-warned` en la raíz del producto instalado, y acá no se repite.
if ! os_python_find && [ ! -f "$here/../../.python-warned" ]; then
  printf '%s\n' "$S_PYTHON_MISSING_WARNING" >&2
fi

templates="$here/../templates"
mkdir -p "$brain"
# Ruta física: sin symlinks adentro (`/var` → `/private/var` en macOS), para que lo que se imprime
# y lo que git nombra sean la misma carpeta. Si el brain es la raíz de su repo lo decide
# `os_brain_repo_state`, no una comparación de rutas.
brain=$(cd "$brain" && pwd -P)

# El bootstrap crea; no rehace. Si las piezas de la raíz ya están, frena: reescribirlas borraría lo
# que el operador haya escrito encima, y eso es pérdida silenciosa. Agregar espacios de trabajo a un
# brain que ya existe es trabajo de new-workspace.
existing=""
for f in "$OS_OPERATOR_FILE" "$OS_VOICE_FILE" "$OS_ROOT_RESOLVER_FILE" "$OS_TREE_FILE" operator.md voice.md resolver.md tree.md; do
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
mkdir -p "$brain/$OS_SYSTEM_DIR" "$brain/$OS_ACCOUNT_DIR/voice"
os_render_lang "$templates/operator.md" "$language" \
  "NAME=$name" "LANGUAGE=$language" "PROFILE=$profile" > "$brain/$OS_OPERATOR_FILE"
# La voz es opcional: sin dato, el archivo lo dice en vez de nacer con una sección en blanco.
voice_body="$voice"
[ -n "$voice_body" ] || voice_body="$S_VOICE_PENDING"
os_render_lang "$templates/voice.md" "$language" \
  "NAME=$name" "VOICE=$voice_body" > "$brain/$OS_VOICE_FILE"
os_render_lang "$templates/root-resolver.md" "$language" > "$brain/$OS_ROOT_RESOLVER_FILE"
# El manual de usuario es del idioma del brain, y su nombre lo enuncia `os_manual_file` una sola vez
# (spec 022). El árbol lo declara como contenido: se ve en la raíz y ningún barrido lo lee como
# trabajo.
os_render "$templates/tree.md" "MANUAL=$OS_MANUAL_LINK" > "$brain/$OS_TREE_FILE"

os_check_identity_cap "$brain/$OS_OPERATOR_FILE"

printf '%s · %s · %s · %s\n' "$OS_OPERATOR_FILE" "$OS_VOICE_FILE" "$OS_ROOT_RESOLVER_FILE" "$OS_TREE_FILE"

# El manual se engancha por symlink al del producto: nace con el brain y se actualiza con el
# producto, sin volver a correr nada.
"$here/manual-link.sh" --brain "$brain" --language "$language" || true

# Lo que la entrevista no trajo se declara. Un hueco silencioso es un hueco que nadie completa.
vacias=""
[ "$sin_language" = "0" ] || vacias="$vacias language"
[ -n "$profile" ] || vacias="$vacias profile"
if [ -z "$voice" ] && ! os_skipped voice; then vacias="$vacias voice"; fi
if [ -n "$vacias" ]; then
  printf 'sin dato:%s — las secciones quedaron vacías y hay que volver a preguntarlas\n' "$vacias"
fi
# Lo que se preguntó y volvió vacío a propósito se declara igual —nada desaparece en silencio— pero
# con otro verbo: no es un hueco que haya que ir a llenar, y el skill no lo vuelve a preguntar.
if [ -n "$skipped" ]; then
  printf 'declarado vacío:%s — se preguntó y la respuesta fue "no tengo" o "después"; no se vuelve a preguntar\n' "$skipped"
fi

# El cerebro nace siempre con un espacio de trabajo (spec 059, decisión 3): la entrevista ya no lo
# pregunta, así que este script lo crea solo primero, con el slug fijo y el nombre visible del
# catálogo — nunca inventado acá. `new-workspace.sh` es el mismo comando que crea cualquier otro
# espacio de trabajo, así que un `workspace:` en las respuestas —para quien lo suma por su cuenta,
# sin pasar por la entrevista— sigue funcionando igual, después de este.
fallidas=""
if ! "$here/new-workspace.sh" --brain "$brain" --name "$S_PERSONAL_WORKSPACE_NAME" --role "" \
     --title "" --owner "$name" --slug "$OS_PERSONAL_WORKSPACE_SLUG"; then
  fallidas="$fallidas $S_PERSONAL_WORKSPACE_NAME"
fi

# Un espacio de trabajo que falla no aborta los demás, y los que no se crearon se nombran.
while IFS= read -r ws; do
  [ -n "$ws" ] || continue
  IFS='|' read -r ws_name ws_title ws_owner ws_identity <<EOF
$ws
EOF
  ws_name=$(os_trim "$ws_name")
  ws_title=$(os_trim "${ws_title:-}")
  ws_owner=$(os_trim "${ws_owner:-}")
  ws_identity=$(os_trim "${ws_identity:-}")
  # El dueño por omisión es el operador: el espacio de trabajo lo crea él.
  [ -n "$ws_owner" ] || ws_owner="$name"
  # El segundo campo es identidad —"qué hacés ahí"—, no activación (spec 020): va al cuerpo vía
  # --title, nunca a --role. `role:` nace vacío; completarlo con el slug de un oficio del pack es
  # un acto aparte, posterior.
  set -- --brain "$brain" --name "$ws_name" --role "" --title "$ws_title" --owner "$ws_owner"
  if [ -n "$ws_identity" ]; then
    set -- "$@" --identity-file "$ws_identity"
  fi
  if ! "$here/new-workspace.sh" "$@"; then
    fallidas="$fallidas $ws_name"
  fi
done <<WORKSPACES
$workspaces
WORKSPACES

# ---------------------------------------------------------------- la mitad local del respaldo
# Corre siempre, sin cuenta ni pregunta (spec 021, decisión 3). Es la única mitad que no depende de
# nada de afuera: el brain nace versionado aunque nunca haya un remoto.
respaldo_local "$brain" "$language"

if [ -n "$fallidas" ]; then
  printf 'sin crear:%s — cada una con su error arriba. El resto del brain quedó escrito.\n' "$fallidas" >&2
  exit 1
fi
