#!/usr/bin/env bash
# Funciones compartidas por los comandos de core/. Interno: no es invocable.
# Bash 3.2 en adelante. Sin dependencias fuera de bash + coreutils, con una excepción: Python 3 (python3)
# —recomendado, no obligatorio desde la spec 080— lo usan `os_settings_authorize`, `mount-repo.sh` y
# `recall.sh`. Se busca con `os_python_find`, por sus tres nombres.

# Tope de identidad, en líneas. Única enunciación del número en el código distribuido.
OS_IDENTITY_CAP=40

# The machinery of the brain's root lives in one hidden folder (spec 076, C7): the tree, the root
# resolver and the mounts table. Only statement of the folder name in the distributed code; every
# reader builds its path from the constants below, never from a path spelled by hand.
OS_SYSTEM_DIR=".system"
OS_TREE_FILE="$OS_SYSTEM_DIR/tree.md"
OS_ROOT_RESOLVER_FILE="$OS_SYSTEM_DIR/resolver.md"

# The two lines of a generated node index that the focus read cuts at (spec 078, C4; spec 079, C4): what is
# between them is the part of the index the AI loads, everything outside is for the person. An index
# written by the spec 078 has only the end line, and the focus then prints from its first line to it. HTML
# comments, so no reader of Markdown shows them. Only statement of the text; `build-indexes.sh` writes them
# and `focus-read.sh` cuts at them.
OS_FOCUS_START='<!-- os:focus-start -->'
OS_FOCUS_END='<!-- os:focus-end -->'

# The account (spec 076, C8): who the operator is and how they write. Visible, edited by the person.
OS_ACCOUNT_DIR="account"
OS_OPERATOR_FILE="$OS_ACCOUNT_DIR/operator.md"
OS_VOICE_FILE="$OS_ACCOUNT_DIR/voice/voice.md"

# Where an installed skill can live (spec 076, C10), in lookup order: the open-standard folder first,
# then Claude Code's. `npx skills add` leaves the skill in the first and a link in the second, so a
# skill present in both counts once (see `os_skill_dirs`).
OS_SKILL_DIRS=".agents/skills .claude/skills"

# Cap, in lines, for each of a workspace's `glossary.md` and `context-map.md` (spec 072): the startup
# read loads them whole, so past this the scan warns. It never truncates. Only statement of the
# number in the distributed code.
OS_GLOSSARY_CAP=100

# Separador de campos de los registros internos: nunca aparece en un archivo del operador.
OS_SEP=$(printf '\037')

# El vocabulario de `status:` es el del esquema de iniciativa. Única enunciación de las dos listas:
# las consumen el arranque de sesión y los barridos globales. Con una lista por lector, la misma
# cabeza queda cerrada para uno y activa para el otro, y el operador ve dos respuestas distintas
# sobre el mismo archivo.
OS_ESTADOS_VALIDOS="active blocked ongoing closed"
OS_ESTADOS_CERRADOS="closed"

# La línea "Cuándo se lee" de un cuerpo (decisión o aprendizaje) sin dato — ni el cierre en vivo ni
# la migración inventan una: la dejan marcada como hueco (spec 043). Una sola enunciación: el cierre
# y `migrate-canonicals.sh` la comparten en vez de llevar cada uno su propio texto.
OS_CUANDO_FALTA='❓ sin definir — no se declaró en el cierre'

# Los archivos propios de un nodo organización, sin la cabeza: las preguntas canónicas del nodo, más
# el backlog. Todo lo demás que un glob alcance adentro de la carpeta de un espacio de trabajo es una
# cabeza de iniciativa. Se enuncia acá una sola vez: los dos lectores —arranque de sesión y barridos
# globales— tienen que contestar lo mismo sobre el mismo archivo, y una tercera copia se
# desincroniza en la primera pregunta canónica que nazca.
#
# La cabeza no está en la lista porque su nombre es dato del brain (spec 040): la suma
# `os_org_propios`, leyéndolo del árbol. Esta lista es además el negativo con el que `os_head_file`
# reconoce la cabeza entre los globs de la altura del espacio de trabajo.
# Since spec 076 a workspace's own files are its head and `.resolver.md`: decisions and learnings are
# folders, and no backlog lives outside an initiative. The names of before stay in the list so a
# brain not migrated yet still tells its head apart from them.
OS_NODE_CANONICOS=".resolver.md resolver.md backlog.md decisions.md learnings.md"

# Los archivos propios de la raíz como nodo, en un brain nacido antes de la spec 059 y todavía sin
# migrar: sus preguntas canónicas, más el backlog. La raíz no tiene cabeza propia —esa identidad es
# `operator.md`, que ya se lee siempre— así que la lista es la de arriba más los archivos que ya
# vivían sueltos en la raíz (`operator.md`, `inbox.md`, `mounts.md`). Desde la spec 059 la raíz solo
# nace con maquinaria: esta lista sigue viva porque `sweep.sh` y `recall.sh --root` siguen leyendo
# trabajo propio de la raíz de un brain viejo — `migrate-root.sh` es lo que lo mueve a
# `workspaces/personal`.
OS_ROOT_PROPIOS="operator.md resolver.md inbox.md mounts.md backlog.md decisions.md learnings.md"

# La etiqueta que agrupa el trabajo propio de la raíz en los barridos globales, sobre un brain
# todavía sin migrar (spec 018, vigente para `sweep.sh` después de la 059). Nunca puede ser un slug
# real: `os_slugify` solo produce alfanumérico en minúscula y guiones, y esta etiqueta lleva
# paréntesis y una tilde.
OS_ROOT_LABEL="(raíz)"

# El slug fijo del espacio de trabajo con el que todo brain nuevo nace (spec 059, decisión 3): nunca
# lo elige el operador ni lo pregunta la entrevista. `bootstrap.sh` lo crea siempre; `migrate-root.sh`
# mueve ahí el trabajo de un brain viejo, creándolo si no existe.
OS_PERSONAL_WORKSPACE_SLUG="personal"

# os_root_gone BRAIN — the answer of a startup tool (`session-start.sh`, `session-read.sh`) asked for
# `--root`, which no longer exists as a scope (spec 059): names the workspaces there are and the
# migration, on stderr, and exits 2 — the same exit as a workspace that does not exist. Written
# once, here, so the two halves of the startup cannot answer differently.
os_root_gone() {
  local brain="$1" slugs
  [ -n "$brain" ] || os_die "falta --brain"
  [ -d "$brain" ] || os_die "no existe el brain: $brain"
  brain=$(cd "$brain" && pwd)
  slugs=$(os_org_slugs "$brain" 2>/dev/null) || slugs=""
  printf 'error: --root ya no existe (spec 059) — el trabajo del operador pasó a un espacio de trabajo. Los que hay:\n' >&2
  if [ -n "$slugs" ]; then
    printf '%s\n' "$slugs" | while IFS= read -r s; do [ -n "$s" ] && printf '  %s\n' "$s" >&2; done
  else
    printf '  (ninguno)\n' >&2
  fi
  printf 'Si el brain todavía tiene trabajo suelto en la raíz, correr .os/core/lib/migrate-root.sh --brain . primero.\n' >&2
  exit 2
}

# os_cerrado ESTADO -> 0 si ese estado saca la cabeza de lo activo.
os_cerrado() {
  local e
  for e in $OS_ESTADOS_CERRADOS; do
    [ "$1" = "$e" ] && return 0
  done
  return 1
}

# os_estado_valido ESTADO -> 0 si el estado está en el vocabulario del esquema.
# Un valor ajeno no se trata como abierto ni como cerrado: se declara. Darlo por abierto deja la
# iniciativa en la lista para siempre; darlo por cerrado la hace desaparecer. Las dos formas son un
# barrido incompleto presentado como completo.
os_estado_valido() {
  local e
  for e in $OS_ESTADOS_VALIDOS; do
    [ "$1" = "$e" ] && return 0
  done
  return 1
}

os_die() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

os_warn() {
  printf 'aviso: %s\n' "$1" >&2
}

# os_deaccent "Ângelo" -> "Angelo"
# Sustitución literal en bash: `tr` trabaja por bytes y partiría al medio un carácter UTF-8, que es
# como un nombre termina perdiendo su primera letra. La tabla cubre las lenguas con las que un
# operador nombra una organización sin traducirla: agudo, grave, diéresis, circunflejo, tilde nasal
# y las vocales nórdicas.
os_deaccent() {
  local s="$1"
  s="${s//á/a}"; s="${s//é/e}"; s="${s//í/i}"; s="${s//ó/o}"; s="${s//ú/u}"
  s="${s//ä/a}"; s="${s//ë/e}"; s="${s//ï/i}"; s="${s//ö/o}"; s="${s//ü/u}"
  s="${s//à/a}"; s="${s//è/e}"; s="${s//ì/i}"; s="${s//ò/o}"; s="${s//ù/u}"
  s="${s//â/a}"; s="${s//ê/e}"; s="${s//î/i}"; s="${s//ô/o}"; s="${s//û/u}"
  s="${s//ã/a}"; s="${s//õ/o}"; s="${s//å/a}"; s="${s//ø/o}"
  s="${s//ñ/n}"; s="${s//ç/c}"
  s="${s//Á/A}"; s="${s//É/E}"; s="${s//Í/I}"; s="${s//Ó/O}"; s="${s//Ú/U}"
  s="${s//Ä/A}"; s="${s//Ë/E}"; s="${s//Ï/I}"; s="${s//Ö/O}"; s="${s//Ü/U}"
  s="${s//À/A}"; s="${s//È/E}"; s="${s//Ì/I}"; s="${s//Ò/O}"; s="${s//Ù/U}"
  s="${s//Â/A}"; s="${s//Ê/E}"; s="${s//Î/I}"; s="${s//Ô/O}"; s="${s//Û/U}"
  s="${s//Ã/A}"; s="${s//Õ/O}"; s="${s//Å/A}"; s="${s//Ø/O}"
  s="${s//Ñ/N}"; s="${s//Ç/C}"
  printf '%s' "$s"
}

# os_slugify "Nombre De La Cosa" -> nombre-de-la-cosa
os_slugify() {
  local s
  s=$(os_deaccent "$1")
  s=$(printf '%s' "$s" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '-')
  while [ "${s#-}" != "$s" ]; do s="${s#-}"; done
  while [ "${s%-}" != "$s" ]; do s="${s%-}"; done
  printf '%s' "$s"
}

# os_slug_cap SLUG MAX -> SLUG cut to at most MAX chars (spec 053: a title long enough to overflow
# the filesystem's own limit lost its file with exit 0). Cuts on a hyphen boundary when the first
# MAX chars contain one, so the name still reads as words; never leaves a trailing hyphen either
# way. A slug already within MAX passes through untouched.
os_slug_cap() {
  local slug="$1" max="$2" cut
  [ "${#slug}" -le "$max" ] && { printf '%s' "$slug"; return; }
  cut="${slug:0:$max}"
  case "$cut" in
    *-*) cut="${cut%-*}" ;;
  esac
  while [ "${cut%-}" != "$cut" ]; do cut="${cut%-}"; done
  printf '%s' "$cut"
}

# os_render TEMPLATE CLAVE=valor ...
# Reemplaza {{CLAVE}} por su valor y escribe el resultado a stdout.
os_render() {
  local tpl="$1"
  shift
  [ -f "$tpl" ] || os_die "falta el template: $tpl"
  local line pair key value
  while IFS= read -r line || [ -n "$line" ]; do
    for pair in "$@"; do
      key="${pair%%=*}"
      value="${pair#*=}"
      line="${line//\{\{$key\}\}/$value}"
    done
    printf '%s\n' "$line"
  done < "$tpl"
}

# ---------------------------------------------------------------- el idioma de lo que se escribe
# Los idiomas que el producto sabe escribir. Única enunciación de la lista.
OS_LANGUAGES="en es"

# La carpeta de esta librería: de acá cuelgan los templates y el catálogo de strings.
OS_LIB_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)
OS_STRINGS_FILE="$OS_LIB_DIR/../templates/strings.md"
# The product version, one plain line `X.Y.Z` in `core/VERSION` (spec 038). Same resolution as the
# strings catalog: relative to this library, never to the caller's cwd.
OS_VERSION_FILE="$OS_LIB_DIR/../VERSION"

# os_version -> the version in `core/VERSION`, empty if the file is not there. An install hooked to
# an older `core/` has no VERSION file: whoever prints it leaves the version out and keeps going.
os_version() {
  local line=""
  [ -f "$OS_VERSION_FILE" ] || return 0
  IFS= read -r line < "$OS_VERSION_FILE" || true
  line="${line%$'\r'}"
  printf '%s' "$(os_trim "$line")"
}

# os_language_valido CODIGO -> 0 si el producto sabe escribir en ese idioma.
os_language_valido() {
  local l
  for l in $OS_LANGUAGES; do
    [ "$1" = "$l" ] && return 0
  done
  return 1
}

# os_language BRAIN -> el idioma declarado en el frontmatter de `operator.md`, o `en`.
# El idioma es dato de la raíz, no de cada comando: `new-workspace` en un brain que ya existe
# escribe en el mismo idioma que el bootstrap eligió, sin volver a preguntarlo.
#
# `en` is the default with no `language:` declared (there is no `operator.md` yet, or the file does
# not carry the key) — silent, because not declaring it is a legitimate choice. A declared
# `language:` the product cannot write (`fr`, `ES`) also falls back to `en`, but warns on stderr:
# falling back in silence would publish English inside a brain that asked for something else
# without anyone noticing — same criterion `os_lang_load` already uses for a key with no
# translation.
os_language() {
  fm_read "$1/$OS_OPERATOR_FILE"
  if [ -n "$fm_language" ] && os_language_valido "$fm_language"; then
    printf '%s' "$fm_language"
  else
    if [ -n "$fm_language" ]; then
      os_warn "$OS_OPERATOR_FILE — language: $fm_language is not supported: falling back to en"
    fi
    printf 'en'
  fi
}

