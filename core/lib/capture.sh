#!/usr/bin/env bash
# Parte determinística de `capture`: archiva un texto en el `backlog.md` de la iniciativa que
# `core/skills/capture.md` nombra. Interno: no es invocable.
#
# Uso: capture.sh --brain DIR --text "TEXTO" (--initiative SLUG | --about HEAD [--create])
#                 [--org SLUG | --workspace SLUG] [--session-org SLUG] [--load-context]
#                 [--blocked-by REF] [--hold RAZON] [--hold-until FECHA]
#
# `--about HEAD` (spec 076, C30) files a task of an area node with no project of its own in the
# node's standing initiative: the one with `status: ongoing` whose `about:` names that head and
# nothing else, in the same workspace.
#   - exactly one: the task goes to its backlog, as with `--initiative`;
#   - none: nothing is written, the script prints on stdout the question the AI asks the operator
#     —`CAPTURE_CREATE_QUESTION` of the strings catalog, in the language of the brain, with no word of
#     the system's vocabulary— and exits 7;
#   - none, with `--create` (the operator's yes, given in that turn): the initiative is created
#     (`status: ongoing`, `about:` the head, the node's title, `os_ini_create`) and the task written.
#     Its slug is the node's; if another initiative already uses it, the slug adds the node's type in
#     the singular (`checkout-product`). The title stays the node's name, with no suffix. An
#     initiative with that slug whose `about:` does not name the node is never reused;
#   - two or more: nothing is written, they are named on stderr, exit 8.
#
# `--workspace` es sinónimo exacto de `--org` (spec 039).
#
# Spec 057, decisión 2: **nada entra sin clasificar**. `--initiative` es obligatorio siempre — sin
# ella no se escribe nada, en ningún archivo: ni el backlog de la organización (que ya no es destino
# de `capture`) ni el `inbox.md` de la raíz (la spec 059 lo saca de la raíz). La tarea va a
# `<wsdir>/<org>/initiatives/<slug>/backlog.md`, en el formato de línea que el arranque de sesión ya lee. El id `tsk-XXX` sigue siendo único en
# todo el brain (decisión 3): sale de una pasada por cada `backlog.md` que el brain tenga
# (`os_backlog_next_id`), nunca de un archivo de estado nuevo.
#
# El backlog de una iniciativa nunca declara su glob: `content: <wsdir>/*/initiatives/*/*.md` ya lo
# alcanza — a diferencia del backlog de organización de antes de esta spec, acá no hace falta
# escribir en `tree.md`.
#
# `--root` ya no existe (spec 059): la raíz del brain solo tiene maquinaria, y el trabajo propio del
# operador es el espacio de trabajo `personal`, con el que todo brain nace — usar
# `--workspace personal`. El flag se acepta solo para frenar con ese destino, sin escribir nada.
#
# Exit: 0 escribió · 2 la organización no existe · 3 escritura cross-nodo sin el context cargado ·
# 4 falta --initiative · 5 la iniciativa no existe en ese ámbito · 6 no se declaró ámbito (ni
# --org ni --workspace) — antes de la spec 057 ese caso caía en el inbox de la raíz · 7 `--about`
# sin iniciativa permanente: la pregunta está en stdout y no se escribió nada · 8 `--about` con dos
# o más iniciativas permanentes · 1 `--root` (spec 059) u otro argumento inválido.

set -u

here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"

brain=""
text=""
org=""
workspace=""
initiative=""
about=""
create=0
session_org=""
load_context=0
blocked_by=""
hold=""
hold_until=""
hold_until_dado=0

while [ $# -gt 0 ]; do
  case "$1" in
    --brain) brain="${2:-}"; shift 2 || os_die "$1 needs a value" ;;
    --text) text="${2:-}"; shift 2 || os_die "$1 needs a value" ;;
    --org) org="${2:-}"; shift 2 || os_die "$1 needs a value" ;;
    --workspace) workspace="${2:-}"; shift 2 || os_die "$1 needs a value" ;;
    --root) os_die "--root ya no existe (spec 059): el trabajo propio del operador es el espacio de trabajo \"$OS_PERSONAL_WORKSPACE_SLUG\" — usá --workspace $OS_PERSONAL_WORKSPACE_SLUG. Si el brain todavía tiene trabajo suelto en la raíz, correr migrate-root.sh primero" ;;
    --initiative) initiative="${2:-}"; shift 2 || os_die "$1 needs a value" ;;
    --about) about="${2:-}"; shift 2 || os_die "$1 needs a value" ;;
    --create) create=1; shift ;;
    --session-org) session_org="${2:-}"; shift 2 || os_die "$1 needs a value" ;;
    --load-context) load_context=1; shift ;;
    --blocked-by) blocked_by="${2:-}"; shift 2 || os_die "$1 needs a value" ;;
    --hold) hold="${2:-}"; shift 2 || os_die "$1 needs a value" ;;
    --hold-until) hold_until="${2:-}"; hold_until_dado=1; shift 2 || os_die "$1 needs a value" ;;
    *) os_die "argumento desconocido: $1" ;;
  esac
