#!/usr/bin/env bash
# Parte determinística de `close-session`: distribuye lo que dejó la sesión y devuelve el veredicto.
# Las dos preguntas las hace core/skills/close-session.md. Interno: no es invocable.
#
# Uso: close-session.sh --brain DIR --org SLUG --material ARCHIVO
#                       [--session-org SLUG] [--load-context]
#      close-session.sh --brain DIR --workspace SLUG --material ARCHIVO
#                       [--session-org SLUG] [--load-context]
#      close-session.sh --brain DIR --root --material ARCHIVO
#
# `--workspace` es sinónimo exacto de `--org` (spec 039). Con `--root` distribuye a los canónicos
# de la raíz (spec 018) en vez de a los de una organización: `backlog.md`, `decisions.md`,
# `learnings.md` y la cabeza de la iniciativa, todos en la raíz del brain. `--org`/`--workspace` y
# `--root` son excluyentes, y la raíz no exige `--session-org` ni `--load-context` — su identidad
# (`operator.md`) ya está cargada en cualquier sesión.
#
# Formato del material — una clave por línea, `clave: valor`.
#
# **Ningún campo de texto libre va antes de un campo estructural.** Después de la clave hay a lo sumo
# UN campo estructural, terminado en `|`, y el texto libre es siempre lo último: se queda con todo el
# resto de la línea, pipes incluidos. Con el texto libre primero, "cuerpo con un | pipe adentro"
# archivaba "cuerpo con un" y el veredicto lo declaraba capturado — pérdida silenciosa, que es
# exactamente lo que este comando existe para evitar.
#
#   decision:      Título
#     what:        Qué se decide
#     why:         Por qué
#     replaces:    Qué decisión reemplaza          (opcional)
#     invalidates: Qué la haría falsa              (opcional)
#   learning:      Título
#     body:        El cuerpo
#   provisional:   Título                          el intento sin conclusión, el "casi funcionó"
#     body:        El cuerpo
#   pending:       Texto de la tarea               al backlog de la organización
#   pending-from:  iniciativa | Texto de la tarea  lo mismo, atribuido a la iniciativa que lo dejó
#   waiting:       iniciativa | quién destraba     escribe `waiting_on:` en el frontmatter de esa cabeza
#   unrouted:      destino | contenido             escritura decidida sin fila del resolver
#   not-captured:  Texto                           lo que la sesión no pudo archivar
#   touched:       Ruta relativa al ámbito         archivo que la sesión modificó a mano, para commitear
#   resume:        Texto                           el puntero de reanudación
#
# Keys in English since spec 033 (the 15-key catalog, spec's own criterion) — the script still
# accepts the old Spanish ones (que/porque/reemplaza/invalidaria/cuerpo/pending-de/sin-fila/
# no-capturado/tocado/retomar) during this version, and the verdict notes "old key: <es> → <en>"
# once per old key used.
#
# Un registro se cierra cuando empieza el siguiente o cuando termina el archivo. Una clave que no
# corresponde al registro abierto no se adivina: se declara en el veredicto.
# Las líneas vacías y las que empiezan con `#` se ignoran.
#
# El cierre commitea lo que escribió más lo que el material declaró con `touched:`, y solo eso —
# nunca `git add -A`: una sesión no barre lo que otra tiene a medias. Una ruta de `touched:` que no
# existe o no está modificada no rompe el cierre: se declara en "No capturado" y el resto se
# commitea igual. Sin repo git en el brain, el cierre reparte igual y no intenta commitear nada.
#
# El veredicto es siempre el mismo: qué se capturó, qué NO se capturó, la fila candidata para el
# resolver, qué quedó sin commitear por no ser de esta sesión, y el puntero para retomar.
# Nunca "listo" a secas — un cierre que solo dice que terminó no se distingue de uno que perdió algo.
#
# Exit: 0 cerró · 2 la organización no existe · 3 escritura cross-nodo sin el context cargado.

set -u

here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"

t_inicio=$(os_now_ms)

nl=$(printf '\nx')
nl="${nl%x}"

brain=""
org=""
workspace=""
root=0
material=""
session_org=""
load_context=0

while [ $# -gt 0 ]; do
  case "$1" in
    --brain) brain="${2:-}"; shift 2 ;;
    --org) org="${2:-}"; shift 2 ;;
    --workspace) workspace="${2:-}"; shift 2 ;;
    --root) root=1; shift ;;
    --material) material="${2:-}"; shift 2 ;;
    --session-org) session_org="${2:-}"; shift 2 ;;
    --load-context) load_context=1; shift ;;
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
  [ -z "$org" ] || os_die "--root y --org/--workspace son excluyentes"