# os_lang_load IDIOMA
# Carga el catálogo `templates/strings.md` en variables `S_<CLAVE>`, y deja las claves leídas en
# `OS_STRING_KEYS`. Una clave sin su línea en el idioma pedido cae a `en` y lo dice por stderr: un
# fallback silencioso publica inglés adentro de un archivo en español sin que nadie se entere.
OS_STRING_KEYS=""
os_lang_load() {
  local lang="$1" file="$OS_STRINGS_FILE" line key code value cur dado k nl
  nl=$(printf '\n.'); nl="${nl%.}"
  [ -f "$file" ] || os_die "falta el catálogo de strings: $file"
  OS_STRING_KEYS=""
  key=""
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      'key: '*)
        key=$(os_trim "${line#key:}")
        OS_STRING_KEYS="$OS_STRING_KEYS $key"
        printf -v "S_${key}_en" '%s' ""
        printf -v "S_${key}_en_dado" '%s' "0"
        printf -v "S_${key}_${lang}" '%s' ""
        printf -v "S_${key}_${lang}_dado" '%s' "0"
        continue
        ;;
    esac
    [ -n "$key" ] || continue
    case "$line" in
      [a-z][a-z]:*|[a-z][a-z]) ;;
      *) continue ;;
    esac
    code="${line%%:*}"
    [ "$code" = "en" ] || [ "$code" = "$lang" ] || continue
    case "$line" in
      "$code:") value="" ;;
      *) value="${line#$code: }" ;;
    esac
    eval "cur=\$S_${key}_${code}; dado=\$S_${key}_${code}_dado"
    if [ "$dado" = "1" ]; then
      printf -v "S_${key}_${code}" '%s' "$cur$nl$value"
    else
      printf -v "S_${key}_${code}" '%s' "$value"
      printf -v "S_${key}_${code}_dado" '%s' "1"
    fi
  done < "$file"

  for k in $OS_STRING_KEYS; do
    eval "dado=\$S_${k}_${lang}_dado; cur=\$S_${k}_${lang}"
    if [ "$dado" = "1" ]; then
      printf -v "S_$k" '%s' "$cur"
    else
      eval "cur=\$S_${k}_en"
      printf -v "S_$k" '%s' "$cur"
      [ "$lang" = "en" ] || os_warn "strings.md — $k no tiene línea en $lang: sale en inglés"
    fi
  done
  return 0
}

# The name of the manual's link at the root of the brain (spec 076, C11): always the same, in every
# language, so the one visible file at the root has one name. The link points at the manual of the
# brain's language (`os_manual_file`). Only statement of the name in the distributed code.
OS_MANUAL_LINK="HOW-IT-WORKS.md"

# os_manual_file IDIOMA -> el nombre del archivo del manual de usuario en ese idioma, dentro de
# `core/manual/` (spec 022). Única enunciación del par idioma → nombre de archivo: lo leen el
# enlazador y los evals. El enlace de la raíz del brain no lleva este nombre sino `OS_MANUAL_LINK`.
os_manual_file() {
  case "$1" in
    es) printf 'COMO-FUNCIONA.md' ;;
    *) printf 'HOW-IT-WORKS.md' ;;
  esac
}

# os_render_lang TEMPLATE IDIOMA CLAVE=valor ...
# Igual que os_render, con las claves del catálogo sumadas como `T_<CLAVE>`. Los templates traen la
# estructura y el catálogo la prosa: el idioma no duplica templates.
os_render_lang() {
  local tpl="$1" lang="$2" k v
  shift 2
  os_lang_load "$lang"
  for k in $OS_STRING_KEYS; do
    eval "v=\$S_$k"
    set -- "$@" "T_$k=$v"
  done
  os_render "$tpl" "$@"
}

# os_check_identity_cap ARCHIVO
# Avisa y no bloquea: la salida —resumir, partir a context/— la elige el operador.
os_check_identity_cap() {
  local file="$1" lines
  lines=$(wc -l < "$file")
  lines=$(printf '%s' "$lines" | tr -d ' ')
  if [ "$lines" -gt "$OS_IDENTITY_CAP" ]; then
    os_warn "$file — identidad $lines/$OS_IDENTITY_CAP · resumir la historia o partir a context/"
  fi
}

# os_trim " texto " -> "texto"
os_trim() {
  local s="$1"
  while [ "${s# }" != "$s" ]; do s="${s# }"; done
  while [ "${s% }" != "$s" ]; do s="${s% }"; done
  printf '%s' "$s"
}

# os_lower "Texto" -> "texto"
os_lower() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

# ---------------------------------------------------------------- frontmatter
# El frontmatter se lee acotado y se exige cerrado. Un `---` de apertura sin su cierre no es
# frontmatter degradado: es un archivo cuyo cuerpo se leería como si fueran claves. Sin cierre
# dentro del tope, lo leído se descarta entero y el archivo se declara como no clasificado.
# Vive acá y no en un barrido: lo leen el arranque de sesión y los barridos globales por igual.
CAP_FRONTMATTER=30

fm_status=""; fm_horizon=""; fm_waiting_on=""; fm_blocked=""; fm_role=""; fm_owner=""
fm_depends_on=""; fm_repo=""; fm_language=""; fm_superseded_by=""; fm_about=""
fm_date=""; fm_key=""; fm_title=""; fm_index_note=""; fm_generated=""
fm_roto=""

fm_limpiar() {
  fm_status=""; fm_horizon=""; fm_waiting_on=""; fm_blocked=""; fm_role=""; fm_owner=""
  fm_depends_on=""; fm_repo=""; fm_language=""; fm_superseded_by=""; fm_about=""
  fm_date=""; fm_key=""; fm_title=""; fm_index_note=""; fm_generated=""
}

# fm_read ARCHIVO — deja el resultado en las variables fm_*. `fm_roto` no vacío significa que no se
# pudo leer, con el motivo adentro: los tres se distinguen porque no son el mismo error.
fm_read() {
  local file="$1" line key value primera=1 cerrado=0 cortado=0 n=0
  fm_limpiar
  fm_roto=""
  [ -f "$file" ] || { fm_roto="sin frontmatter"; return 0; }
  while IFS= read -r line || [ -n "$line" ]; do
    n=$(( n + 1 ))
    if [ "$primera" = "1" ]; then
      primera=0
      if [ "$line" != "---" ]; then fm_roto="sin frontmatter"; return 0; fi
      continue
    fi
    if [ "$line" = "---" ]; then cerrado=1; break; fi
    # Los dos motivos de corte se distinguen: uno es un archivo mal escrito y el otro un frontmatter
    # legítimo que pasó el tope. Llamarlos igual reporta un error que no pasó.
    if [ "$n" -ge "$CAP_FRONTMATTER" ]; then cortado=1; break; fi
    case "$line" in
      *:*) ;;
      *) continue ;;
    esac
    # Trimmed in place, with no subshell: this loop runs once per frontmatter line of every head and
    # every decision the reads walk (spec 076 builds the indexes on each startup read), and a `$(...)`
    # per line was the whole cost. Same rule as `os_trim`: spaces only, both ends.
    key="${line%%:*}"
    while [ "${key# }" != "$key" ]; do key="${key# }"; done
    while [ "${key% }" != "$key" ]; do key="${key% }"; done
    value="${line#*:}"
    while [ "${value# }" != "$value" ]; do value="${value# }"; done
    while [ "${value% }" != "$value" ]; do value="${value% }"; done
    case "$key" in
      status) fm_status="$value" ;;
      horizon) fm_horizon="$value" ;;
      waiting_on) fm_waiting_on="$value" ;;
      blocked) fm_blocked="$value" ;;
      role) fm_role="$value" ;;
      owner) fm_owner="$value" ;;
      depends_on) fm_depends_on="$value" ;;
      repo) fm_repo="$value" ;;
      language) fm_language="$value" ;;
      # `superseded_by:` (spec 046) — the path, relative to the brain, of the file that replaced
      # this one. It reaches this reader like every other key, with the same bound and the same
      # three failure values: a file whose frontmatter cannot be read has no vigency mark either,
      # and saying it does would be inventing one. Any file can carry it — a head that a `glob:`
      # reaches and a content file that only a `content:` reaches — because the reader at risk is
      # whoever opened the file, not whoever walked the tree.
      superseded_by) fm_superseded_by="$value" ;;
      # `about:` (spec 049) — the path, relative to the brain, of the head this node is about, or a
      # list of them on one line (spec 076, C16: `os_about_values` splits it). Kept raw here. A
      # decision or a learning carries it too (spec 076, C17): the scan never opens those, the index
      # generator and the focus's key decisions do.
      # `about: []` names nothing: the same as no `about:` at all, for every reader (spec 076, C16).
      about) case "$value" in '['*']') [ -n "$(printf '%s' "${value#\[}" | tr -d ' ]')" ] || value="" ;; esac
             fm_about="$value" ;;
      # The keys of the generated indexes (spec 076, C18): `date:` and `key:` of a decision or a
      # learning, `title:` when the link text differs from the body's `# Title`, `index_note:` the
      # tail of its index line, and `generated:` on every file a script writes so the AI and the
      # generator never mistake it for one a person wrote.
      date) fm_date="$value" ;;
      key) fm_key="$value" ;;
      title) fm_title="$value" ;;
      index_note) fm_index_note="$value" ;;
      generated) fm_generated="$value" ;;
    esac
  done < "$file"
  if [ "$primera" = "1" ]; then fm_roto="sin frontmatter"; return 0; fi
  if [ "$cerrado" = "0" ]; then
    fm_limpiar
    if [ "$cortado" = "1" ]; then
      fm_roto="frontmatter demasiado largo"
    else
      fm_roto="frontmatter sin cerrar"
    fi
  fi
  return 0
}

# ---------------------------------------------------------------- el árbol se lee, no se infiere
# os_tree_files BRAIN -> las rutas que alcanzan los globs declarados, una por línea, relativas al
# brain. Exit 1 si no hay declaración: quien llama decide qué decir.
# Ningún barrido descubre el árbol ni asume profundidad. Agregar una altura es agregar una línea
# en `tree.md`, no tocar un script.
os_tree_files() {
  local brain="$1" line g
  [ -f "$brain/$OS_TREE_FILE" ] || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      glob:*) ;;
      *) continue ;;
    esac
    g=$(os_trim "${line#glob:}")
    [ -n "$g" ] || continue
    ( cd "$brain" && for f in $g; do [ -e "$f" ] && printf '%s\n' "$f"; done )
  done < "$brain/$OS_TREE_FILE"
  return 0
}

# os_tree_content_files BRAIN -> las rutas que alcanzan las líneas `content:` declaradas, una por
# línea, relativas al brain. Exit 1 si no hay declaración: quien llama decide qué decir.
#
# Segunda clase de línea del mismo árbol (spec 007): lo que un `content:` alcanza cuenta como
# alcanzado —nunca aparece en "ningún glob de tree.md alcanza"— pero nunca se lee como cabeza. Por
# eso vive en un lector aparte de `os_tree_files` en vez de sumar una columna al mismo: el llamador
# que arma cabezas sigue leyendo solo `glob:`, y el que audita alcance lee las dos clases. Una
# segunda copia del parser de `tree.md` en session-start.sh o sweep.sh sería la desincronización que
# este repo ya prohíbe — por eso el lector queda acá, el único lugar que lee el formato.
os_tree_content_files() {
  local brain="$1" line g
  [ -f "$brain/$OS_TREE_FILE" ] || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      content:*) ;;
      *) continue ;;
    esac
    g=$(os_trim "${line#content:}")
    [ -n "$g" ] || continue
    ( cd "$brain" && for f in $g; do [ -e "$f" ] && printf '%s\n' "$f"; done )
  done < "$brain/$OS_TREE_FILE"
  return 0
}

# os_tree_archive_files BRAIN -> the paths the declared `archive:` lines reach, one per line,
# relative to the brain. Exit 1 if there is no declaration: the caller decides what to say.
#
# Third class of line of the same tree (spec 048). What an `archive:` line reaches is **reached** —
# it never shows up as "no glob of tree.md reaches it" — is never read as a head, and, unlike the
# `content:` class, is never **loaded** either: the focus prints its name and stops there. That is
# the whole point of the class, and it is why it is a third reader instead of a flag on the second
# one: a caller that loads bodies reads `content:` and stops, and cannot pick up archived files by
# forgetting to filter them out. The only file that parses `tree.md` is still this one.
os_tree_archive_files() {
  local brain="$1" line g
  [ -f "$brain/$OS_TREE_FILE" ] || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      archive:*) ;;
      *) continue ;;
    esac
    g=$(os_trim "${line#archive:}")
    [ -n "$g" ] || continue
    ( cd "$brain" && for f in $g; do [ -e "$f" ] && printf '%s\n' "$f"; done )
  done < "$brain/$OS_TREE_FILE"
  return 0
}

# ---------------------------------------------------------------- rutas relativas al brain
# Las tres funciones de acá abajo nacieron adentro de `supersede.sh` (spec 047) y viven ahora en el
# único lugar que lee el formato del brain: desde la spec 049 hay un segundo comando que valida una
# ruta escrita a mano en un frontmatter, y una segunda copia de estas comparaciones sería la
# desincronización que este repo ya prohíbe. Al mudarlas se corrigió un defecto: bajo bash 3.2 el
# reemplazo escrito `\/` adentro de `${p//\/\//\/}` aterriza en el valor, así que `d//a.md` salía
# `d\/a.md` y toda comparación de rutas contestaba sobre un archivo que no existe.

# os_rel_ok RUTA -> 0 si es una ruta relativa al brain: ni absoluta, ni con `..`, ni vacía.
# Toda ruta del sistema es relativa al brain (`core/CLAUDE.md`): una absoluta funciona en una sola
# máquina y un `..` sale del árbol que el brain gobierna.
os_rel_ok() {
  case "$1" in
    /*) return 1 ;;
    ../*|*/../*|*/..|..) return 1 ;;
    "") return 1 ;;
  esac
  return 0
}

# os_rel_norm RUTA -> la misma ruta escrita de la única forma con la que se compara: sin `./` al
# principio, sin `//`, sin `/./`, sin `/` al final. Sin esto `d/a.md`, `./d/a.md` y `d//a.md` son
# tres cadenas distintas para el mismo archivo, y toda comparación de ruta del sistema es una
# comparación de cadenas.
os_rel_norm() {
  local p="$1" prev=""
  while [ "$p" != "$prev" ]; do
    prev="$p"
    p="${p#./}"
    p="${p//\/\///}"
    p="${p//\/.\///}"
    p="${p%/.}"
    p="${p%/}"
  done
  printf '%s' "$p"
}

