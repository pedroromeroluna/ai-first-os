#!/usr/bin/env bash
# Parte determinística de `close-session`: distribuye lo que dejó la sesión y devuelve el veredicto.
# Las dos preguntas las hace core/skills/close-session.md. Interno: no es invocable.
#
# Uso: close-session.sh --brain DIR --org SLUG --material ARCHIVO
#                       [--session-org SLUG] [--load-context]
#      close-session.sh --brain DIR --root --material ARCHIVO
#
# Con `--root` distribuye a los canónicos de la raíz (spec 018) en vez de a los de una organización:
# `backlog.md`, `decisions.md`, `learnings.md` y `initiatives/<nombre>.md`, todos en la raíz del
# brain. `--org` y `--root` son excluyentes, y la raíz no exige `--session-org` ni `--load-context` —
# su identidad (`operator.md`) ya está cargada en cualquier sesión.
#
# Formato del material — una clave por línea, `clave: valor`.
#
# **Ningún campo de texto libre va antes de un campo estructural.** Después de la clave hay a lo sumo
# UN campo estructural, terminado en `|`, y el texto libre es siempre lo último: se queda con todo el
# resto de la línea, pipes incluidos. Con el texto libre primero, "cuerpo con un | pipe adentro"
# archivaba "cuerpo con un" y el veredicto lo declaraba capturado — pérdida silenciosa, que es
# exactamente lo que este comando existe para evitar.
#
#   decision:     Título
#     que:        Qué se decide
#     porque:     Por qué
#     reemplaza:  Qué decisión reemplaza          (opcional)
#     invalidaria: Qué la haría falsa             (opcional)
#   learning:     Título
#     cuerpo:     El cuerpo
#   provisional:  Título                          el intento sin conclusión, el "casi funcionó"
#     cuerpo:     El cuerpo
#   pending:      Texto de la tarea               al backlog de la organización
#   pending-de:   iniciativa | Texto de la tarea  lo mismo, atribuido a la iniciativa que lo dejó
#   waiting:      iniciativa | quién destraba     escribe `waiting_on:` en el frontmatter de esa cabeza
#   sin-fila:     destino | contenido             escritura decidida sin fila del resolver
#   no-capturado: Texto                           lo que la sesión no pudo archivar
#   retomar:      Texto                           el puntero de reanudación
#
# Un registro se cierra cuando empieza el siguiente o cuando termina el archivo. Una clave que no
# corresponde al registro abierto no se adivina: se declara en el veredicto.
# Las líneas vacías y las que empiezan con `#` se ignoran.
#
# El veredicto es siempre el mismo: qué se capturó, qué NO se capturó y el puntero para retomar.
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
root=0
material=""
session_org=""
load_context=0

while [ $# -gt 0 ]; do
  case "$1" in
    --brain) brain="${2:-}"; shift 2 ;;
    --org) org="${2:-}"; shift 2 ;;
    --root) root=1; shift ;;
    --material) material="${2:-}"; shift 2 ;;
    --session-org) session_org="${2:-}"; shift 2 ;;
    --load-context) load_context=1; shift ;;
    *) os_die "argumento desconocido: $1" ;;
  esac
done

[ -n "$brain" ] || os_die "falta --brain"
if [ "$root" = "1" ]; then
  [ -z "$org" ] || os_die "--root y --org son excluyentes"
else
  [ -n "$org" ] || os_die "falta --org o --root"
fi
[ -n "$material" ] || os_die "falta --material"
[ -d "$brain" ] || os_die "no existe el brain: $brain"
[ -f "$material" ] || os_die "no existe el material de la sesión: $material"
brain=$(cd "$brain" && pwd)

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
# `orgprefix` es la única diferencia de ruta entre los dos ámbitos: "orgs/<slug>/" para una
# organización, vacío para la raíz. Todo lo que sigue arma sus rutas con este prefijo en vez de
# repetir el condicional en cada canónico.
if [ "$root" = "1" ]; then
  orgprefix=""
  ambito_nombre="raíz"
else
  orgprefix="orgs/$org/"
  ambito_nombre="$org"
  ctx="${orgprefix}context.md"
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

push_capturado() { capturado="$capturado  $1$nl"; n_piezas=$(( n_piezas + 1 )); }
push_no_capturado() { no_capturado="$no_capturado  $1$nl"; }
push_candidata() { candidatas="$candidatas  $1$nl"; }

declarar_glob() {
  os_tree_ensure "$brain" "$1"
  case "$?" in
    0) push_capturado "tree.md — glob declarado: $1" ;;
    2) push_no_capturado "falta tree.md — el glob \"$1\" quedó sin declarar" ;;
  esac
}

# ---------------------------------------------------------------- los canónicos del nodo
# Un archivo que solo guarda contenido nace con su primer dato. `decisions` y `learnings` son dos de
# las cinco preguntas del nodo: en un nodo carpeta, cada una es su archivo. Con `--root` son dos de
# las cuatro preguntas propias de la raíz (spec 018) — mismo formato, sin `orgs/<slug>/` adelante.
nace_canonico() {
  # nace_canonico ARCHIVO TITULO SUBTITULO
  local file="$brain/${orgprefix}$1" glob
  [ -f "$file" ] && return 0
  {
    printf '# %s\n\n' "$2"
    printf '%s\n\n' "$3"
  } > "$file"
  push_capturado "${orgprefix}$1 nació con su primer dato"
  if [ "$root" = "1" ]; then glob="$1"; else glob="orgs/*/$1"; fi
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

    que)         continuacion_valida "que" decision && r_que="$value" ;;
    porque)      continuacion_valida "porque" decision && r_porque="$value" ;;
    reemplaza)   continuacion_valida "reemplaza" decision && r_reemplaza="$value" ;;
    invalidaria) continuacion_valida "invalidaria" decision && r_invalidaria="$value" ;;
    cuerpo)      continuacion_valida "cuerpo" learning provisional && r_cuerpo="$value" ;;

    pending|pending-de)
      cerrar_registro
      texto="$value"
      if [ "$key" = "pending-de" ]; then
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
      cabeza="${orgprefix}initiatives/$ini.md"
      if [ ! -f "$brain/$cabeza" ]; then
        push_no_capturado "espera no escrita: no existe $cabeza"
        continue
      fi
      if os_fm_set "$brain/$cabeza" "waiting_on" "$quien"; then
        push_capturado "espera → $cabeza: waiting_on: $quien"
      else
        push_no_capturado "espera no escrita: $cabeza — $fm_roto"
      fi
      ;;

    sin-fila)
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

    no-capturado)
      cerrar_registro
      push_no_capturado "$value"
      ;;

    retomar)
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
    glob="orgs/*/backlog.md"
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
  declarar_glob "$glob"
fi

# ---------------------------------------------------------------- el veredicto
printf 'Cierre de sesión — %s\n\n' "$ambito_nombre"

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

printf '\nPara retomar\n'
if [ -z "$puntero" ]; then
  printf '  sin puntero de reanudación: la próxima sesión arranca sin por dónde seguir\n'
else
  printf '  retomar: %s (%s) — escrito en %sbacklog.md\n' "$puntero" "$hoy" "$orgprefix"
fi

t_fin=$(os_now_ms)
printf '\n%s piezas · %s\n' "$n_piezas" "$(os_elapsed "$t_inicio" "$t_fin")"
exit 0