else
  [ -n "$org" ] || os_die "falta --org, --workspace o --root"
fi
[ -n "$material" ] || os_die "falta --material"
[ -d "$brain" ] || os_die "no existe el brain: $brain"
[ -f "$material" ] || os_die "no existe el material de la sesión: $material"
brain=$(cd "$brain" && pwd)

# Layout inválido frena acá, antes de cualquier $(...) que arme una ruta con el nombre de la
# carpeta (P2, spec 039).
os_ws_check "$brain"
wsdir=$(os_ws_dir "$brain")
# La forma de la cabeza, leída del árbol (spec 040).
head=$(os_head_file "$brain") || true

# Only the "old key" note goes through the bilingual catalog (spec 033) — the rest of the verdict
# stays in Spanish: that is not what this spec asked to translate.
os_lang_load "$(os_language "$brain")" > /dev/null 2>&1

if [ "$root" = "0" ] && ! os_org_existe "$brain" "$org"; then
  printf 'la organización "%s" no existe. Las que hay:\n' "$org" >&2
  slugs=$(os_org_slugs "$brain")
  if [ -n "$slugs" ]; then
    printf '%s\n' "$slugs" | while IFS= read -r s; do printf '  %s\n' "$s" >&2; done
  else
    printf '  (ninguna)\n' >&2
  fi
  exit 2
fi

# Escribir en un nodo cuyo `context` no está cargado exige cargarlo primero o negarse. El cierre
# escribe en los canónicos del nodo: es la escritura más cara de mandar al lugar equivocado.
#
# La raíz no tiene este candado: su identidad (`operator.md`) está cargada en cualquier sesión, a
# cualquier ámbito — no hay `context` cross-nodo que custodiar.
#
# `orgprefix` es la única diferencia de ruta entre los dos ámbitos: "<wsdir>/<slug>/" para una
# organización, vacío para la raíz. Todo lo que sigue arma sus rutas con este prefijo en vez de
# repetir el condicional en cada canónico.
if [ "$root" = "1" ]; then
  orgprefix=""
  ambito_nombre="raíz"
else
  orgprefix="$wsdir/$org/"
  ambito_nombre="$org"
  ctx="${orgprefix}$head"
  res="${orgprefix}resolver.md"
  if [ "$session_org" != "$org" ]; then
    if [ "$load_context" = "0" ]; then
      printf 'escritura cross-nodo: la sesión está parada en "%s" y el cierre escribe en "%s".\n' \
        "${session_org:-(ningún ámbito declarado)}" "$org" >&2
      printf 'no se escribió nada. Cargá primero %s y %s, y repetí con --load-context.\n' \
        "$ctx" "$res" >&2
      exit 3
    fi
    printf 'context cargado antes de escribir en "%s":\n' "$org"
    for f in "$ctx" "$res"; do
      if [ -f "$brain/$f" ]; then
        printf -- '--- %s\n' "$f"
        cat "$brain/$f"
      else
        printf -- '--- %s: no está — se cierra degradado y se dice\n' "$f"
      fi
    done
    printf -- '---\n\n'
  fi
fi

hoy=$(date +%Y-%m-%d)

capturado=""
no_capturado=""
candidatas=""
puntero=""
n_piezas=0

# Las rutas que el script mismo escribió, más las de `touched:` una vez validadas. Es lo único que el
# cierre commitea — nunca se recomputa desde `git status` al final: eso confundiría una edición
# ajena a un canónico con una propia. Se acumula a medida que cada escritura pasa.
escritos=""
tocado_rutas=""
# Old Spanish keys used in this close (spec 033) — each one is noted only once in the verdict, even
# if the material used it on several lines.
old_keys=""

push_capturado() { capturado="$capturado  $1$nl"; n_piezas=$(( n_piezas + 1 )); }
push_no_capturado() { no_capturado="$no_capturado  $1$nl"; }
push_candidata() { candidatas="$candidatas  $1$nl"; }
push_tocado() { tocado_rutas="$tocado_rutas$1$nl"; }
mark_old_key() {
  # mark_old_key OLD NEW
  local linea
  linea=$(printf "  $S_OLD_KEY_LINE" "$1" "$2")
  case "$nl$old_keys$nl" in
    *"$nl$linea$nl"*) return 0 ;;
  esac
  old_keys="$old_keys$linea$nl"
}
marcar_escrito() {
  case "$nl$escritos" in
    *"$nl$1$nl"*) return 0 ;;
  esac
  escritos="$escritos$1$nl"
}