# os_inside_brain BRAIN RUTA -> 0 si la ruta, resuelta a través de los enlaces que tengan sus
# directorios, sigue cayendo adentro del brain. `os_rel_ok` es texto y un directorio enlazado no lo
# es: sin esta, una ruta escrita a través de `enlace/x.md` nombra un archivo que ningún brain
# gobierna.
os_inside_brain() {
  local brain="$1" rel="$2" dir real brain_real
  brain_real=$(cd "$brain" 2>/dev/null && pwd -P) || return 1
  dir=$(dirname "$brain/$rel")
  real=$(cd "$dir" 2>/dev/null && pwd -P) || return 1
  case "$real" in
    "$brain_real"|"$brain_real"/*) return 0 ;;
  esac
  return 1
}

# ---------------------------------------------------------------- tipos de nodo de memoria (spec 041)
# La carpeta es el tipo (spec 041): no hay campo `type:` en ningún frontmatter, así que el único
# lugar donde el nombre de un tipo existe es el segmento de ruta entre el árbol y `/*/`. `products/`
# fue el primer tipo, y ya no está escrito a mano en ningún lector: session-start.sh y sweep.sh piden
# la lista de tipos declarados en vez de nombrar `products` — así cualquier carpeta de nodos de
# memoria que se declare en `tree.md` (accounts/, channels/, la que invente el operador) funciona
# igual, sin tocar un script.

# os_memory_types BRAIN SCOPE -> los nombres de tipo declarados en tree.md para ese ámbito, uno por
# línea. SCOPE es "org" (altura `<wsdir>/*/<tipo>/*/...`) o "root" (altura `<tipo>/*/...`, sin
# prefijo de espacio de trabajo). Un tipo se reconoce por su glob de cabeza a esa altura
# (`<prefijo><tipo>/*/<cabeza>`) — nunca por sus 5 líneas completas: un tipo creado a mano antes de
# que existiera `new-memory` puede tener declarada solo esa línea, no las 5, y esta spec tiene que
# dejarlo contando igual, sin migrar nada (evidencia real: el eval de campo de esta spec, sobre un
# brain con tipos creados a mano). Se excluyen por nombre los dos canónicos que matchean la misma
# forma sin ser un tipo: `initiatives` (cabeza de iniciativa, en las dos alturas) y, en la raíz, el
# propio `$wsdir` (cabeza del nodo organización). Cualquier otra colisión de nombre es la que la spec
# deja como condición de parada para el operador, no algo que este lector adivine. Toda comparación
# de ruta es literal (parámetros citados): un prefijo con `*` adentro (`workspaces/*/`) nunca se
# interpreta como patrón de shell.
os_memory_types() {
  local brain="$1" scope="$2" wsdir head prefix line g rest tipo resto2 types nl
  nl=$(printf '\nx'); nl="${nl%x}"
  [ -f "$brain/$OS_TREE_FILE" ] || return 1
  wsdir=$(os_ws_dir "$brain")
  head=$(os_head_file "$brain") || true
  if [ "$scope" = "root" ]; then prefix=""; else prefix="$wsdir/*/"; fi
  types=""
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      glob:*) ;;
      *) continue ;;
    esac
    g=$(os_trim "${line#glob:}")
    if [ -n "$prefix" ]; then
      [ "${g#"$prefix"}" != "$g" ] || continue
    fi
    rest="${g#"$prefix"}"
    tipo="${rest%%/*}"
    [ -n "$tipo" ] && [ "$tipo" != "$rest" ] || continue
    [ "$tipo" = "initiatives" ] && continue
    [ "$scope" = "root" ] && [ "$tipo" = "$wsdir" ] && continue
    resto2="${rest#"$tipo"/}"
    [ "$resto2" = "*/$head" ] || continue
    case "$nl$types" in *"$nl$tipo$nl"*) continue ;; esac
    types="$types$tipo$nl"
  done < "$brain/$OS_TREE_FILE"
  printf '%s' "$types"
  return 0
}

# os_memory_own_file WSDIR HEAD TYPES_ORG TYPES_ROOT F -> 0 si F (relativo al brain) es la cabeza,
# `resolver.md` o `decisions.md` de un nodo de memoria de cualquier tipo declarado — nunca su
# `context/` ni su `research/`, que son `content:` y nunca llegan a esta pregunta. TYPES_ORG y
# TYPES_ROOT son la salida de `os_memory_types` para los ámbitos "org" y "root", calculada una sola
# vez por corrida y pasada acá, no releída por archivo.
os_memory_own_file() {
  local wsdir="$1" head="$2" types_org="$3" types_root="$4" f="$5" t
  for t in $types_org; do
    case "$f" in
      "$wsdir"/*/"$t"/*/"$head"|"$wsdir"/*/"$t"/*/.resolver.md|"$wsdir"/*/"$t"/*/resolver.md|"$wsdir"/*/"$t"/*/decisions.md)
        return 0 ;;
    esac
  done
  for t in $types_root; do
    case "$f" in
      "$t"/*/"$head"|"$t"/*/.resolver.md|"$t"/*/resolver.md|"$t"/*/decisions.md) return 0 ;;
    esac
  done
  return 1
}

# ---------------------------------------------------------------- qué es una cabeza, por su ruta (spec 056)
# os_head_kind WSDIR HEAD F -> clasifica F (una cabeza ya resuelta por un `glob:` del árbol) por su
# segmento de ruta, sin abrir ningún archivo: imprime "<kind> <scope>" en una línea. `kind` es
# `root`, `workspace`, `initiative`, `entity` u `other`; `scope` es el slug del espacio de trabajo
# en el que vive F, vacío cuando F es de la raíz. Las cuatro entidades son fijas —`products`,
# `accounts`, `channels`, `courses`— por criterio delegado de la spec: no se reutiliza
# `os_memory_types` porque esa lista es abierta (cualquier carpeta que el operador declare) y acá el
# modelo de nodos solo reconoce esas cuatro.
os_head_kind() {
  local wsdir="$1" head="$2" f="$3" ws inner mid tipo

  if [ "$f" = "$OS_OPERATOR_FILE" ]; then printf 'root'; return 0; fi

  case "$f" in
    "$wsdir"/*)
      ws="${f#"$wsdir"/}"; ws="${ws%%/*}"
      inner="${f#"$wsdir"/"$ws"/}"
      ;;
    *)
      ws=""
      inner="$f"
      ;;
  esac

  if [ -n "$ws" ] && [ "$inner" = "$head" ]; then
    printf 'workspace %s' "$ws"
    return 0
  fi

  # La forma de la cabeza (spec 040) trata a las iniciativas distinto del resto: la forma anterior
  # (`legacy`) las guarda como archivo suelto —`initiatives/<slug>.md`, sin carpeta ni el nombre de
  # `head`— mientras que products/accounts/channels/courses conservan la carpeta más el archivo de
  # cabeza en las dos formas. Las dos formas de iniciativa se prueban acá, nunca una sola: un brain
  # a medio migrar tiene las dos a la vez (`os_head_file` ya contempla ese caso mixto).
  case "$inner" in
    initiatives/*/"$head")
      mid="${inner#initiatives/}"; mid="${mid%/"$head"}"
      case "$mid" in
        */*) ;;
        *) printf 'initiative %s' "$ws"; return 0 ;;
      esac
      ;;
    initiatives/*.md)
      mid="${inner#initiatives/}"
      case "$mid" in
        */*) ;;
        *) printf 'initiative %s' "$ws"; return 0 ;;
      esac
      ;;
  esac

  for tipo in products accounts channels courses; do
    case "$inner" in
      "$tipo"/*/"$head")
        mid="${inner#"$tipo"/}"; mid="${mid%/"$head"}"
        case "$mid" in
          */*) ;;
          *) printf 'entity %s' "$ws"; return 0 ;;
        esac
        ;;
    esac
  done

  printf 'other'
}

# os_tree_ensure BRAIN GLOB [CLASE]
# Deja declarado el glob en `tree.md` si faltaba. Es la contracara de que los archivos de solo
# contenido nazcan con su primer dato: el archivo aparece y ningún glob lo alcanza hasta que el
# comando que lo creó declara su altura. Los globs los mantienen los comandos que crean niveles; la
# única excepción es la lectura de arranque, para el glosario y el mapa de contextos de un espacio
# de trabajo escritos a mano (spec 072, `session-read.sh`).
# CLASE es `glob` (default, una cabeza) o `content` (alcanzado, nunca leído como cabeza — spec 007).
# El manual de usuario entra por `content` (spec 022): se ve en la raíz y no es trabajo.
#   0  lo agregó       1  ya estaba       2  no hay tree.md que mantener
# os_tree_line LINE -> "<class><TAB><pattern>" when LINE is a declaration of tree.md (glob, content or
# archive); 1 otherwise. The one place outside the readers above that knows the three prefixes — a
# caller that rewrites tree.md line by line (migrate-root.sh) asks here instead of parsing them.
os_tree_line() {
  case "$1" in
    glob:*|content:*|archive:*) printf '%s\t%s' "${1%%:*}" "$(os_trim "${1#*:}")"; return 0 ;;
  esac
  return 1
}

os_tree_ensure() {
  local brain="$1" glob="$2" clase="${3:-glob}" line g
  [ -f "$brain/$OS_TREE_FILE" ] || return 2
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      "$clase":*) ;;
      *) continue ;;
    esac
    g=$(os_trim "${line#$clase:}")
    [ "$g" = "$glob" ] && return 1
  done < "$brain/$OS_TREE_FILE"
  # A tree.md edited by hand can end without a newline: the new line would glue onto the last one
  # and corrupt that declaration (Codex review of spec 072, finding 1).
  if [ -s "$brain/$OS_TREE_FILE" ] && [ -n "$(tail -c 1 "$brain/$OS_TREE_FILE")" ]; then
    printf '\n' >> "$brain/$OS_TREE_FILE"
  fi
  printf '%s: %s\n' "$clase" "$glob" >> "$brain/$OS_TREE_FILE"
  return 0
}

# ---------------------------------------------------------------- one file per decision, per learning (spec 043)
# `decisions/<YYYY-MM-DD>-<slug>.md` and `learnings/<slug>.md` — the body, one per fact — with
# `decisions.md`/`learnings.md` left as the index (unchanged name, unchanged place, unchanged
# `OS_NODE_CANONICOS`). Both `close-session.sh` (the live writer) and `migrate-canonicals.sh` (the
# one-time split of what already exists) call these, so the file name a fact gets and the line its
# index carries are the same lookup either way — a second copy of either would desync the day one
# of the two callers changes.

# os_decision_path BRAIN PREFIX DATE TITLE -> a free path for a decision's body, relative to the
# node (PREFIX already applied, so the caller joins it as "$brain/$PREFIX$path"). A same-date
# collision on the slug is resolved with -2, -3…, never by silently overwriting (spec's own
# criterion for the slug).
os_decision_path() {
  local brain="$1" prefix="$2" date="$3" title="$4" slug base rel n=1
  slug=$(os_slugify "$title")
  [ -n "$slug" ] || slug="sin-titulo"
  slug=$(os_slug_cap "$slug" 80)
  base="decisions/${date}-${slug}"
  rel="${base}.md"
  while [ -e "$brain/${prefix}${rel}" ]; do
    n=$((n + 1))
    rel="${base}-${n}.md"
  done
  printf '%s' "$rel"
}

# os_learning_path BRAIN PREFIX TITLE -> the path for a learning's body, relative to the node. No
# date in the name (spec's own criterion: a learning that gets updated does not change its
# identity), so the same title always resolves to the same file — exit 0 when that file already
# existed (the caller's cue to update in place instead of writing a fresh header), 1 when it is new.
#
# A file is the same learning only if its own title (`title:`, or else its `# Title`) slugifies to the
# same slug as TITLE: two different titles that land on one name (`Index`, which never takes `index.md`,
# and `Index 1`) never share a file. The next free name is `<name>-2`, `<name>-3`, and so on, and a
# file there is the same learning by the same test.
os_learning_path() {
  local brain="$1" prefix="$2" title="$3" slug want first cand n rel stored
  slug=$(os_slugify "$title")
  [ -n "$slug" ] || slug="sin-titulo"
  slug=$(os_slug_cap "$slug" 80)
  want="$slug"
  first="$slug"
  # `index.md` is the generated index of the folder (spec 076, C18): a learning never takes that name.
  [ "$first" = "index" ] && first="index-1"
  cand="$first"
  n=1
  while :; do
    rel="learnings/${cand}.md"
    if [ ! -f "$brain/${prefix}${rel}" ]; then
      printf '%s' "$rel"
      return 1
    fi
    fm_read "$brain/${prefix}${rel}"
    stored="$fm_title"
    [ -n "$stored" ] || stored=$(os_titulo "$brain/${prefix}${rel}")
    stored=$(os_slugify "$stored")
    [ -n "$stored" ] || stored="sin-titulo"
    if [ "$(os_slug_cap "$stored" 80)" = "$want" ]; then
      printf '%s' "$rel"
      return 0
    fi
    n=$(( n + 1 ))
    cand="$first-$n"
  done
}

# os_index_line DATE TITLE REL WHEN -> the one line an index (`decisions.md`/`learnings.md`) carries
# per body (C3): date, title linking to the body, and the body's own "when it is read" line, which
# is what makes the index worth reading instead of a table of contents (C4).
#
# A fifth argument "key" (spec 069) marks the decision as a key one: `clave · ` goes between the date
# and the title. Without it the line is exactly the one above. The label is a literal, like the
# "Cuándo se lee" label of the body of a learning: it does not come from the strings catalog.
#
# An empty WHEN (spec 070) leaves the tail out: `- DATE · [clave · ][TITLE](REL)`. That is the line of
# a decision written in MADR, which has no "when it is read" field; the learnings and the migration
# of old decisions always pass one.
os_index_line() {
  local tail=""
  [ -z "$4" ] || tail=" — $4"
  if [ "${5:-}" = "key" ]; then
    printf -- '- %s · clave · [%s](%s)%s\n' "$1" "$2" "$3" "$tail"
  else
    printf -- '- %s · [%s](%s)%s\n' "$1" "$2" "$3" "$tail"
  fi
}

# os_index_link_of INDEXFILE TITLE -> prints the link target of the first index line whose link text
# is TITLE (relative to the node, as the index carries it). Exit 1 when there is none. Same match
# rule as `os_index_mark_superseded`, so both point at the same line.
os_index_link_of() {
  local idx="$1" title="$2" line link
  [ -f "$idx" ] || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      "- "*"[$title]("*)
        link="${line#*"[$title]("}"
        link="${link%%)*}"
        printf '%s' "$link"
        return 0
        ;;
    esac
  done < "$idx"
  return 1
}

