#!/usr/bin/env bash
# Funciones compartidas por los comandos de core/. Interno: no es invocable.
# Bash 3.2 en adelante. Sin dependencias fuera de bash + coreutils, con una excepción: `python3`
# —requisito duro del producto junto a `git`, spec 030— lo usa `os_settings_authorize` para leer y
# escribir JSON.

# Tope de identidad, en líneas. Única enunciación del número en el código distribuido.
OS_IDENTITY_CAP=40

# Separador de campos de los registros internos: nunca aparece en un archivo del operador.
OS_SEP=$(printf '\037')

# El vocabulario de `status:` es el del esquema de iniciativa. Única enunciación de las dos listas:
# las consumen el arranque de sesión y los barridos globales. Con una lista por lector, la misma
# cabeza queda cerrada para uno y activa para el otro, y el operador ve dos respuestas distintas
# sobre el mismo archivo.
OS_ESTADOS_VALIDOS="active blocked ongoing closed"
OS_ESTADOS_CERRADOS="closed"

# Los archivos propios de un nodo organización, sin la cabeza: las preguntas canónicas del nodo, más
# el backlog. Todo lo demás que un glob alcance adentro de la carpeta de un espacio de trabajo es una
# cabeza de iniciativa. Se enuncia acá una sola vez: los dos lectores —arranque de sesión y barridos
# globales— tienen que contestar lo mismo sobre el mismo archivo, y una tercera copia se
# desincroniza en la primera pregunta canónica que nazca.
#
# La cabeza no está en la lista porque su nombre es dato del brain (spec 040): la suma
# `os_org_propios`, leyéndolo del árbol. Esta lista es además el negativo con el que `os_head_file`
# reconoce la cabeza entre los globs de la altura del espacio de trabajo.
OS_NODE_CANONICOS="resolver.md backlog.md decisions.md learnings.md"

# Los archivos propios de la raíz como nodo (spec 018): sus preguntas canónicas, más el backlog. La
# raíz no tiene cabeza propia —esa identidad es `operator.md`, que ya se lee siempre— así que la
# lista es la de arriba más los archivos que ya vivían sueltos en la raíz (`operator.md`,
# `inbox.md`, `mounts.md`). Todo lo demás que un `glob:` alcance fuera de la carpeta de espacios de
# trabajo es una cabeza de iniciativa de la raíz.
OS_ROOT_PROPIOS="operator.md resolver.md inbox.md mounts.md backlog.md decisions.md learnings.md"

# La etiqueta que agrupa el trabajo propio de la raíz en los barridos globales (spec 018). Nunca
# puede ser un slug real: `os_slugify` solo produce alfanumérico en minúscula y guiones, y esta
# etiqueta lleva paréntesis y una tilde. Es la misma razón por la que los scripts de ámbito único
# (`session-start.sh`, `capture.sh`, `close-session.sh`) usan un flag `--root` separado en vez de un
# valor reservado de `--org`: un valor de texto siempre puede colisionar con lo que alguien nombre.
OS_ROOT_LABEL="(raíz)"

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
  fm_read "$1/operator.md"
  if [ -n "$fm_language" ] && os_language_valido "$fm_language"; then
    printf '%s' "$fm_language"
  else
    if [ -n "$fm_language" ]; then
      os_warn "operator.md — language: $fm_language is not supported: falling back to en"
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

# os_manual_file IDIOMA -> el nombre del manual de usuario en ese idioma (spec 022).
# Única enunciación del par idioma → nombre de archivo: lo leen el bootstrap, el enlazador y los
# evals. El nombre es legible para quien no programa, en el idioma del manual — el archivo se ve en
# la raíz del brain, al lado de lo que el operador escribe.
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
fm_depends_on=""; fm_repo=""; fm_language=""
fm_roto=""