declarar_glob() {
  os_tree_ensure "$brain" "$1"
  case "$?" in
    0) push_capturado "tree.md — glob declarado: $1"; marcar_escrito "tree.md" ;;
    2) push_no_capturado "falta tree.md — el glob \"$1\" quedó sin declarar" ;;
  esac
}

# ---------------------------------------------------------------- los canónicos del nodo
# Un archivo que solo guarda contenido nace con su primer dato. `decisions` y `learnings` son dos de
# las cinco preguntas del nodo: en un nodo carpeta, cada una es su archivo. Con `--root` son dos de
# las cuatro preguntas propias de la raíz (spec 018) — mismo formato, sin `<wsdir>/<slug>/` adelante.
nace_canonico() {
  # nace_canonico ARCHIVO TITULO SUBTITULO
  local file="$brain/${orgprefix}$1" glob
  [ -f "$file" ] && return 0
  {
    printf '# %s\n\n' "$2"
    printf '%s\n\n' "$3"
  } > "$file"
  push_capturado "${orgprefix}$1 nació con su primer dato"
  if [ "$root" = "1" ]; then glob="$1"; else glob="$wsdir/*/$1"; fi
  declarar_glob "$glob"
  return 0
}

escribir_decision() {
  # escribir_decision TITULO QUE PORQUE REEMPLAZA INVALIDARIA
  local file="$brain/${orgprefix}decisions.md"
  nace_canonico "decisions.md" "Decisiones" \
    "Registro append-only. Nunca se corrige: si una decisión cambia, se agrega otra que la reemplaza y la nombra."
  {
    printf -- '---\n\n'
    printf '## %s · %s\n\n' "$hoy" "$1"
    printf '**Qué se decide**: %s\n\n' "$2"
    printf '**Por qué**: %s\n\n' "$3"
    [ -n "$4" ] && printf '**Reemplaza a**: %s\n\n' "$4"
    [ -n "$5" ] && printf '**La invalidaría**: %s\n\n' "$5"
  } >> "$file"
  push_capturado "decisión → ${orgprefix}decisions.md: $1"
  marcar_escrito "${orgprefix}decisions.md"
}

escribir_learning() {
  # escribir_learning TITULO CUERPO STATUS
  local file="$brain/${orgprefix}learnings.md"
  nace_canonico "learnings.md" "Aprendizajes" \
    "Vivo: se actualiza o se borra. Lo que se intentó y no cerró queda con status: provisional, para que nadie lo reintente sin saberlo."
  {
    printf -- '---\n\n'
    printf '## %s · %s\n\n' "$hoy" "$1"
    # Solo el intento sin conclusión lleva marca. Un aprendizaje cerrado no necesita estado, y
    # ponerle uno inventaría un vocabulario que el esquema no tiene.
    [ "$3" = "provisional" ] && printf 'status: provisional\n\n'
    printf '%s\n\n' "$2"
  } >> "$file"
  if [ "$3" = "provisional" ]; then
    push_capturado "intento sin conclusión → ${orgprefix}learnings.md (status: provisional): $1"
  else
    push_capturado "aprendizaje → ${orgprefix}learnings.md: $1"
  fi
  marcar_escrito "${orgprefix}learnings.md"
}

# ---------------------------------------------------------------- el material
# Un registro se acumula hasta que empieza el siguiente. `r_tipo` dice cuál está abierto: una clave
# de continuación que no corresponde no se adivina, se declara.
r_tipo=""; r_titulo=""; r_que=""; r_porque=""; r_reemplaza=""; r_invalidaria=""; r_cuerpo=""

cerrar_registro() {
  case "$r_tipo" in
    '') return 0 ;;
    decision)
      if [ -z "$r_que" ]; then
        push_no_capturado "decisión sin qué se decide, no se archivó: $r_titulo"
      else
        escribir_decision "$r_titulo" "$r_que" "$r_porque" "$r_reemplaza" "$r_invalidaria"
      fi
      ;;
    learning) escribir_learning "$r_titulo" "$r_cuerpo" "activo" ;;
    provisional) escribir_learning "$r_titulo" "$r_cuerpo" "provisional" ;;
  esac
  r_tipo=""; r_titulo=""; r_que=""; r_porque=""; r_reemplaza=""; r_invalidaria=""; r_cuerpo=""
  return 0
}