# os_decision_mark_superseded BRAIN OLD_REL NEW_REL -> marks a replaced decision in its front matter
# (spec 070): the replacement mark the session contract follows is written by `supersede.sh`, its
# single writer (spec 046), and then MADR's own `status: superseded by NEW` is set next to it. Both
# happen in this one call. `supersede.sh` creates a front matter above a headerless body and refuses
# one it cannot read; the content of the old decision is never rewritten. Exit 1 if either write fails.
os_decision_mark_superseded() {
  local brain="$1" old="$2" new="$3"
  [ -f "$brain/$old" ] || return 1
  "$OS_LIB_DIR/supersede.sh" --brain "$brain" --file "$old" --by "$new" > /dev/null 2>&1 || return 1
  os_fm_set "$brain/$old" status "superseded by $new" || return 1
  return 0
}

# os_key_decision_lines INDEXFILE -> prints, as they are, the lines of an index that are marked as
# key (`- DATE · clave · [..`) and not superseded (no `**reemplazada por**` mark). Nothing for a file
# that is not there or has none. Single reader of the mark (spec 069): both startup reads use it.
os_key_decision_lines() {
  [ -f "$1" ] || return 0
  grep -E '^- [0-9]{4}-[0-9]{2}-[0-9]{2} · clave · \[' "$1" | grep -vF '**reemplazada por**' || true
}

# os_index_mark_superseded INDEXFILE OLD_TITLE NEW_TITLE NEW_REL -> rewrites, in place, the single
# index line whose link text is OLD_TITLE, appending the supersession mark (C5: the mark lives on
# the index line, never on the superseded body — `diff` on that body stays empty). Copied line by
# line to a temp file and moved back: never a whole-file regen, so a line the operator edited by
# hand elsewhere survives untouched. Only the first match is marked, in case two decisions ever
# share a title.
os_index_mark_superseded() {
  local idx="$1" old="$2" new="$3" rel="$4" tmp line marker found=0
  [ -f "$idx" ] || return 1
  tmp="$idx.os-tmp"
  marker=" — **reemplazada por**: [${new}](${rel})"
  : > "$tmp"
  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$found" = "0" ]; then
      case "$line" in
        "- "*"[$old]("*)
          line="${line}${marker}"
          found=1
          ;;
      esac
    fi
    printf '%s\n' "$line" >> "$tmp"
  done < "$idx"
  mv "$tmp" "$idx"
  [ "$found" = "1" ]
}

# ---------------------------------------------------------------- `about:` names one node or several (spec 076, C16)
# `about: <path>` names one head; `about: [<path>, <path>]` names several, on a single line, in the
# order they are read. The key stays optional. These two are the only readers of the list form: the
# scan validates each value, the focus jumps once per value, the index generator files a document
# under each node it names and `close-session` copies the focus's value as it is.

# os_about_values VALUE -> each path the value names, one per line, in order, trimmed. `[]` names
# none. An empty item between two commas is printed as an empty line, so a caller that validates
# reports it instead of skipping it.
os_about_values() {
  local v="$1" item rest
  case "$v" in
    '['*']')
      rest="${v#\[}"
      rest="${rest%\]}"
      while [ "${rest# }" != "$rest" ]; do rest="${rest# }"; done
      while [ "${rest% }" != "$rest" ]; do rest="${rest% }"; done
      [ -n "$rest" ] || return 0
      while :; do
        case "$rest" in
          *,*) item="${rest%%,*}"; rest="${rest#*,}" ;;
          *) item="$rest"; rest="" ;;
        esac
        while [ "${item# }" != "$item" ]; do item="${item# }"; done
        while [ "${item% }" != "$item" ]; do item="${item% }"; done
        printf '%s\n' "$(os_unquote "$item")"
        [ -n "$rest" ] || break
      done
      ;;
    '') return 0 ;;
    *) printf '%s\n' "$(os_unquote "$v")" ;;
  esac
  return 0
}

# os_unquote VALUE -> VALUE without one pair of matching surrounding quotes (`"x"` or `'x'`), the
# way YAML reads a quoted scalar. The layout migration (`migrate_layout.py`, `unquote`) reads `about:`
# with the same rule, so both recognise the same standing initiative of a node.
os_unquote() {
  local v="$1"
  case "$v" in
    \"*\") [ "${#v}" -ge 2 ] && v="${v#\"}" && v="${v%\"}" ;;
    \'*\') [ "${#v}" -ge 2 ] && v="${v#\'}" && v="${v%\'}" ;;
  esac
  printf '%s' "$v"
}

# os_about_names VALUE HEAD -> 0 if one of the paths VALUE names, normalised, is HEAD.
os_about_names() {
  local v
  while IFS= read -r v || [ -n "$v" ]; do
    [ -n "$v" ] || continue
    [ "$(os_rel_norm "$v")" = "$2" ] && return 0
  done <<VALUES
$(os_about_values "$1")
VALUES
  return 1
}

# os_about_set VALUE -> the paths VALUE names, normalised, as one string with a newline before and
# after each one: a caller that tests membership many times builds it once and matches it with
# `case "$set" in *"<newline>$head<newline>"*)`, no subshell per test. Empty for no value.
os_about_set() {
  local v out=""
  while IFS= read -r v || [ -n "$v" ]; do
    [ -n "$v" ] || continue
    out="$out
$(os_rel_norm "$v")"
  done <<VALUES
$(os_about_values "$1")
VALUES
  [ -n "$out" ] && printf '%s\n' "$out"
  return 0
}

# os_about_is_single VALUE HEAD -> 0 if VALUE names HEAD and nothing else: the shape of the standing
# initiative of a node (spec 076, C30), as opposed to an initiative that is about several nodes.
os_about_is_single() {
  local n=0 v hit=0
  while IFS= read -r v || [ -n "$v" ]; do
    [ -n "$v" ] || continue
    n=$(( n + 1 ))
    [ "$(os_rel_norm "$v")" = "$2" ] && hit=1
  done <<VALUES
$(os_about_values "$1")
VALUES
  [ "$n" = "1" ] && [ "$hit" = "1" ]
}

# ---------------------------------------------------------------- relative links (spec 076, C18)
# os_rel_link FROM_DIR TO -> TO written relative to FROM_DIR. Both are relative to the brain; FROM_DIR
# has no trailing slash and is empty for the brain itself. This is what makes a generated index open
# its lines with one click from Obsidian and from GitHub.
os_rel_link() {
  local from="$1" to="$2" up=""
  while [ -n "$from" ]; do
    case "$to" in
      "$from"/*) printf '%s%s' "$up" "${to#"$from"/}"; return 0 ;;
    esac
    up="../$up"
    case "$from" in
      */*) from="${from%/*}" ;;
      *) from="" ;;
    esac
  done
  printf '%s%s' "$up" "$to"
}

# ---------------------------------------------------------------- the index line of a decision or a learning (spec 076, C18)
# Decisions and learnings live flat in the workspace (`decisions/`, `learnings/`), one file each, and
# every index that lists them is generated from their frontmatter — never from a hand-kept index.
# The line is the one the hand-kept index carried (spec 043, 069): date, the key label, the title as
# a link, the tail, and the replacement mark at the end:
#
#   - DATE · <key label> · [TITLE](LINK) — <index_note> — **<superseded label>**: [NEW](LINK)
#
# `date:` gives the date; `title:`, else the body's first `# Title`, else the file name, gives the
# title; `key:` with any value but `false` gives the key label; `superseded_by:` gives the mark, with
# the title of the file it names; `index_note:` gives the tail. The two labels come from the strings
# catalog, so the caller has the catalog loaded.

# os_doc_is_key VALUE -> 0 if a `key:` value marks the document as key. The decisions of spec 069
# carry the reason as free text in the key; the migration writes `true`.
os_doc_is_key() {
  case "$1" in
    ''|false|no) return 1 ;;
  esac
  return 0
}

# os_doc_title FILE -> the title an index shows for it: `title:`, the first `# Title`, or the name.
# Reads the frontmatter itself: the caller's `fm_*` are overwritten.
os_doc_title() {
  local t base
  fm_read "$1"
  t="$fm_title"
  [ -n "$t" ] || t=$(os_titulo "$1")
  if [ -z "$t" ]; then
    base="${1##*/}"
    t="${base%.md}"
  fi
  printf '%s' "$t"
}

# md_cell TEXT -> the text safe inside a table cell or a link label: backslash, `|`, `[` and `]` escaped.
md_cell() {
  local t="$1"
  t="${t//\\/\\\\}"
  t="${t//|/\\|}"
  t="${t//[/\\[}"
  t="${t//]/\\]}"
  printf '%s' "$t"
}

# md_dest PATH -> the path as a link destination: `%`, `&`, `\`, tab, space, parentheses, `|`, `<`, `>`, `#` and `?`
# encoded, and `./` before a first segment with a colon. The one place that knows it (spec 078, C6): every generated index line goes through it.
md_dest() {
  local t="$1"
  t="${t//%/%25}"
  t="${t//&/%26}"
  t="${t//\\/%5C}"
  t="${t//$'\t'/%09}"
  t="${t// /%20}"
  t="${t//(/%28}"
  t="${t//)/%29}"
  t="${t//|/%7C}"
  t="${t//</%3C}"
  t="${t//>/%3E}"
  t="${t//#/%23}"
  t="${t//\?/%3F}"
  # A first segment with a colon would read as a URI scheme: `./` keeps it a relative path.
  case "${t%%/*}" in *:*) t="./$t" ;; esac
  printf '%s' "$t"
}

# os_doc_index_line BRAIN REL FROM_DIR -> the index line of the document at REL (relative to the
# brain), with its links relative to FROM_DIR. Exit 1 when the file is not there.
os_doc_index_line() {
  local brain="$1" rel="$2" from="$3" date key title note sup line sup_title
  [ -f "$brain/$rel" ] || return 1
  title=$(os_doc_title "$brain/$rel")
  fm_read "$brain/$rel"
  date="$fm_date"; key="$fm_key"; note="$fm_index_note"; sup=$(os_rel_norm "$fm_superseded_by")
  line="-"
  [ -n "$date" ] && line="$line $date ·"
  os_doc_is_key "$key" && line="$line $S_INDEX_KEY_LABEL ·"
  line="$line [$(md_cell "$title")]($(md_dest "$(os_rel_link "$from" "$rel")"))"
  [ -n "$note" ] && line="$line — $note"
  if [ -n "$sup" ]; then
    if [ -f "$brain/$sup" ]; then sup_title=$(os_doc_title "$brain/$sup"); else sup_title="${sup##*/}"; fi
    line="$line — **$S_INDEX_SUPERSEDED_LABEL**: [$(md_cell "$sup_title")]($(md_dest "$(os_rel_link "$from" "$sup")"))"
  fi
  printf '%s' "$line"
  return 0
}

# os_doc_superseded -> 0 if the document `fm_read` just read is replaced: `superseded_by:` (spec 046)
# or MADR's `status: superseded by ...` (spec 070), which `os_decision_mark_superseded` writes together.
os_doc_superseded() {
  [ -n "$fm_superseded_by" ] && return 0
  case "$fm_status" in superseded*) return 0 ;; esac
  return 1
}

# os_doc_superseded_path -> the normalised path of the file that replaced the document `fm_read` just read, or
# nothing (the one place outside the writer that reads the key for an index).
os_doc_superseded_path() {
  case "$fm_superseded_by" in
    '') ;;
    *) os_rel_norm "$fm_superseded_by"; return 0 ;;
  esac
  # MADR's own form, `status: superseded by <path>` (spec 070), when the key is not there.
  case "$fm_status" in
    "superseded by "*) os_rel_norm "$(os_trim "${fm_status#superseded by }")" ;;
  esac
}

# os_docs_sorted BRAIN DIR_REL -> the `.md` files of that folder (never its generated `index.md`),
# relative to the brain, newest `date:` first; same date, by path. An undated file goes last.
os_docs_sorted() {
  local brain="$1" dir="$2" f rel tab
  tab=$(printf '\tx'); tab="${tab%x}"
  [ -d "$brain/$dir" ] || return 0
  for f in "$brain/$dir"/*.md; do
    [ -f "$f" ] || continue
    rel="${f#"$brain"/}"
    [ "${rel##*/}" = "index.md" ] && continue
    fm_read "$f"
    printf '%s\t%s\n' "${fm_date:-0000-00-00}" "$rel"
  done | LC_ALL=C sort -t "$tab" -k1,1r -k2,2 | while IFS="$tab" read -r _d rel; do
    printf '%s\n' "$rel"
  done
}

# os_key_decisions BRAIN WS_REL [NODE_HEAD] -> the key decisions of a workspace (spec 076, C19), one
# index line each, links relative to its `decisions/`, newest first. Without NODE_HEAD: the key ones,
# not replaced, with no `about:` — what the startup read loads. With it: the key ones, not replaced,
# whose `about:` names that head — what the focus loads for that node. Read from the frontmatter of
# each decision, never from an index. Nothing for a workspace without any.
os_key_decisions() {
  local brain="$1" ws="$2" node="${3:-}" rel
  while IFS= read -r rel || [ -n "$rel" ]; do
    [ -n "$rel" ] || continue
    fm_read "$brain/$rel"
    [ -z "$fm_roto" ] || continue
    os_doc_is_key "$fm_key" || continue
    os_doc_superseded && continue
    if [ -z "$node" ]; then
      [ -z "$fm_about" ] || continue
    else
      os_about_names "$fm_about" "$node" || continue
    fi
    os_doc_index_line "$brain" "$rel" "$ws/decisions"
    printf '\n'
  done <<DOCS
$(os_docs_sorted "$brain" "$ws/decisions")
DOCS
  return 0
}