done

# `--workspace` es sinónimo exacto de `--org` (P3, spec 039).
if [ -n "$org" ] && [ -n "$workspace" ] && [ "$org" != "$workspace" ]; then
  os_die "--org y --workspace con valores distintos: $org / $workspace"
fi
[ -n "$org" ] || org="$workspace"

[ -n "$brain" ] || os_die "falta --brain"
[ -n "$text" ] || os_die "falta --text"
[ -d "$brain" ] || os_die "no existe el brain: $brain"
brain=$(cd "$brain" && pwd)

# Layout inválido frena acá, antes de cualquier $(...) que arme una ruta con el nombre de la
# carpeta (P2, spec 039).
os_ws_check "$brain"
wsdir=$(os_ws_dir "$brain")
# Una captura es UNA línea, siempre. Un texto con saltos escribía varias líneas y cualquiera de
# ellas podía tener la forma de una tarea. Se colapsa y no se rechaza: `capture` existe para tirar
# cosas al vuelo.
text=$(os_una_linea "$text")
[ -n "$text" ] || os_die "el texto está vacío"

hoy=$(date +%Y-%m-%d)

# ---------------------------------------------------------------- el ámbito
# Sin --org/--workspace no hay ámbito que resolver: antes de la spec 057 ese caso caía en el inbox;
# ahora no hay inbox al que caer, así que se declara sin tocar nada, con el mismo criterio que la
# falta de iniciativa de más abajo — spec 057, decisión 2.
if [ -z "$org" ]; then
  printf 'no se declaró ámbito: capture no escribe nada sin --org/--workspace.\n' >&2
  exit 6
fi
if ! os_org_existe "$brain" "$org"; then
  printf 'la organización "%s" no existe. Las que hay:\n' "$org" >&2
  slugs=$(os_org_slugs "$brain")
  if [ -n "$slugs" ]; then
    printf '%s\n' "$slugs" | while IFS= read -r s; do printf '  %s\n' "$s" >&2; done
  else
    printf '  (ninguna)\n' >&2
  fi
  exit 2
fi
prefix="$wsdir/$org/"
ambito_label="\"$org\""

# ---------------------------------------------------------------- nada entra sin clasificar
# Decisión 2 de la spec 057: sin iniciativa nombrada no
# se escribe nada, en ningún archivo. Frena antes de tocar el brain — inclusive antes del chequeo de
# escritura cross-nodo, que solo tiene sentido una vez que ya hay un destino.
[ -z "$initiative" ] || [ -z "$about" ] || os_die "--initiative y --about no van juntos: la tarea va a una sola iniciativa"
[ "$create" = "0" ] || [ -n "$about" ] || os_die "--create solo va con --about"

# ---------------------------------------------------------------- the standing initiative of a node (spec 076, C30)
crear_ini=0
if [ -n "$about" ]; then
  about=$(os_rel_norm "$about")
  head_name=$(os_head_file "$brain" || true)
  case "$about" in
    "$prefix"*) ;;
    *) os_die "--about no es un nodo de $ambito_label: $about" ;;
  esac
  [ -f "$brain/$about" ] || os_die "--about no existe: $about"
  case "$(os_head_kind "$wsdir" "$head_name" "$about")" in
    "entity $org") ;;
    *) os_die "--about no es la cabeza de un nodo de área (producto, curso, canal o cuenta): $about" ;;
  esac
  nodo_slug=$(os_entity_name "$about")
  nodo_tipo="${about#"$prefix"}"; nodo_tipo="${nodo_tipo%%/*}"; nodo_tipo="${nodo_tipo%s}"
  nodo_titulo=$(os_titulo "$brain/$about")
  [ -n "$nodo_titulo" ] || nodo_titulo="$nodo_slug"
  candidatas=""
  n_candidatas=0
  while IFS= read -r s_ini || [ -n "$s_ini" ]; do
    [ -n "$s_ini" ] || continue
    fm_read "$brain/$(os_ini_head_rel "$brain" "$prefix" "$s_ini")"
    [ "$fm_status" = "ongoing" ] || continue
    os_about_is_single "$fm_about" "$about" || continue
    n_candidatas=$(( n_candidatas + 1 ))
    candidatas="$candidatas $s_ini"
  done <<INIS