# continuacion CLAVE TIPO_ESPERADO... -> 0 si el registro abierto la admite.
continuacion_valida() {
  local clave="$1" t
  shift
  for t in "$@"; do
    [ "$r_tipo" = "$t" ] && return 0
  done
  push_no_capturado "\"$clave\" sin un registro que la admita, no se archivó"
  return 1
}

while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in
    ''|'#'*) continue ;;
  esac
  case "$line" in
    *:*) ;;
    *) push_no_capturado "línea sin clave, no se archivó: $line"; continue ;;
  esac
  key=$(os_trim "${line%%:*}")
  # El valor se queda con TODO el resto de la línea. Lo estructural, si hay, se corta después: es un
  # solo campo y termina en `|`, así que el texto libre nunca se parte.
  value=$(os_trim "${line#*:}")

  # Single old -> new table (spec 033), resolved here before the case: from here down the whole
  # script only ever sees the English key. One place that knows about the ten old keys, instead of
  # repeating "am I the old form?" in every arm.
  case "$key" in
    que) mark_old_key "que" "what"; key="what" ;;
    porque) mark_old_key "porque" "why"; key="why" ;;
    reemplaza) mark_old_key "reemplaza" "replaces"; key="replaces" ;;
    invalidaria) mark_old_key "invalidaria" "invalidates"; key="invalidates" ;;
    cuerpo) mark_old_key "cuerpo" "body"; key="body" ;;
    pending-de) mark_old_key "pending-de" "pending-from"; key="pending-from" ;;
    sin-fila) mark_old_key "sin-fila" "unrouted"; key="unrouted" ;;
    no-capturado) mark_old_key "no-capturado" "not-captured"; key="not-captured" ;;
    tocado) mark_old_key "tocado" "touched"; key="touched" ;;
    retomar) mark_old_key "retomar" "resume"; key="resume" ;;
  esac

  case "$key" in
    decision|learning|provisional)
      cerrar_registro
      if [ -z "$value" ]; then
        push_no_capturado "$key sin título, no se archivó"
        continue
      fi
      r_tipo="$key"
      r_titulo="$value"
      ;;

    what)    continuacion_valida "$key" decision && r_que="$value" ;;
    why)     continuacion_valida "$key" decision && r_porque="$value" ;;
    replaces)    continuacion_valida "$key" decision && r_reemplaza="$value" ;;
    invalidates) continuacion_valida "$key" decision && r_invalidaria="$value" ;;
    body)    continuacion_valida "$key" learning provisional && r_cuerpo="$value" ;;

    pending|pending-from)
      cerrar_registro
      texto="$value"
      if [ "$key" = "pending-from" ]; then
        # El único campo estructural va primero y termina en `|`; el texto libre se queda con el
        # resto, pipes incluidos. Sin el separador no se adivina cuál es cuál: se declara.
        case "$value" in
          *'|'*) ;;
          *) push_no_capturado "pendiente sin el separador de la iniciativa: $value"; continue ;;
        esac
        IFS='|' read -r ini texto <<CAMPOS
$value
CAMPOS
        ini=$(os_trim "$ini")
        texto=$(os_trim "$texto")
        [ -n "$ini" ] && texto="($ini) $texto"
      fi
      if [ -z "$texto" ]; then push_no_capturado "pendiente sin texto"; continue; fi
      # Archivar una tarea suelta ya es `capture`: el cierre la llama en vez de repetir su escritura.
      # La raíz no manda `--session-org`: capture.sh nunca la pide para su propio ámbito.
      if [ "$root" = "1" ]; then
        salida=$("$here/capture.sh" --brain "$brain" --root --text "$texto" 2>&1)
      else
        salida=$("$here/capture.sh" --brain "$brain" --org "$org" --session-org "$org" \
                 --text "$texto" 2>&1)
      fi
      rc=$?
      if [ "$rc" = "0" ]; then
        detalle=$(os_trim "$(printf '%s\n' "$salida" | grep 'backlog.md — ' | head -1)")
        push_capturado "pendiente → $detalle"
        if [ "$root" = "1" ]; then marcar_escrito "backlog.md"; else marcar_escrito "$wsdir/$org/backlog.md"; fi
      else
        push_no_capturado "pendiente no archivado: $texto"
      fi
      ;;

    waiting)
      # `waiting_on:` no es un campo nuevo: es el del esquema, y lo escriben estas herramientas
      # cuando el operador queda esperando algo. El valor dice quién destraba.
      cerrar_registro
      case "$value" in
        *'|'*) ;;
        *) push_no_capturado "espera sin el separador de la iniciativa: $value"; continue ;;
      esac
      IFS='|' read -r ini quien <<CAMPOS