# os_buscar_oficio BRAIN SLUG -> la ruta del archivo con `command: SLUG`, relativa al brain, por
# stdout. Exit 0 si lo encontró, 1 si no. Único buscador (spec 009): la mitad negativa del arranque
# de sesión (el aviso "capacidad no instalada") y la positiva (nombrar la ruta del oficio activo)
# leen del mismo lugar — dos copias de este recorrido se desincronizan la primera vez que cambie
# dónde vive un oficio.
#
# Busca en `.os/core/skills`, `.os/packs/*/skills` y después en las carpetas de skills del brain
# (`OS_SKILL_DIRS`: `.agents/skills` primero, `.claude/skills` después; spec 076, C10), la marca en
# primera columna: `command: SLUG` en el frontmatter de un `.md`, `# command: SLUG` en un script — el
# mismo vocabulario que declara un invocable en toda la arquitectura. Se queda con el primer archivo
# que matchea, así que una skill presente en las dos carpetas de skills se encuentra una sola vez.
#
# Las carpetas de skills del brain son donde el CLI de skills.sh deja un pack bajado por
# `npx skills add` (spec 026), y ahí la marca del formato Agent Skills es `name:`, no `command:` — el
# generador del release la escribe desde el mismo `command:` del fuente. Sin este origen, un `role:`
# de un oficio del pack se reporta como capacidad no instalada con el oficio instalado al lado.
#
# La coincidencia es sin distinción de mayúsculas (spec personal-os#014, Gate 1): `role: CPO` en el
# nodo activa `command: cpo` del oficio. El slug canónico del archivo sigue siendo minúscula; acá
# se normaliza el slug de entrada con `os_lower` y se busca con `grep -i`.
os_buscar_oficio() {
  local brain="$1" slug="$2" d f rel slug_lc marca sd
  local -a dirs
  slug_lc=$(os_lower "$slug")
  dirs=("$brain/.os/core/skills" "$brain"/.os/packs/*/skills)
  for sd in $OS_SKILL_DIRS; do dirs+=("$brain/$sd"); done
  for d in "${dirs[@]}"; do
    [ -d "$d" ] || continue
    # La marca depende del origen, no del archivo: `name:` solo se acepta donde el formato es el del
    # CLI. Aceptarla en todos lados volvería invocable cualquier frontmatter con esa clave.
    marca="^(# )?command: $slug_lc\$"
    for sd in $OS_SKILL_DIRS; do
      [ "$d" = "$brain/$sd" ] && marca="^(# )?name: $slug_lc\$"
    done
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      if grep -qiE "$marca" "$f"; then
        rel="${f#$brain/}"
        printf '%s\n' "$rel"
        return 0
      fi
    done <<FILES
$(find -L "$d" -type f 2>/dev/null | sort)
FILES
  done
  return 1
}

# os_skill_resolver_indexes BRAIN -> the pack indexes the brain has installed, one path per line,
# relative to the brain: `<skills-dir>/<pack>-resolver/SKILL.md` for each folder of `OS_SKILL_DIRS`
# that exists, in lookup order (spec 076, C10). A pack present in both folders —the link that
# `npx skills add` leaves in `.claude/skills`— counts once, under the first folder. The glob of the
# shell, never `find`: the CLI leaves the pack index as a symlinked folder, and pathname expansion
# follows it.
os_skill_resolver_indexes() {
  local brain="$1" sd f name seen="" nl
  nl=$(printf '\nx'); nl="${nl%x}"
  for sd in $OS_SKILL_DIRS; do
    [ -d "$brain/$sd" ] || continue
    for f in "$brain/$sd"/*-resolver/SKILL.md; do
      [ -f "$f" ] || continue
      name=$(basename "$(dirname "$f")")
      case "$nl$seen" in *"$nl$name$nl"*) continue ;; esac
      seen="$seen$name$nl"
      printf '%s\n' "${f#$brain/}"
    done
  done
  return 0
}

# os_pack_hint BRAIN -> el ofrecimiento del pack en una línea, o vacío.
# La demanda dispara la oferta (spec 029): cuando algo pide una capacidad que no está y en el brain
# no hay ningún skill instalado por el CLI, lo que falta puede ser justamente lo que trae el pack, y
# el aviso lleva el comando al lado en vez de dejar al operador buscándolo.
#
# Con algo ya instalado en las carpetas de skills no se ofrece nada: ahí el pack está, y lo que falte
# es otro problema — ofrecer una instalación hecha es ruido en cada arranque.
#
# El comando exacto lo imprime `pack-install.sh --line`, único lugar donde el generador inyecta el
# nombre del repo del pack. Sin ese archivo —un brain instalado desde una versión anterior— la
# función no dice nada: un aviso que no puede nombrar el comando no agrega información.
os_pack_hint() {
  local brain="$1" d sd linea
  for sd in $OS_SKILL_DIRS; do
    for d in "$brain/$sd"/*/SKILL.md; do
      [ -f "$d" ] && return 0
    done
  done
  [ -x "$brain/.os/core/lib/pack-install.sh" ] || return 0
  linea=$("$brain/.os/core/lib/pack-install.sh" --brain "$brain" --line 2>/dev/null) || return 0
  [ -n "$linea" ] || return 0
  printf ' — %s' "$linea"
}

# ---------------------------------------------------------------- el formato de línea del backlog
# Una tarea es una línea:
#
#   - [ ] tsk-001 <texto libre> (blocked-by: <ref>) (hold: <razón>) (hold-until: <fecha>) (since <fecha>)
#
# **Los marcadores son grupos `(clave: valor)` al final de la línea, y solo ahí.** El texto libre del
# operador queda verbatim y nunca se interpreta: con los marcadores reconocidos en cualquier posición,
# capturar "revisar el blocked-by: de la spec 3" escondía la tarea del conteo de listas — texto del
# operador leído como estructura del formato.
#
# El escaneo va de derecha a izquierda y para en el primer grupo que no sea un marcador conocido, así
# que un paréntesis adentro del texto no arrastra nada. Límite conocido: un texto libre que **termina**
# con un grupo con forma de marcador —`(hold-until: 2000-01-01)`— sí colisiona. Es en banda, y la
# alternativa es escapar el texto del operador, que rompe la otra mitad —que el archivo se lea solo—.
#
# Único lugar donde este formato se lee y se escribe: lo consumen `capture` al escribir y el arranque
# de sesión al contar. Una segunda copia es la desincronización de siempre.
OS_BACKLOG_MARCAS="blocked-by hold hold-until since"

bl_hecha=""; bl_id=""; bl_texto=""
bl_blocked_by=""; bl_hold=""; bl_hold_until=""; bl_hold_until_dado=""; bl_since=""
bl_roto=""

# os_backlog_lee LINEA -> 0 si la línea es una tarea, 1 si no. Deja el resultado en `bl_*`.
os_backlog_lee() {
  local line="$1" resto grupo clave valor conocida m
  bl_hecha=""; bl_id=""; bl_texto=""
  bl_blocked_by=""; bl_hold=""; bl_hold_until=""; bl_hold_until_dado=0; bl_since=""
  bl_roto=""
  case "$line" in
    '- [ ] '*) bl_hecha=0; resto="${line#- \[ \] }" ;;
    '- [x] '*) bl_hecha=1; resto="${line#- \[x\] }" ;;
    *) return 1 ;;
  esac

  while :; do
    case "$resto" in
      *')') ;;
      *) break ;;
    esac
    case "$resto" in
      *'('*) ;;
      *) break ;;
    esac
    grupo="${resto##*\(}"
    grupo="${grupo%\)}"
    case "$grupo" in
      'since '*) clave="since"; valor=$(os_trim "${grupo#since }") ;;
      *:*) clave=$(os_trim "${grupo%%:*}"); valor=$(os_trim "${grupo#*:}") ;;
      *) break ;;
    esac
    conocida=0
    for m in $OS_BACKLOG_MARCAS; do
      [ "$clave" = "$m" ] && conocida=1
    done
    [ "$conocida" = "1" ] || break
    case "$clave" in
      blocked-by) bl_blocked_by="$valor" ;;
      hold) bl_hold="$valor" ;;
      hold-until) bl_hold_until="$valor"; bl_hold_until_dado=1 ;;
      since) bl_since="$valor" ;;
    esac
    resto="${resto%\(*}"
    resto=$(os_trim "$resto")
  done

  # El id es el primer token, si tiene la forma que escribe `capture`.
  case "$resto" in
    tsk-*)
      bl_id="${resto%% *}"
      if [ "$bl_id" = "$resto" ]; then resto=""; else resto="${resto#* }"; fi
      ;;
  esac
  bl_texto=$(os_trim "$resto")

  # Una clave reservada SUELTA en el texto —`blocked-by: tsk-001` sin paréntesis, que es el formato
  # que escribía la 002— ya no se lee como marcador: el texto queda verbatim y el marcador se pierde
  # en silencio. `bl_roto` lo declara y no cambia el conteo: la tarea sigue contando como siempre.
  # Es la misma ley que la 003 aplicó al `status:` fuera del vocabulario — declarar en vez de
  # interpretar. Quien llama le pone el número de línea, que es lo que vuelve accionable el aviso.
  for m in blocked-by hold-until hold; do
    case "$bl_texto" in
      *"$m: "*|*"$m:")
        [ -n "$bl_roto" ] || bl_roto="marcador en formato viejo: $m"
        ;;
    esac
  done
  return 0
}

# os_backlog_lista HOY -> 0 si la tarea leída está lista para hacerse hoy.
# Uso: os_backlog_lee "$linea" && os_backlog_lista "$(date +%Y-%m-%d)"
# Trabada por otra tarea no está lista. Un `hold` vigente tampoco; uno vencido devuelve la tarea. Un
# `hold-until:` sin fecha es un hold vigente indefinido: sin fecha no hay día en que la tarea resurja.
os_backlog_lista() {
  [ -n "$bl_blocked_by" ] && return 1
  if [ "$bl_hold_until_dado" = "1" ]; then
    if [ -n "$bl_hold_until" ] && [ "$bl_hold_until" \< "$1" ]; then return 0; fi
    return 1
  fi
  [ -n "$bl_hold" ] && return 1
  return 0
}

# os_backlog_linea ID TEXTO BLOCKED_BY HOLD HOLD_UNTIL HOLD_UNTIL_DADO SINCE
# La otra mitad del mismo formato: lo escribe quien captura, lo lee `os_backlog_lee`.
os_backlog_linea() {
  local linea="- [ ] $1 $2"
  [ -n "$3" ] && linea="$linea (blocked-by: $3)"
  [ -n "$4" ] && linea="$linea (hold: $4)"
  [ "$6" = "1" ] && linea="$linea (hold-until: $5)"
  linea="$linea (since $7)"
  printf '%s' "$linea"
}

# os_una_linea TEXTO -> el texto en una sola línea, con los blancos colapsados.
# Una captura es una línea. Un texto con saltos escribía varias, y una de ellas podía tener la forma
# de una tarea: quedaba en el backlog una tarea que nadie escribió, con un id que además envenenaba
# al siguiente. Se colapsa en vez de rechazar: `capture` existe para tirar cosas al vuelo.
os_una_linea() {
  local s="$1" nl cr tab
  nl=$(printf '\nx'); nl="${nl%x}"
  cr=$(printf '\rx'); cr="${cr%x}"
  tab=$(printf '\tx'); tab="${tab%x}"
  s="${s//$nl/ }"
  s="${s//$cr/ }"
  s="${s//$tab/ }"
  while :; do
    case "$s" in
      *'  '*) s="${s//  / }" ;;
      *) break ;;
    esac
  done
  printf '%s' "$(os_trim "$s")"
}

# os_backlog_cabecera BRAIN TITULO -> la cabecera de un backlog nuevo, en el idioma del brain.
# El texto sale del catálogo (`templates/strings.md`): un archivo que nace en la sesión sale en el
# mismo idioma que los que escribió el bootstrap.
os_backlog_cabecera() {
  local lang
  lang=$(os_language "$1")
  os_lang_load "$lang"
  printf '# %s %s\n\n' "$S_BACKLOG_TITLE" "$2"
  printf '%s\n\n' "$S_BACKLOG_INTRO"
}

# ---------------------------------------------------------------- backlog by initiative (spec 057)
# A task hangs from an initiative and only from there: there is no workspace-level or root-level
# backlog to write into any more (decision 1). The functions below are the only place that names
# where an initiative's own `backlog.md` lives — everything that writes or counts tasks calls
# through here instead of concatenating the path by hand.

# os_ini_head_rel BRAIN PREFIX SLUG -> the initiative's head, relative to the brain. PREFIX is
# `<wsdir>/<org>/` for a workspace initiative, or empty for a root one — always with the trailing
# slash already in it, or no slash at all.
os_ini_head_rel() {
  printf '%s%s' "$2" "$(os_head_path "$1" initiative "$3")"
}

# os_ini_existe BRAIN PREFIX SLUG -> 0 if that initiative's head exists under PREFIX.
os_ini_existe() {
  [ -f "$1/$(os_ini_head_rel "$1" "$2" "$3")" ]
}