$(os_ini_slugs "$brain" "$prefix")
INIS
  if [ "$n_candidatas" -gt 1 ]; then
    printf 'dos o más iniciativas permanentes para %s; nombrá una con --initiative:%s\n' "$about" "$candidatas" >&2
    exit 8
  fi
  if [ "$n_candidatas" = "1" ]; then
    initiative="${candidatas# }"
  else
    initiative="$nodo_slug"
    if os_ini_existe "$brain" "$prefix" "$initiative" || [ -e "$brain/${prefix}initiatives/$initiative" ]; then
      initiative="$nodo_slug-$nodo_tipo"
    fi
    if os_ini_existe "$brain" "$prefix" "$initiative" || [ -e "$brain/${prefix}initiatives/$initiative" ]; then
      os_die "los slugs $nodo_slug y $initiative ya los usan otras iniciativas: nombrá una con --initiative"
    fi
    if [ "$create" = "0" ]; then
      os_lang_load "$(os_language "$brain")"
      printf "$S_CAPTURE_CREATE_QUESTION\n" "$nodo_titulo" "$nodo_titulo"
      exit 7
    fi
    crear_ini=1
  fi
fi

if [ -z "$initiative" ]; then
  printf 'falta la iniciativa: capture no escribe nada sin --initiative.\n' >&2
  printf 'nombrala vos, o proponé una y esperá que el operador la confirme, y repetí con --initiative <slug>.\n' >&2
  exit 4
fi

if [ "$crear_ini" = "0" ] && ! os_ini_existe "$brain" "$prefix" "$initiative"; then
  printf 'la iniciativa "%s" no existe en %s. Las que hay:\n' "$initiative" "$ambito_label" >&2
  slugs=$(os_ini_slugs "$brain" "$prefix")
  if [ -n "$slugs" ]; then
    printf '%s\n' "$slugs" | while IFS= read -r s; do printf '  %s\n' "$s" >&2; done
  else
    printf '  (ninguna)\n' >&2
  fi
  printf 'ningún comando crea iniciativas: si hace falta una nueva, se escribe su cabeza primero.\n' >&2
  exit 5
fi

# ---------------------------------------------------------------- escribir en otro nodo exige cargarlo
# El arranque de sesión ya cargó el `context` del nodo donde se trabaja: ahí no hay nada que
# recordar. La excepción es la escritura cross-nodo — el resolver del destino no está cargado y el
# agente archiva a ciegas, dejando el dato mal archivado en el nodo equivocado y en silencio.
# Un ámbito de sesión sin declarar cuenta como no cargado: suponer lo contrario es la misma ceguera.
if [ "$session_org" != "$org" ]; then
  ctx="$wsdir/$org/$(os_head_file "$brain" || true)"
  res="$wsdir/$org/.resolver.md"
  if [ "$load_context" = "0" ]; then
    printf 'escritura cross-nodo: la sesión está parada en "%s" y esto se escribe en "%s".\n' \
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
      printf -- '--- %s: no está — se escribe degradado y se dice\n' "$f"
    fi
  done
  printf -- '---\n'
fi

# ---------------------------------------------------------------- the standing initiative is born (spec 076, C30)
if [ "$crear_ini" = "1" ]; then
  os_ini_create "$brain" "$prefix" "$initiative" "$nodo_titulo" ongoing "$about" \
    || os_die "no se pudo crear la iniciativa: ${prefix}initiatives/$initiative"
  printf 'iniciativa creada: %s\n' "$(os_ini_head_rel "$brain" "$prefix" "$initiative")"
fi

# ---------------------------------------------------------------- el backlog de la iniciativa
backlog_rel=$(os_ini_backlog_rel "$prefix" "$initiative")
backlog="$brain/$backlog_rel"
nacio=0
os_ini_backlog_asegurar "$brain" "$prefix" "$initiative" || nacio=1

# El id sale de una pasada por cada `backlog.md` del brain (decisión 3: el contador sigue siendo
# global, no por iniciativa) — nunca del máximo de este solo archivo, que repetiría un id ya usado
# en otra iniciativa.
id=$(os_backlog_next_id "$brain")

# El formato de línea vive en common.sh y lo comparten quien escribe y quien lee. Los marcadores son
# grupos al final; el texto del operador queda verbatim y nunca se interpreta.
linea=$(os_backlog_linea "$id" "$text" "$blocked_by" "$hold" "$hold_until" "$hold_until_dado" "$hoy")
printf '%s\n' "$linea" >> "$backlog"

printf 'clasificado en %s (%s)\n' "$ambito_label" "$initiative"
printf '  %s — %s\n' "$backlog_rel" "$linea"
[ "$nacio" = "1" ] && printf '  %s nació con este dato\n' "$backlog_rel"
exit 0