$value
CAMPOS
      ini=$(os_trim "$ini")
      quien=$(os_trim "$quien")
      if [ -z "$ini" ] || [ -z "$quien" ]; then
        push_no_capturado "espera sin iniciativa o sin valor: $value"
        continue
      fi
      cabeza="${orgprefix}$(os_head_path "$brain" initiative "$ini")"
      if [ ! -f "$brain/$cabeza" ]; then
        push_no_capturado "espera no escrita: no existe $cabeza"
        continue
      fi
      if os_fm_set "$brain/$cabeza" "waiting_on" "$quien"; then
        push_capturado "espera → $cabeza: waiting_on: $quien"
        marcar_escrito "$cabeza"
      else
        push_no_capturado "espera no escrita: $cabeza — $fm_roto"
      fi
      ;;

    unrouted)
      # El resolver crece por excepción encontrada, y se ofrece: no se escribe solo. Una fila existe
      # solo si un agente competente adivinaría mal sin ella, y eso lo decide el operador.
      cerrar_registro
      case "$value" in
        *'|'*) ;;
        *) push_no_capturado "fila candidata sin el separador del destino: $value"; continue ;;
      esac
      IFS='|' read -r destino contenido <<CAMPOS
$value
CAMPOS
      destino=$(os_trim "$destino")
      contenido=$(os_trim "$contenido")
      if [ -z "$destino" ] || [ -z "$contenido" ]; then
        push_no_capturado "fila candidata incompleta: $value"
        continue
      fi
      push_candidata "| $contenido | \`$destino\` |"
      ;;

    not-captured)
      cerrar_registro
      push_no_capturado "$value"
      ;;

    touched)
      # Se valida recién al commitear, no acá: existir y estar modificada dependen del estado del
      # árbol al final del reparto, no de este punto de la lectura.
      cerrar_registro
      if [ -z "$value" ]; then
        push_no_capturado "$key sin ruta, no se archivó"
        continue
      fi
      push_tocado "$value"
      ;;

    resume)
      cerrar_registro
      puntero="$value"
      ;;

    *)
      cerrar_registro
      push_no_capturado "clave desconocida, no se archivó: $key"
      ;;
  esac
done < "$material"
cerrar_registro

# ---------------------------------------------------------------- el puntero de reanudación
# Una línea, greppeable, que la próxima sesión pueda leer sin contexto. Vive en el backlog del nodo
# —lo que ya contesta "qué falta"— y hay una sola: la última pisa a la anterior. No lleva checkbox,
# así que no cuenta como tarea en ningún conteo.
if [ -n "$puntero" ]; then
  nacio=0
  if [ "$root" = "1" ]; then
    os_root_backlog_asegurar "$brain" || nacio=1
    glob="backlog.md"
  else
    os_backlog_asegurar "$brain" "$org" || nacio=1
    glob="$wsdir/*/backlog.md"
  fi
  backlog="$brain/${orgprefix}backlog.md"
  tmp="$backlog.os-tmp"
  : > "$tmp"
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      'retomar: '*) continue ;;
    esac
    printf '%s\n' "$line" >> "$tmp"
  done < "$backlog"
  mv "$tmp" "$backlog"
  printf 'retomar: %s (%s)\n' "$puntero" "$hoy" >> "$backlog"
  [ "$nacio" = "1" ] && push_capturado "${orgprefix}backlog.md nació con este dato"
  marcar_escrito "${orgprefix}backlog.md"
  declarar_glob "$glob"
fi

# ---------------------------------------------------------------- el commit del cierre
# El cierre commitea lo que escribió más lo que el material declaró con `tocado:` — nunca
# `git add -A`, para que esta sesión no barra lo que otra tiene a medias. Lo que quede afuera se
# nombra, nunca se toca. El script no configura identidad de git del operador: si el commit falla
# por eso o por un hook del brain, no se hace bypass — se declara y el cierre sigue en 0.
#
# `os_git_sucio` es el mismo lector que usa `session-start.sh` para Chequeos (spec 031): una segunda
# forma de leer `git status --porcelain` acá sería la desincronización que este repo ya prohíbe.
sin_commitear=""
commit_error=""
push_sin_commitear() { sin_commitear="$sin_commitear  $1$nl"; }

if sucios=$(os_git_sucio "$brain"); then es_git=1; else es_git=0; fi