# os_ini_slugs BRAIN PREFIX -> the slugs of the initiatives that live under PREFIX, one per line —
# the folders that carry a head (the new form) or the loose files (the old one, spec 040). The head
# name is never hardcoded here (spec 040): `os_head_file` is the only reader of that form.
os_ini_slugs() {
  local brain="$1" prefix="$2" dir="$brain/${prefix}initiatives" d base head
  [ -d "$dir" ] || return 0
  head=$(os_head_file "$brain") || true
  for d in "$dir"/*; do
    if [ -d "$d" ]; then
      [ -f "$d/$head" ] || continue
      printf '%s\n' "$(basename "$d")"
    else
      case "$d" in
        *.md)
          base=$(basename "$d")
          printf '%s\n' "${base%.md}"
          ;;
      esac
    fi
  done
  return 0
}

# os_ini_backlog_rel PREFIX SLUG -> the path of that initiative's own `backlog.md`, relative to the
# brain. Only the new form — a folder per initiative — has room for a backlog next to the head; the
# old form (a loose file) has none, and this spec does not give it one.
os_ini_backlog_rel() {
  printf '%sinitiatives/%s/backlog.md' "$1" "$2"
}

# os_ini_backlog_asegurar BRAIN PREFIX SLUG
# Leaves that initiative's `backlog.md` existing. A content-only file is born with its first piece
# of data, never with the bootstrap — same criterion every other backlog followed. No glob gets
# declared here: `content: initiatives/*/*.md` (and its workspace twin) already reach it, so unlike
# the workspace/root backlogs of before this spec, this one needs no line of its own in `tree.md`.
#   0  already there      1  born with this piece of data
os_ini_backlog_asegurar() {
  local brain="$1" prefix="$2" slug="$3" file titulo
  file="$brain/$(os_ini_backlog_rel "$prefix" "$slug")"
  [ -f "$file" ] && return 0
  titulo=$(os_titulo "$brain/$(os_ini_head_rel "$brain" "$prefix" "$slug")")
  [ -n "$titulo" ] || titulo="$slug"
  os_backlog_cabecera "$brain" "$titulo" > "$file"
  return 1
}

# os_backlog_next_id BRAIN -> the next `tsk-XXX`, unique across the whole brain (decision 3: the
# counter stays global, never per initiative — ids already written get cited by number in a README
# or a decision). One pass over every `backlog.md` the brain has, initiative or stray, instead of a
# state file of its own: an id already sitting in a leftover workspace/root backlog still has to be
# respected, or the next capture would collide with it.
os_backlog_next_id() {
  local brain="$1" f line num max=0
  while IFS= read -r f || [ -n "$f" ]; do
    [ -n "$f" ] || continue
    while IFS= read -r line || [ -n "$line" ]; do
      os_backlog_lee "$line" || continue
      num="${bl_id#tsk-}"
      case "$num" in
        ''|*[!0-9]*) continue ;;
      esac
      while [ "${num#0}" != "$num" ] && [ -n "${num#0}" ]; do num="${num#0}"; done
      [ "$num" -gt "$max" ] && max="$num"
    done < "$f"
  done <<FILES
$(find "$brain" -name 'backlog.md' -not -path '*/.git/*' -not -path '*/.os/*' 2>/dev/null)
FILES
  printf 'tsk-%03d' "$(( max + 1 ))"
}

# The slug of a workspace's initiative for tasks that belong to no other (spec 076, Gate 1 P9). Its
# title comes from the strings catalog (`TASKS_TO_SORT_TITLE`), in the language of the brain.
OS_TASKS_TO_SORT_SLUG="tasks-to-sort"

# os_strip_emoji TEXT -> TEXT without the emoji the product itself writes at the start of a title and the space
# after it (spec 079, C15): `👤 ` on the operator's heading and `✍️ ` on the voice's. Nothing else is touched, so a
# name that begins with any other Unicode character comes out as it came in.
os_strip_emoji() {
  case "$1" in
    "👤 "*) printf '%s' "${1#"👤 "}" ;;
    "✍️ "*) printf '%s' "${1#"✍️ "}" ;;
    *) printf '%s' "$1" ;;
  esac
}

# os_operator_name BRAIN -> the operator's name: the first `# Title` of `account/operator.md`, without the
# emoji that opens it.
os_operator_name() {
  os_strip_emoji "$(os_titulo "$1/$OS_OPERATOR_FILE")"
}

# os_ini_render TITLE STATUS ABOUT OWNER DATE -> the text of the head of a new initiative, on stdout:
# the same frontmatter a standing initiative already carries in a real brain (`status`, `owner` when
# given, `horizon: later`, `about` when given, `updated`) and its title. The one place that shape is
# written: `os_ini_create` writes it to disk, and the layout migration (`migrate_layout.py`) calls it
# to plan the initiatives it creates, so the two can never differ.
os_ini_render() {
  local title="$1" status="$2" about="$3" owner="$4" day="$5"
  printf -- '---\n'
  printf 'status: %s\n' "$status"
  [ -n "$owner" ] && printf 'owner: %s\n' "$owner"
  printf 'horizon: later\n'
  [ -n "$about" ] && printf 'about: %s\n' "$about"
  printf 'updated: %s\n' "$day"
  printf -- '---\n\n'
  printf '# %s\n' "$title"
}

# os_ini_create BRAIN PREFIX SLUG TITLE STATUS [ABOUT] — writes the head of a new initiative
# (`os_ini_render`, owned by the operator, dated today). Never overwrites: exit 1 if the head is
# already there. Its callers (spec 076) are `capture --about --create`, after the operator said
# yes, and the workspace's `tasks-to-sort`, where the system files its own pending steps. Only the
# new form (a folder per initiative) is written.
os_ini_create() {
  local brain="$1" prefix="$2" slug="$3" title="$4" status="$5" about="${6:-}" rel
  rel=$(os_ini_head_rel "$brain" "$prefix" "$slug")
  [ -e "$brain/$rel" ] && return 1
  mkdir -p "$(dirname "$brain/$rel")" || return 1
  os_ini_render "$title" "$status" "$about" "$(os_operator_name "$brain")" "$(date +%Y-%m-%d)" \
    > "$brain/$rel" || return 1
  return 0
}

# os_personal_backlog_append BRAIN TASK — the one write of a task that the system does for itself, and
# only after the operator's yes (spec 076, final Gate 2): `pack-install.sh --defer --note` and
# `remote-backup.sh --note`; without `--note` both ask «¿Te lo anoto para después?» and write nothing. A
# pending step of the system itself (installing the skill pack, setting up the remote backup),
# written by a deterministic script with no model in between that could name an initiative (spec
# 057, delegated decision). Since spec 076 (C29) no tool writes a `backlog.md` outside an initiative:
# the step lands in the backlog of the `tasks-to-sort` initiative of the `personal` workspace —the
# initiative Gate 1 (P9) set for the tasks of a workspace that fit no other—, born here with its
# first task when it is not there. An existing `tasks-to-sort` is reused only if it has no `about:`.
# Same line format and same brain-wide counter as `capture`.
#   0  written      1  the same task was already there      2  the `personal` workspace does not
#   exist (a brain born before spec 059 and not migrated yet) — nothing written      3  the
#   `tasks-to-sort` slug is taken by an initiative that is about a node — nothing written
os_personal_backlog_append() {
  local brain="$1" task="$2" wsdir prefix slug="$OS_TASKS_TO_SORT_SLUG" file id
  wsdir=$(os_ws_dir "$brain")
  prefix="$wsdir/$OS_PERSONAL_WORKSPACE_SLUG/"
  [ -d "$brain/$prefix" ] || return 2
  if os_ini_existe "$brain" "$prefix" "$slug"; then
    fm_read "$brain/$(os_ini_head_rel "$brain" "$prefix" "$slug")"
    [ -z "$fm_about" ] || return 3
  else
    os_lang_load "$(os_language "$brain")" > /dev/null 2>&1
    os_ini_create "$brain" "$prefix" "$slug" "$S_TASKS_TO_SORT_TITLE" active || return 3
  fi
  file="$brain/$(os_ini_backlog_rel "$prefix" "$slug")"
  if [ -f "$file" ] && grep -qF -- "$task" "$file"; then return 1; fi
  os_ini_backlog_asegurar "$brain" "$prefix" "$slug" || true
  id=$(os_backlog_next_id "$brain")
  printf '%s\n' "$(os_backlog_linea "$id" "$task" "" "" "" "0" "$(date +%Y-%m-%d)")" >> "$file"
  return 0
}

# ---------------------------------------------------------------- el nombre de la carpeta (spec 039)
# El código sigue diciendo "org" —la variable, la opción `--org`, `os_org_slugs`, `os_org_existe`,
# `OS_ORG_PROPIOS`— porque nada de eso lo ve el operador (P3): renombrarlo agrandaría el diff sin
# cambiar nada hacia afuera. Lo que el operador ve es la palabra "workspace"/"espacio de trabajo" y
# el nombre de la carpeta, y los dos se resuelven acá, en un solo lugar.

# os_ws_dir BRAIN -> el nombre real de la carpeta de espacios de trabajo de este brain:
# `workspaces` o `orgs`, leído del árbol (`tree.md`), nunca de qué carpeta exista en disco (H3: el
# árbol ya es la fuente de qué lee un barrido). Sin `tree.md`, o sin ninguna de las dos líneas,
# `workspaces` — el nombre de nacimiento. Nunca aborta: solo imprime. Un layout inválido lo detecta
# `os_ws_check`, aparte.
os_ws_dir() {
  local tree="$1/$OS_TREE_FILE" line
  [ -f "$tree" ] || { printf 'workspaces'; return 0; }
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      'glob: workspaces/'*|'content: workspaces/'*) printf 'workspaces'; return 0 ;;
      'glob: orgs/'*|'content: orgs/'*) printf 'orgs'; return 0 ;;
    esac
  done < "$tree"
  printf 'workspaces'
}

# os_ws_check BRAIN
# Corre antes de cualquier `$(...)` que arme una ruta con `os_ws_dir` (P2): un `os_die` adentro de
# una sustitución de comando mata solo la subshell, y el script seguiría con la variable vacía
# armando rutas en la raíz del brain. Sale con `os_die` cuando el layout es inválido:
#   (a) existen `workspaces/` y `orgs/` a la vez — nadie eligió una;
#   (b) el árbol declara una y en disco existe solo la otra — el árbol quedó desincronizado del
#       disco (por ejemplo, un `mv` a mano sin tocar `tree.md`).
# Con un layout válido, no imprime nada y vuelve con 0.
os_ws_check() {
  local brain="$1" declarado tiene_ws=0 tiene_orgs=0 lang
  [ -d "$brain/workspaces" ] && tiene_ws=1
  [ -d "$brain/orgs" ] && tiene_orgs=1
  [ "$tiene_ws" = "1" ] || [ "$tiene_orgs" = "1" ] || return 0
  lang=$(os_language "$brain")
  os_lang_load "$lang"
  if [ "$tiene_ws" = "1" ] && [ "$tiene_orgs" = "1" ]; then
    os_die "$S_WS_LAYOUT_BOTH"
  fi
  declarado=$(os_ws_dir "$brain")
  if [ "$declarado" = "workspaces" ] && [ "$tiene_ws" = "0" ]; then
    os_die "$S_WS_LAYOUT_MISMATCH_WS"
  fi
  if [ "$declarado" = "orgs" ] && [ "$tiene_orgs" = "0" ]; then
    os_die "$S_WS_LAYOUT_MISMATCH_ORGS"
  fi
  return 0
}

# ---------------------------------------------------------------- la forma de la cabeza (spec 040)
# Todo nodo es una carpeta con su cabeza adentro, y la cabeza se llama `README.md`. Un brain nacido
# antes de esta spec la llama de otra manera y guarda las iniciativas como archivo suelto: la forma
# se lee del árbol —igual que el nombre de la carpeta de espacios de trabajo (spec 039)— y ningún
# script lleva adentro el nombre viejo. `rename-heads` adopta la forma nueva a pedido.

# os_head_file BRAIN -> el nombre de la cabeza de un nodo en este brain, leído del árbol, y la
# forma en el código de salida. Único lector de la forma: todo lo demás la recibe de acá.
#
# El árbol declara las cabezas en dos alturas: la del espacio de trabajo (`glob: <wsdir>/*/<cabeza>`,
# donde la cabeza es el único glob de esa altura que no es un canónico de `OS_NODE_CANONICOS`) y la
# de las iniciativas (`glob: initiatives/...`, en la raíz o adentro de un espacio de trabajo). Un
# brain de raíz pura no declara la primera, así que la forma se lee igual de la segunda.
#
# Imprime el nombre de la cabeza de nodo, o `README.md` cuando el árbol no declara esa altura — es
# el nombre con el que se arma una ruta nueva, no una afirmación sobre lo que el brain tiene.
# Las dos alturas se leen siempre, incluso cuando la primera ya contestó: un brain a medio migrar
# tiene una en cada forma, y cortar en la primera lo daba por migrado entero.
#
# Exit: 0 las dos alturas en la forma nueva · 1 las dos en la anterior · 2 el árbol no declara
# ninguna cabeza · 3 mixto, con el espacio de trabajo en la forma nueva y las iniciativas en la
# anterior · 4 mixto al revés. Nunca aborta ella misma, pero su código de salida no es un error:
# quien solo quiera el nombre tiene que absorberlo (`|| true`), o `set -e` mata al script en la
# asignación.
os_head_file() {
  local brain="$1" tree="$1/$OS_TREE_FILE" line g base wsdir ws_head="" ini_forma=""
  [ -f "$tree" ] || { printf 'README.md'; return 2; }
  wsdir=$(os_ws_dir "$brain")
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      glob:*) ;;
      *) continue ;;
    esac
    g=$(os_trim "${line#glob:}")
    # la altura de las iniciativas, en la raíz o adentro de un espacio de trabajo
    case "$g" in
      initiatives/\*/?*|"$wsdir"/\*/initiatives/\*/?*) [ -n "$ini_forma" ] || ini_forma="nueva"; continue ;;
      initiatives/\*.md|"$wsdir"/\*/initiatives/\*.md) [ -n "$ini_forma" ] || ini_forma="vieja"; continue ;;
    esac
    # la altura del espacio de trabajo
    case "$g" in
      "$wsdir"/\*/*/*) continue ;;
      "$wsdir"/\*/?*) base="${g##*/}" ;;
      *) continue ;;
    esac
    case " $OS_NODE_CANONICOS " in
      *" $base "*) continue ;;
    esac
    [ -n "$ws_head" ] || ws_head="$base"
  done < "$tree"

  local ws_forma=""
  if [ -n "$ws_head" ]; then
    printf '%s' "$ws_head"
    if [ "$ws_head" = "README.md" ]; then ws_forma="nueva"; else ws_forma="vieja"; fi
  else
    printf 'README.md'
  fi

  # sin ninguna de las dos alturas declarada, el árbol no dice nada sobre la forma
  [ -n "$ws_forma$ini_forma" ] || return 2
  # con una sola declarada, esa es la forma del brain
  [ -n "$ws_forma" ] || { [ "$ini_forma" = "nueva" ] && return 0; return 1; }
  [ -n "$ini_forma" ] || { [ "$ws_forma" = "nueva" ] && return 0; return 1; }
  # con las dos, coinciden o el brain está a medio migrar
  [ "$ws_forma" = "$ini_forma" ] && { [ "$ws_forma" = "nueva" ] && return 0; return 1; }
  [ "$ws_forma" = "nueva" ] && return 3
  return 4
}

# os_head_path BRAIN KIND [SLUG] -> la ruta de una cabeza, relativa al nodo que la contiene.
#   node               la cabeza de un espacio de trabajo o de un producto
#   initiative SLUG    la cabeza de una iniciativa
# No lee el árbol: lo hace `os_head_file`. Con la forma nueva una iniciativa es una carpeta con su
# `README.md` adentro; con la vieja, un archivo suelto. Los scripts arman rutas con esto y nunca
# concatenando un nombre propio.
os_head_path() {
  local brain="$1" kind="$2" slug="${3:-}" head forma=0
  head=$(os_head_file "$brain") || forma=$?
  case "$kind" in
    node) printf '%s' "$head" ;;
    initiative)
      # La forma de esta altura, no la del brain entero: en un brain a medio migrar (3 y 4) las dos
      # alturas difieren. 1 y 3 son los dos casos con la iniciativa en la forma anterior.
      if [ "$forma" = "1" ] || [ "$forma" = "3" ]; then
        printf 'initiatives/%s.md' "$slug"
      else
        # En la forma nueva la cabeza se llama siempre igual, sea cual sea el nombre que la altura
        # del espacio de trabajo tenga declarado en un brain a medio migrar.
        printf 'initiatives/%s/README.md' "$slug"
      fi
      ;;
    *) return 1 ;;
  esac
  return 0
}