fm_limpiar() {
  fm_status=""; fm_horizon=""; fm_waiting_on=""; fm_blocked=""; fm_role=""; fm_owner=""
  fm_depends_on=""; fm_repo=""; fm_language=""
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
    key=$(os_trim "${line%%:*}")
    value=$(os_trim "${line#*:}")
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
  [ -f "$brain/tree.md" ] || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      glob:*) ;;
      *) continue ;;
    esac
    g=$(os_trim "${line#glob:}")
    [ -n "$g" ] || continue
    ( cd "$brain" && for f in $g; do [ -e "$f" ] && printf '%s\n' "$f"; done )
  done < "$brain/tree.md"
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
  [ -f "$brain/tree.md" ] || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      content:*) ;;
      *) continue ;;
    esac
    g=$(os_trim "${line#content:}")
    [ -n "$g" ] || continue
    ( cd "$brain" && for f in $g; do [ -e "$f" ] && printf '%s\n' "$f"; done )
  done < "$brain/tree.md"
  return 0
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
  [ -f "$brain/tree.md" ] || return 1
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
  done < "$brain/tree.md"
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
      "$wsdir"/*/"$t"/*/"$head"|"$wsdir"/*/"$t"/*/resolver.md|"$wsdir"/*/"$t"/*/decisions.md)
        return 0 ;;
    esac
  done
  for t in $types_root; do
    case "$f" in
      "$t"/*/"$head"|"$t"/*/resolver.md|"$t"/*/decisions.md) return 0 ;;
    esac
  done
  return 1
}

# os_tree_ensure BRAIN GLOB [CLASE]
# Deja declarado el glob en `tree.md` si faltaba. Es la contracara de que los archivos de solo
# contenido nazcan con su primer dato: el archivo aparece y ningún glob lo alcanza hasta que el
# comando que lo creó declara su altura. Los globs los mantienen los comandos que crean niveles.
# CLASE es `glob` (default, una cabeza) o `content` (alcanzado, nunca leído como cabeza — spec 007).
# El manual de usuario entra por `content` (spec 022): se ve en la raíz y no es trabajo.
#   0  lo agregó       1  ya estaba       2  no hay tree.md que mantener
os_tree_ensure() {
  local brain="$1" glob="$2" clase="${3:-glob}" line g
  [ -f "$brain/tree.md" ] || return 2
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      "$clase":*) ;;
      *) continue ;;
    esac
    g=$(os_trim "${line#$clase:}")
    [ "$g" = "$glob" ] && return 1
  done < "$brain/tree.md"
  printf '%s: %s\n' "$clase" "$glob" >> "$brain/tree.md"
  return 0
}

# os_buscar_oficio BRAIN SLUG -> la ruta del archivo con `command: SLUG`, relativa al brain, por
# stdout. Exit 0 si lo encontró, 1 si no. Único buscador (spec 009): la mitad negativa del arranque
# de sesión (el aviso "capacidad no instalada") y la positiva (nombrar la ruta del oficio activo)
# leen del mismo lugar — dos copias de este recorrido se desincronizan la primera vez que cambie
# dónde vive un oficio.
#
# Busca en `.os/core/skills`, `.os/packs/*/skills` y `.claude/skills`, la marca en primera columna:
# `command: SLUG` en el frontmatter de un `.md`, `# command: SLUG` en un script — el mismo
# vocabulario que declara un invocable en toda la arquitectura. Se queda con el primer archivo que
# matchea.
#
# `.claude/skills` es donde el CLI de skills.sh deja un pack bajado por `npx skills add` (spec 026),
# y ahí la marca del formato Agent Skills es `name:`, no `command:` — el generador del release la
# escribe desde el mismo `command:` del fuente. Sin este origen, un `role:` de un oficio del pack
# se reporta como capacidad no instalada con el oficio instalado al lado.
#
# La coincidencia es sin distinción de mayúsculas (spec personal-os#014, Gate 1): `role: CPO` en el
# nodo activa `command: cpo` del oficio. El slug canónico del archivo sigue siendo minúscula; acá
# se normaliza el slug de entrada con `os_lower` y se busca con `grep -i`.
os_buscar_oficio() {
  local brain="$1" slug="$2" d f rel slug_lc marca
  slug_lc=$(os_lower "$slug")
  for d in "$brain/.os/core/skills" "$brain"/.os/packs/*/skills "$brain/.claude/skills"; do
    [ -d "$d" ] || continue
    # La marca depende del origen, no del archivo: `name:` solo se acepta donde el formato es el del
    # CLI. Aceptarla en todos lados volvería invocable cualquier frontmatter con esa clave.
    case "$d" in
      "$brain/.claude/skills") marca="^(# )?name: $slug_lc\$" ;;
      *) marca="^(# )?command: $slug_lc\$" ;;
    esac
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      if grep -qiE "$marca" "$f"; then
        rel="${f#$brain/}"
        printf '%s\n' "$rel"
        return 0
      fi
    done <<FILES
$(find "$d" -type f | sort)
FILES
  done
  return 1
}

# os_pack_hint BRAIN -> el ofrecimiento del pack en una línea, o vacío.
# La demanda dispara la oferta (spec 029): cuando algo pide una capacidad que no está y en el brain
# no hay ningún skill instalado por el CLI, lo que falta puede ser justamente lo que trae el pack, y
# el aviso lleva el comando al lado en vez de dejar al operador buscándolo.
#
# Con algo ya instalado en `.claude/skills` no se ofrece nada: ahí el pack está, y lo que falte es
# otro problema — ofrecer una instalación hecha es ruido en cada arranque.
#
# El comando exacto lo imprime `pack-install.sh --line`, único lugar donde el generador inyecta el
# nombre del repo del pack. Sin ese archivo —un brain instalado desde una versión anterior— la
# función no dice nada: un aviso que no puede nombrar el comando no agrega información.
os_pack_hint() {
  local brain="$1" d linea
  for d in "$brain"/.claude/skills/*/SKILL.md; do
    [ -f "$d" ] && return 0
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

# os_backlog_asegurar BRAIN ORG
# Deja existiendo el `backlog.md` de la organización y declarado su glob. Un archivo de solo
# contenido nace con su primer dato, no con el bootstrap.
#   0  ya estaba       1  nació con este dato
os_backlog_asegurar() {
  local brain="$1" org="$2" file titulo wsdir
  wsdir=$(os_ws_dir "$brain")
  file="$brain/$wsdir/$org/backlog.md"
  [ -f "$file" ] && return 0
  titulo=$(os_titulo "$brain/$wsdir/$org/$(os_head_file "$brain" || true)")
  [ -n "$titulo" ] || titulo="$org"
  os_backlog_cabecera "$brain" "$titulo" > "$file"
  return 1
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

# os_root_backlog_asegurar BRAIN
# Deja existiendo `backlog.md` en la raíz del brain y declarado su glob. Mismo criterio que
# `os_backlog_asegurar`, para el nodo del operador: el título sale del nombre en `operator.md`, no de
# una cabeza de nodo que la raíz no tiene.
#   0  ya estaba       1  nació con este dato
os_root_backlog_asegurar() {
  local brain="$1" file titulo
  file="$brain/backlog.md"
  [ -f "$file" ] && return 0
  titulo=$(os_titulo "$brain/operator.md")
  [ -n "$titulo" ] || titulo="la raíz"
  os_backlog_cabecera "$brain" "$titulo" > "$file"
  return 1
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
  local tree="$1/tree.md" line
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
  local brain="$1" tree="$1/tree.md" line g base wsdir ws_head="" ini_forma=""
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

# os_fm_set ARCHIVO CLAVE VALOR
# Escribe una clave en el frontmatter de una cabeza sin tocar el cuerpo: reemplaza la que esté o la
# suma antes del `---` de cierre. Exit 1 si el frontmatter no se pudo leer, con el motivo en
# `fm_roto` — escribir sobre un frontmatter que no se entiende es corromper el archivo en silencio.
os_fm_set() {
  local file="$1" key="$2" value="$3" tmp line n=0 primera=1 puesto=0
  fm_read "$file"
  [ -z "$fm_roto" ] || return 1
  tmp="$file.os-tmp"
  : > "$tmp"
  while IFS= read -r line || [ -n "$line" ]; do
    n=$(( n + 1 ))
    if [ "$primera" = "1" ]; then
      primera=0
      printf '%s\n' "$line" >> "$tmp"
      continue
    fi
    if [ "$puesto" = "0" ]; then
      if [ "$line" = "---" ]; then
        printf '%s: %s\n' "$key" "$value" >> "$tmp"
        puesto=1
        printf '%s\n' "$line" >> "$tmp"
        continue
      fi
      case "$line" in
        "$key":*)
          printf '%s: %s\n' "$key" "$value" >> "$tmp"
          puesto=1
          continue
          ;;
      esac
    fi
    printf '%s\n' "$line" >> "$tmp"
  done < "$file"
  mv "$tmp" "$file"
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
OS_MOUNTS_ARCHIVO="mounts.md"

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

# El nombre del archivo de permisos del harness, relativo al brain (spec 030). `python3` lo lee y
# escribe: es requisito duro del producto junto a `git` desde la spec 030 (en macOS los dos llegan
# con las mismas Command Line Tools; `bootstrap.sh` y `mount-repo.sh` lo chequean antes de escribir).
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
os_settings_authorize() {
  local brain="$1" ruta="$2" archivo
  archivo="$brain/$OS_SETTINGS_ARCHIVO"
  mkdir -p "$(dirname "$archivo")" 2>/dev/null
  python3 - "$archivo" "$ruta" <<'PY'
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
    sys.exit(1)
directorios.append(ruta)

with open(archivo, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")
sys.exit(0)
PY
  return $?
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