esta_sucio() {
  # esta_sucio RUTA -> 0 si esa ruta aparece en la foto de `git status` ya leída.
  case "$nl$sucios$nl" in
    *"$nl$1$nl"*) return 0 ;;
    *) return 1 ;;
  esac
}

if [ "$es_git" = "1" ]; then
  if [ -n "$tocado_rutas" ]; then
    # `tocado:` se declara relativo al ámbito —igual que `roles/linkedin.md` en el ejemplo de la
    # spec—, la misma convención que ya usa cada canónico (`${orgprefix}decisions.md`, etc.): acá
    # también hay que anteponer `orgprefix` para llegar a la ruta real desde la raíz del brain.
    while IFS= read -r ruta || [ -n "$ruta" ]; do
      [ -n "$ruta" ] || continue
      full="${orgprefix}$ruta"
      if [ ! -e "$brain/$full" ]; then
        push_no_capturado "tocado: $full — no existe, no se commiteó"
        continue
      fi
      if ! esta_sucio "$full"; then
        push_no_capturado "tocado: $full — no está modificada, no se commiteó"
        continue
      fi
      marcar_escrito "$full"
    done <<TOCADO
$tocado_rutas
TOCADO
  fi

  if [ -n "$escritos" ]; then
    while IFS= read -r ruta || [ -n "$ruta" ]; do
      [ -n "$ruta" ] || continue
      git -C "$brain" add -- "$ruta" > /dev/null 2>&1
    done <<ESCRITOS
$escritos
ESCRITOS

    if ! git -C "$brain" diff --cached --quiet 2>/dev/null; then
      primera_linea="Cierre de sesión — $ambito_nombre"
      if [ -n "$puntero" ]; then
        commit_msg="$primera_linea: $puntero"
      else
        commit_msg="$primera_linea"
      fi
      commit_salida=$(git -C "$brain" commit -q -m "$commit_msg" 2>&1)
      if [ "$?" != "0" ]; then
        while IFS= read -r ruta || [ -n "$ruta" ]; do
          [ -n "$ruta" ] || continue
          git -C "$brain" reset --quiet -- "$ruta" > /dev/null 2>&1
        done <<ESCRITOS2
$escritos
ESCRITOS2
        commit_error=$(os_trim "$(printf '%s\n' "$commit_salida" | head -1)")
      fi
    fi
  fi

  resto=$(os_git_sucio "$brain")
  while IFS= read -r line || [ -n "$line" ]; do
    [ -n "$line" ] || continue
    push_sin_commitear "$line"
  done <<RESTO
$resto
RESTO
fi

# ---------------------------------------------------------------- el veredicto
printf 'Cierre de sesión — %s\n\n' "$ambito_nombre"

if [ -n "$old_keys" ]; then
  printf '%s\n' "$old_keys"
fi

printf 'Capturado\n'
if [ -z "$capturado" ]; then
  printf '  nada se capturó\n'
else
  printf '%s' "$capturado"
fi

printf '\nNo capturado\n'
if [ -z "$no_capturado" ]; then
  printf '  nada quedó sin capturar\n'
else
  printf '%s' "$no_capturado"
fi

printf '\nFila candidata para el resolver\n'
if [ -z "$candidatas" ]; then
  printf '  ninguna escritura necesitó decidir fuera del resolver\n'
else
  printf '%s' "$candidatas"
  printf '  la escribe el operador en %sresolver.md con un sí — no se escribe sola\n' "$orgprefix"
fi

printf '\nSin commitear (no es de esta sesión)\n'
if [ "$es_git" = "0" ]; then
  printf '  sin repo git: no se commiteó\n'
else
  if [ -n "$commit_error" ]; then
    printf '  no se pudo commitear lo de esta sesión (%s) — revisá identidad de git o el hook del brain\n' \
      "$commit_error"
  fi
  if [ -z "$sin_commitear" ] && [ -z "$commit_error" ]; then
    printf '  nada\n'
  else
    printf '%s' "$sin_commitear"
  fi
fi

printf '\nPara retomar\n'
if [ -z "$puntero" ]; then
  printf '  sin puntero de reanudación: la próxima sesión arranca sin por dónde seguir\n'
else
  printf '  retomar: %s (%s) — escrito en %sbacklog.md\n' "$puntero" "$hoy" "$orgprefix"
fi

t_fin=$(os_now_ms)
printf '\n%s piezas · %s\n' "$n_piezas" "$(os_elapsed "$t_inicio" "$t_fin")"
exit 0