# os_node_name RUTA -> el nombre del nodo que esa cabeza encabeza.
# El nombre de la cosa aparece una sola vez: en la carpeta. Una cabeza `README.md` lo toma de su
# carpeta; una cabeza vieja, del nombre del archivo. No lee el árbol: la forma se ve en la ruta.
os_node_name() {
  local ruta="$1" base carpeta
  base="${ruta##*/}"
  if [ "$base" = "README.md" ]; then
    carpeta="${ruta%/*}"
    printf '%s' "${carpeta##*/}"
    return 0
  fi
  printf '%s' "${base%.md}"
}

# os_entity_name RUTA -> el nombre de la entidad que una cabeza de `about:` encabeza (spec 056),
# siempre por su carpeta. A diferencia de `os_node_name`, acá no hay caso de iniciativa suelta que
# distinguir: quien llama ya validó con `os_head_kind` que RUTA es una entidad —producto, cuenta,
# canal o curso—, y las cuatro viven siempre en una carpeta propia en las dos formas de cabeza (spec
# 040): la cabeza vieja de esa forma no es la identidad del nodo ahí, la carpeta lo es. Una función propia, en vez
# de sumarle a `os_node_name` un segundo caso especial: esa función también nombra iniciativas
# sueltas de la forma vieja, donde el archivo sí es la identidad, y confundir los dos casos por el
# nombre de archivo rompería esa otra lectura.
os_entity_name() {
  local ruta="$1" carpeta
  carpeta="${ruta%/*}"
  printf '%s' "${carpeta##*/}"
}

# os_org_propios BRAIN -> los archivos propios de un nodo espacio de trabajo, cabeza incluida.
os_org_propios() {
  printf '%s %s' "$(os_head_file "$1" || true)" "$OS_NODE_CANONICOS"
}

# os_org_slugs BRAIN -> los slugs reales de la carpeta de espacios de trabajo de este brain, uno
# por línea. El ámbito se valida contra este listado, byte a byte, nunca con `[ -d ]`: un test de
# directorio acepta lo que acepte el filesystem —`Acme` en uno que no distingue mayúsculas,
# `../..` fuera del árbol— y el resultado se lee como un brain vacío en vez de como un ámbito mal
# escrito.
os_org_slugs() {
  local d wsdir
  wsdir=$(os_ws_dir "$1")
  [ -d "$1/$wsdir" ] || return 0
  for d in "$1/$wsdir"/*; do
    [ -d "$d" ] || continue
    printf '%s\n' "$(basename "$d")"
  done
  return 0
}

# os_org_existe BRAIN SLUG -> 0 si el slug es una organización real.
os_org_existe() {
  local s
  while IFS= read -r s || [ -n "$s" ]; do
    [ "$s" = "$2" ] && return 0
  done <<SLUGS
$(os_org_slugs "$1")
SLUGS
  return 1
}

# os_titulo ARCHIVO -> el primer `# Título` del archivo, o vacío.
os_titulo() {
  local line
  [ -f "$1" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      '# '*) printf '%s' "$(os_trim "${line#\# }")"; return 0 ;;
    esac
  done < "$1"
  return 0
}

# os_file_mode ARCHIVO -> los bits de permiso en octal (tres dígitos), o exit 1. Se leen de `ls -ld`
# y se convierten acá: `stat` no está en el PATH mínimo con el que corre E7, y un lector que no
# existe devuelve vacío, que es lo mismo que "sin permisos que conservar" — el archivo vuelve con el
# umask de la sesión sin que nadie se entere. Los bits especiales (setuid, sticky) no se conservan:
# ningún archivo del brain los usa.
os_file_mode() {
  local line perms i val total=""
  line=$(ls -ld "$1" 2>/dev/null) || return 1
  set -- $line
  perms="$1"
  [ "${#perms}" -ge 10 ] || return 1
  for i in 1 4 7; do
    val=0
    case "${perms:$i:1}" in r) val=$(( val + 4 )) ;; esac
    case "${perms:$(( i + 1 )):1}" in w) val=$(( val + 2 )) ;; esac
    case "${perms:$(( i + 2 )):1}" in x|s|t) val=$(( val + 1 )) ;; esac
    total="$total$val"
  done
  printf '%s' "$total"
  return 0
}

# os_replace_file TMP DESTINO
# Reemplaza el destino por el temporal conservando sus permisos, y devuelve 1 —borrando el
# temporal— si algo falló. Un `mv` sin chequear sobre un directorio sin permiso de escritura deja
# el archivo intacto y el llamador anunciando que escribió: una escritura que no ocurrió nunca
# reporta éxito (spec 047 C1). Los permisos se copian antes del `mv` porque el temporal nace con el
# umask de la sesión: sin eso un archivo de solo lectura vuelve 0644.
os_replace_file() {
  local tmp="$1" dest="$2" mode
  [ -f "$tmp" ] || return 1
  if [ -e "$dest" ]; then
    mode=$(os_file_mode "$dest") || mode=""
    if [ -n "$mode" ]; then
      chmod "$mode" "$tmp" 2>/dev/null || { rm -f "$tmp"; return 1; }
    fi
  fi
  mv -f "$tmp" "$dest" 2>/dev/null || { rm -f "$tmp"; return 1; }
  return 0
}

# os_tree_class_matches BRAIN CLASE RUTA -> 0 si algún glob de esa clase (`glob`, `content` o
# `archive`) coincide con la ruta. A diferencia de los tres lectores de arriba, que expanden los
# globs contra lo que hay en disco, esto contesta por una ruta que todavía no existe: es lo que
# necesita quien va a **escribir** ahí. Sin esto, un comando escribe un archivo en una carpeta que
# ningún árbol alcanza y el resultado es invisible para el barrido y para la auditoría de vigencia.
#
# La comparación es segmento por segmento, y por eso no es un `case "$ruta" in $glob)` pelado: en un
# patrón de `case` el `*` **cruza las barras**, así que `workspaces/*/initiatives/*/*.md` le daría
# por bueno `workspaces/a/initiatives/i/research/x.md` — una altura que ese glob no declara. Al
# expandir contra el disco eso no pasa (ahí el `*` no cruza), y una respuesta distinta según si el
# archivo ya existe es la peor de las dos.
os_tree_class_matches() {
  local brain="$1" clase="$2" ruta="$3" line g
  [ -f "$brain/$OS_TREE_FILE" ] || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      "$clase":*) ;;
      *) continue ;;
    esac
    g=$(os_trim "${line#$clase:}")
    [ -n "$g" ] || continue
    os_glob_path_match "$g" "$ruta" && return 0
  done < "$brain/$OS_TREE_FILE"
  return 1
}

# os_glob_path_match GLOB RUTA -> 0 si coinciden con la semántica de los globs del árbol: el `*` vale
# adentro de un segmento y nunca cruza una barra. Los dos tienen que tener la misma cantidad de
# segmentos.
os_glob_path_match() {
  local g="$1" r="$2" gs rs
  while [ -n "$g" ] || [ -n "$r" ]; do
    case "$g" in */*) gs="${g%%/*}"; g="${g#*/}" ;; *) gs="$g"; g="" ;; esac
    case "$r" in */*) rs="${r%%/*}"; r="${r#*/}" ;; *) rs="$r"; r="" ;; esac
    [ -n "$gs" ] || [ -n "$rs" ] || return 1
    case "$rs" in
      $gs) ;;
      *) return 1 ;;
    esac
  done
  return 0
}

# ---------------------------------------------------------------- una ruta que se movió se reescribe una sola vez
# La regla —**solo se reescribe un token que coincide exactamente con una ruta que este comando
# movió**, o con esa misma ruta relativa al nodo dueño del archivo que se está reescribiendo; nunca
# por sufijo, y un nombre pelado sin una sola barra nunca se resuelve contra la carpeta— está
# decidida el 2026-08-22 (`decisions.md`, "Una ruta se reescribe solo si coincide exactamente con
# una que se movió" y "Un nombre suelto no es una ruta"). Vivía adentro de `rename-heads.sh`; la
# spec 048 le agregó un segundo llamador (`archive.sh`), y dos copias de esta regla se desincronizan
# la primera vez que alguien la afine. Vive acá, y los dos comandos la llaman.
#
# Solo bash, carácter a carácter — nada de sed ni awk (E7, PATH restringido).
#
# Límite conocido, por diseño: una ruta con espacios adentro no se reescribe (el texto se parte en
# tokens por espacio). No reescribir es el modo seguro de fallar; corromper, no.
#
# El mapa es `OS_RW_MAP`: una línea por movimiento, `origen<OS_SEP>destino`. Lo escribe el llamador
# antes de reescribir el primer archivo, y con todos los movimientos adentro — un mapa a medio
# llenar deja una referencia apuntando a donde el archivo ya no está.
OS_RW_MAP=""
OS_RW_OUT=""

# os_rw_lookup RUTA -> el destino de una ruta que el llamador movió, por stdout. Exit 1 si esa ruta
# no está en el mapa: entonces el token no se toca.
os_rw_lookup() {
  local linea
  [ -n "$1" ] || return 1
  while IFS= read -r linea || [ -n "$linea" ]; do
    [ -n "$linea" ] || continue
    case "$linea" in
      "$1$OS_SEP"*) printf '%s' "${linea#*$OS_SEP}"; return 0 ;;
    esac
  done <<MAPA
$OS_RW_MAP
MAPA
  return 1
}

# os_rw_token TOKEN DIR — acumula en `OS_RW_OUT`. DIR es la carpeta del archivo que se está
# reescribiendo, relativa al brain, para resolver una referencia relativa al propio nodo.
os_rw_token() {
  local tok="$1" dir="${2:-}" ruta="" ancla="" punto="" linea="" destino
  # Una URL —con esquema o con la forma `usuario@host:ruta`— no es una ruta de este brain.
  case "$tok" in
    *://*|*@*:*) OS_RW_OUT="$OS_RW_OUT$tok"; return 0 ;;
  esac
  ruta="$tok"
  # el ancla del final
  case "$ruta" in
    *'#'*) ancla="#${ruta#*#}"; ruta="${ruta%%#*}" ;;
  esac
  # el `:línea` del final, y el `:` suelto de una cita
  case "$ruta" in
    *:) linea=":"; ruta="${ruta%:}" ;;
    *:[0-9]) linea=":${ruta##*:}"; ruta="${ruta%:*}" ;;
    *:[0-9][0-9]|*:[0-9][0-9][0-9]|*:[0-9][0-9][0-9][0-9]) linea=":${ruta##*:}"; ruta="${ruta%:*}" ;;
  esac
  # el `./` del principio
  case "$ruta" in
    ./*) punto="./"; ruta="${ruta#./}" ;;
  esac
  if [ -n "$ruta" ]; then
    if destino=$(os_rw_lookup "$ruta"); then
      OS_RW_OUT="$OS_RW_OUT$punto$destino$linea$ancla"; return 0
    fi
    # Relativa al nodo dueño del archivo. Solo si el token es una ruta —tiene al menos una barra—:
    # un nombre pelado adentro de la carpeta de un nodo no es una referencia a la cabeza de ese
    # nodo, y resolverlo contra la carpeta reescribía prosa que hablaba de otro repo.
    case "$ruta" in
      */*)
        if [ -n "$dir" ] && destino=$(os_rw_lookup "$dir/$ruta"); then
          OS_RW_OUT="$OS_RW_OUT$punto${destino#$dir/}$linea$ancla"; return 0
        fi
        ;;
    esac
  fi
  OS_RW_OUT="$OS_RW_OUT$tok"
}

# os_rw_line LINEA DIR -> la línea con las rutas movidas reescritas, por stdout.
os_rw_line() {
  local line="$1" dir="${2:-}" i=0 len=${#1} c tok=""
  OS_RW_OUT=""
  while [ "$i" -lt "$len" ]; do
    c="${line:$i:1}"
    case "$c" in
      ' '|$'\t'|'`'|'|'|'('|')'|'['|']'|'<'|'>'|'"'|"'"|','|';'|'!')
        os_rw_token "$tok" "$dir"; tok=""; OS_RW_OUT="$OS_RW_OUT$c" ;;
      *) tok="$tok$c" ;;
    esac
    i=$(( i + 1 ))
  done
  os_rw_token "$tok" "$dir"
  printf '%s' "$OS_RW_OUT"
}

# os_rw_file BRAIN RUTA_RELATIVA -> reescribe el archivo si alguna línea cambió.
#   0  reescribió       1  no había nada que cambiar, o el archivo no está
#   2  había que cambiarlo y la escritura no se pudo hacer
# El 2 existe por la spec 047: una reescritura que no ocurrió no puede contarse como "sin cambios".
os_rw_file() {
  local brain="$1" rel="$2" file="$1/$2" dir tmp line nueva cambio=0
  [ -f "$file" ] || return 1
  case "$rel" in
    */*) dir="${rel%/*}" ;;
    *) dir="" ;;
  esac
  tmp="$file.os-tmp"
  : > "$tmp" 2>/dev/null || return 2
  while IFS= read -r line || [ -n "$line" ]; do
    nueva=$(os_rw_line "$line" "$dir")
    [ "$nueva" = "$line" ] || cambio=1
    printf '%s\n' "$nueva"
  done < "$file" >> "$tmp"
  if [ "$cambio" = "1" ]; then
    os_replace_file "$tmp" "$file" || return 2
    return 0
  fi
  rm -f "$tmp"
  return 1
}

# os_fm_shape_ok ARCHIVO -> 0 si lo que hay entre los dos `---` es realmente un frontmatter: cada
# línea de adentro es una clave, un comentario, un ítem de lista o una línea vacía.
# Un cuerpo markdown que abre con una línea `---` y más abajo tiene otra le parece frontmatter a un
# lector que solo mira los delimitadores, y un escritor que le cree aterriza la clave en el medio de
# la prosa (spec 047 C7). Esto no cambia lo que `fm_read` contesta: es la guarda del escritor.
os_fm_shape_ok() {
  local file="$1" line primera=1 n=0 clave
  [ -f "$file" ] || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    n=$(( n + 1 ))
    if [ "$primera" = "1" ]; then
      primera=0
      [ "$line" = "---" ] || return 1
      continue
    fi
    [ "$line" = "---" ] && return 0
    [ "$n" -ge "$CAP_FRONTMATTER" ] && return 1
    case "$line" in
      "") continue ;;
      '#'*) continue ;;
      '- '*) continue ;;
      ' '*) continue ;;
      '	'*) continue ;;
    esac
    case "$line" in
      *:*) clave="${line%%:*}" ;;
      *) return 1 ;;
    esac
    case "$clave" in
      "") return 1 ;;
      *[!A-Za-z0-9_-]*) return 1 ;;
    esac
  done < "$file"
  return 1
}

# os_fm_set ARCHIVO CLAVE VALOR
# Escribe una clave en el frontmatter de una cabeza sin tocar el cuerpo: reemplaza la que esté o la
# suma antes del `---` de cierre. Exit 1 si el frontmatter no se pudo leer, con el motivo en
# `fm_roto` — escribir sobre un frontmatter que no se entiende es corromper el archivo en silencio—,
# si lo que hay entre los delimitadores no tiene forma de frontmatter, o si la escritura no ocurrió.
os_fm_set() {
  local file="$1" key="$2" value="$3" tmp line primera=1 puesto=0
  fm_read "$file"
  [ -z "$fm_roto" ] || return 1
  os_fm_shape_ok "$file" || return 1
  tmp="$file.os-tmp"
  rm -f "$tmp"
  if ! {
    while IFS= read -r line || [ -n "$line" ]; do
      if [ "$primera" = "1" ]; then
        primera=0
        printf '%s\n' "$line"
        continue
      fi
      if [ "$puesto" = "0" ]; then
        if [ "$line" = "---" ]; then
          printf '%s: %s\n' "$key" "$value"
          puesto=1
          printf '%s\n' "$line"
          continue
        fi
        case "$line" in
          "$key":*)
            printf '%s: %s\n' "$key" "$value"
            puesto=1
            continue
            ;;
        esac
      fi
      printf '%s\n' "$line"
    done < "$file"
  } 2>/dev/null > "$tmp"; then
    rm -f "$tmp"
    return 1
  fi
  # Un frontmatter nunca es vacío: un temporal vacío es una escritura que se cortó a la mitad.
  [ -s "$tmp" ] || { rm -f "$tmp"; return 1; }
  os_replace_file "$tmp" "$file" || return 1
  return 0
}

# os_backticks LINEA -> cada token entre backticks, uno por línea.
# Una ruta declarada se escribe entre backticks, y eso es lo que se verifica: así una fila muerta y
# una referencia no alcanzada se buscan igual, sin distinguir la tabla de la sección de referencias
# —que sería parsear secciones—.
os_backticks() {
  local rest="$1" tok
  while :; do
    case "$rest" in *'`'*) ;; *) break ;; esac
    rest="${rest#*\`}"
    case "$rest" in *'`'*) ;; *) break ;; esac
    tok="${rest%%\`*}"
    rest="${rest#*\`}"
    [ -n "$tok" ] && printf '%s\n' "$tok"
  done
  return 0
}

# ---------------------------------------------------------------- la tabla del entorno
# `mounts.md` en la raíz del brain: remote -> ruta local en ESTA máquina. Es dato del entorno, no del
# producto: no viaja, se gitignorea, y en una máquina nueva no está — los barridos lo reportan y
# `mount-repo` sobre el mismo remote la reconstruye.
#
# El formato lo fija el comando que la escribe, y se enuncia una sola vez acá porque lo consumen tres
# lectores: `mount-repo` al escribir, y los dos barridos al leer.
#
#   clone-root: `<ruta>`            la raíz de clonado de la máquina, fuera del brain
#
#   | Remote | Ruta local |
#   |---|---|
#   | `<remote>` | `<ruta local>`|
#
# Una fila es una línea que empieza con `|` y no es estructura markdown. **La estructura se reconoce
# por forma, no por posición**: separador es toda línea de `|`, `-`, `:` y blancos, y cabecera es la
# línea que precede a un separador. Con la primera tabla ubicada por posición, una segunda tabla
# reportaba su cabecera como fila ilegible — un formato canónico que se declaraba roto a sí mismo.
OS_MOUNTS_ARCHIVO="$OS_SYSTEM_DIR/mounts.md"

# os_mounts_filas ARCHIVO -> una línea por fila de datos: `N<OS_SEP>remote<OS_SEP>ruta`.
# Con remote o ruta vacíos, la fila es ilegible: quien llama la declara con su número de línea, nunca
# la saltea. Exit 1 si el archivo no está.
os_mounts_filas() {
  local file="$1" line n=0 seps="" limpio remote ruta i tok
  [ -f "$file" ] || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    n=$(( n + 1 ))
    case "$line" in '|'*) ;; *) continue ;; esac
    limpio="${line//|/}"; limpio="${limpio//-/}"; limpio="${limpio//:/}"; limpio="${limpio// /}"
    [ -n "$limpio" ] && continue
    seps="$seps $n "
  done < "$file"

  n=0
  while IFS= read -r line || [ -n "$line" ]; do
    n=$(( n + 1 ))
    case "$line" in '|'*) ;; *) continue ;; esac
    case "$seps" in *" $n "*) continue ;; esac
    case "$seps" in *" $(( n + 1 )) "*) continue ;; esac
    remote=""; ruta=""; i=0
    while IFS= read -r tok; do
      i=$(( i + 1 ))
      [ "$i" = "1" ] && remote="$tok"
      [ "$i" = "2" ] && ruta="$tok"
    done <<CELDAS
$(os_backticks "$line")
CELDAS
    printf '%s%s%s%s%s\n' "$n" "$OS_SEP" "$remote" "$OS_SEP" "$ruta"
  done < "$file"
  return 0
}

# os_mounts_clone_root ARCHIVO -> la raíz de clonado declarada, o vacío.
# Se pregunta una sola vez y queda escrita: sin respuesta no hay default inventado — clonar en una
# carpeta que el operador no eligió es esparcir checkouts por la máquina.
os_mounts_clone_root() {
  local line v tok
  [ -f "$1" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      'clone-root:'*) ;;
      *) continue ;;
    esac
    v=$(os_trim "${line#clone-root:}")
    tok=$(os_backticks "$line" | head -1)
    [ -n "$tok" ] && v="$tok"
    printf '%s' "$v"
    return 0
  done < "$1"
  return 0
}

# os_git_sucio BRAIN -> las rutas modificadas o sin trackear que reporta `git status --porcelain`,
# una por línea, relativas al brain. Lector único de la spec 031: lo comparten `close-session.sh`
# (para saber qué queda ajeno a la sesión) y `session-start.sh` (para avisarlo en Chequeos).
#
# Un brain es "repo git" si tiene `.git` en su propia raíz — nunca se resuelve subiendo el árbol con
# `git rev-parse`, porque un brain de prueba (o cualquier brain) puede vivir adentro de otro repo sin
# ser uno él mismo, y ese ancestro ajeno no es el repo que este comando commitea.
#   Exit 1  el brain no es un repo git — sin salida.
os_git_sucio() {
  local brain="$1"
  [ -e "$brain/.git" ] || return 1
  git -C "$brain" status --porcelain 2>/dev/null | while IFS= read -r line; do
    [ -n "$line" ] || continue
    printf '%s\n' "${line:3}"
  done
  return 0
}

# os_gitignore_ensure BRAIN ENTRADA
# Deja la entrada declarada en el `.gitignore` del brain. Lo personal se aísla por posición, y la
# tabla del entorno no puede aislarse así —vive en la raíz del brain—: el gitignore es su frontera, y
# lo escribe el comando que crea el archivo, nunca el operador a mano.
#   0  la agregó       1  ya estaba
os_gitignore_ensure() {
  local file="$1/.gitignore" line
  if [ -f "$file" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      [ "$(os_trim "$line")" = "$2" ] && return 1
    done < "$file"
    # Un `.gitignore` que no termina en newline es legal, y appendear encima pega la entrada nueva a
    # la última regla: se pierden las dos —la regla previa deja de aplicar y la entrada nueva
    # tampoco—, y la tabla del entorno, que lleva rutas con nombre de usuario, viaja igual. La
    # sustitución de comandos come los newlines finales: si `tail -c 1` devuelve algo, el archivo no
    # terminaba en uno.
    if [ -s "$file" ] && [ -n "$(tail -c 1 "$file")" ]; then
      printf '\n' >> "$file"
    fi
  fi
  printf '%s\n' "$2" >> "$file"
  return 0
}

# Python 3 por sus tres nombres (spec 080). Única enunciación del orden y de la prueba en bash;
# `findPython` de ai-first-os.js (el lanzador de npx) la espeja. Orden: `python3`, `python`, `py -3` (el lanzador de Windows,
# que deja `py` y `python` pero nunca `python3`). Un candidato se acepta solo si corre de verdad y
# termina con éxito únicamente cuando su versión mayor es 3: así quedan afuera el atajo de la
# Microsoft Store (falla) y un Python 2.
# El comando queda en el arreglo `OS_PY` —una palabra o dos (`py -3`)—, y se corre siempre como
# "${OS_PY[@]}" o con `os_py`, sin depender de que una cadena se parta en espacios.
OS_PY=()
OS_PYTHON_PROBE='import sys; sys.exit(0 if sys.version_info[0] == 3 else 1)'

# os_python_probe CMD... -> 0 si CMD (una o dos palabras) corre y es Python 3. Con `perl` en el PATH la
# prueba tiene un plazo (OS_PYTHON_PROBE_TIMEOUT, 10 s por defecto): un candidato colgado cuenta como
# fallo y se pasa al siguiente. Sin `perl` no hay plazo.
os_python_probe() {
  if command -v perl > /dev/null 2>&1; then
    perl -e 'alarm shift; exec @ARGV' "${OS_PYTHON_PROBE_TIMEOUT:-10}" "$@" -c "$OS_PYTHON_PROBE" > /dev/null 2>&1
  else
    "$@" -c "$OS_PYTHON_PROBE" > /dev/null 2>&1
  fi
}

# os_python_find -> 0 y deja el comando en OS_PY; 1 y deja OS_PY vacío si ningún nombre sirve.
os_python_find() {
  OS_PY=()
  if command -v python3 > /dev/null 2>&1 && os_python_probe python3; then
    OS_PY=(python3); return 0
  fi
  if command -v python > /dev/null 2>&1 && os_python_probe python; then
    OS_PY=(python); return 0
  fi
  if command -v py > /dev/null 2>&1 && os_python_probe py -3; then
    OS_PY=(py -3); return 0
  fi
  return 1
}

# os_python_cmd -> imprime el comando de Python 3 (`python3`, `python` o `py -3`); sin Python 3 no
# imprime nada y sale 1. Para mostrarlo y para los evals; para correrlo, `os_py`.
os_python_cmd() {
  ( os_python_find && printf '%s' "${OS_PY[*]}" )
}

# os_py ARGS... -> corre Python 3 con ARGS (stdin y stdout pasan tal cual). Sale 127 sin escribir
# nada si no hay Python 3. Busca una vez por proceso. Fuerza UTF-8 en la entrada y la salida: el Python
# nativo de Windows usa la página de códigos ANSI en los pipes, que corrompe nombres de archivo con
# tildes y rompe con `→` o emoji.
os_py() {
  if [ "${#OS_PY[@]}" -eq 0 ]; then
    os_python_find || return 127
  fi
  PYTHONIOENCODING=utf-8 PYTHONUTF8=1 "${OS_PY[@]}" "$@"
}

# El nombre del archivo de permisos del harness, relativo al brain (spec 030). Python 3 lo lee y
# escribe (`os_py`); `mount-repo.sh` lo busca antes de escribir y frena sin él (spec 080).
OS_SETTINGS_ARCHIVO=".claude/settings.local.json"

# os_settings_authorize BRAIN RUTA
# Deja RUTA (absoluta) declarada en `permissions.additionalDirectories` de
# `<BRAIN>/.claude/settings.local.json` — el mecanismo que el harness lee para tratar otro
# directorio como el de trabajo: lectura sin prompt, edición según el modo vigente (doc de
# permisos de Claude Code, sección "Working directories"). Preserva byte a byte, por valor
# parseado, cualquier otra clave que el archivo ya traiga.
#   0  la agregó (el archivo pudo nacer o ya existir)
#   1  ya estaba
#   2  el archivo existe y no es JSON válido — no se tocó
#   9  Python falló por otra razón (una excepción, no haber Python): nada se puede dar por autorizado
os_settings_authorize() {
  local brain="$1" ruta="$2" archivo
  archivo="$brain/$OS_SETTINGS_ARCHIVO"
  mkdir -p "$(dirname "$archivo")" 2>/dev/null
  os_py - "$archivo" "$ruta" <<'PY'
import json
import os
import sys

archivo, ruta = sys.argv[1], sys.argv[2]
data = {}
if os.path.exists(archivo):
    with open(archivo, "r", encoding="utf-8") as f:
        crudo = f.read()
    if crudo.strip():
        try:
            data = json.loads(crudo)
        except ValueError:
            sys.exit(2)
        if not isinstance(data, dict):
            sys.exit(2)

permisos = data.setdefault("permissions", {})
if not isinstance(permisos, dict):
    sys.exit(2)
directorios = permisos.setdefault("additionalDirectories", [])
if not isinstance(directorios, list):
    sys.exit(2)
if ruta in directorios:
    sys.exit(10)
directorios.append(ruta)

with open(archivo, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")
sys.exit(0)
PY
  local rc=$?
  # Dentro de Python, 10 es «ya estaba»: un `exit 1` es el de una excepción sin atrapar, y no puede
  # leerse como «ya autorizado».
  case "$rc" in
    0|2) return "$rc" ;;
    10) return 1 ;;
    *) return 9 ;;
  esac
}

# os_now_ms -> milisegundos desde epoch.
# `date +%s%N` es de GNU; el `date` de macOS devuelve la N literal. Cuando la salida no es toda
# dígitos, se cae a segundos enteros: el cronometraje pierde la décima, no la corrida.
os_now_ms() {
  local t
  t=$(date +%s%N 2>/dev/null)
  case "$t" in
    ''|*[!0-9]*)
      t=$(date +%s 2>/dev/null)
      printf '%s000' "${t:-0}"
      return 0
      ;;
  esac
  if [ "${#t}" -gt 6 ]; then
    printf '%s' "${t%??????}"
  else
    printf '0'
  fi
}

# os_elapsed MS_INICIO MS_FIN -> "X.Xs"
os_elapsed() {
  local d
  d=$(( $2 - $1 ))
  [ "$d" -ge 0 ] || d=0
  printf '%s.%ss' "$(( d / 1000 ))" "$(( (d % 1000) / 100 ))"
}
