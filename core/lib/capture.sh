#!/usr/bin/env bash
# Parte determinística de `capture`: archiva un texto en el `backlog.md` de la iniciativa que
# `core/skills/capture.md` nombra. Interno: no es invocable.
#
# Uso: capture.sh --brain DIR --text "TEXTO" --initiative SLUG
#                 [--org SLUG | --workspace SLUG | --root] [--session-org SLUG] [--load-context]
#                 [--blocked-by REF] [--hold RAZON] [--hold-until FECHA]
#
# `--workspace` es sinónimo exacto de `--org` (spec 039). `--org`/`--workspace` y `--root` son
# excluyentes.
#
# Spec 057, decisión 2: **nada entra sin clasificar**. `--initiative` es obligatorio siempre — sin
# ella no se escribe nada, en ningún archivo: ni el backlog de la organización o de la raíz (que ya
# no existen como destino de `capture`) ni el `inbox.md` de la raíz (deja de ser destino; su
# desaparición de la raíz la resuelve la spec 059). La tarea va a
# `<wsdir>/<org>/initiatives/<slug>/backlog.md`, o a `initiatives/<slug>/backlog.md` con `--root`,
# en el formato de línea que el arranque de sesión ya lee. El id `tsk-XXX` sigue siendo único en
# todo el brain (decisión 3): sale de una pasada por cada `backlog.md` que el brain tenga
# (`os_backlog_next_id`), nunca de un archivo de estado nuevo.
#
# El backlog de una iniciativa nunca declara su glob: `content: initiatives/*/*.md` (y su gemelo de
# espacio de trabajo) ya lo alcanzan — a diferencia del backlog de organización o de raíz de antes de
# esta spec, acá no hace falta escribir en `tree.md`.
#
# La raíz no exige `--session-org` ni `--load-context`: su identidad (`operator.md`) está cargada en
# cualquier sesión, a cualquier ámbito — no hay context cross-nodo que custodiar.
#
# Exit: 0 escribió · 2 la organización no existe · 3 escritura cross-nodo sin el context cargado ·
# 4 falta --initiative · 5 la iniciativa no existe en ese ámbito · 6 no se declaró ámbito (ni
# --org/--workspace ni --root) — antes de esta spec ese caso caía en el inbox de la raíz.

set -u

here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"

brain=""
text=""
org=""
workspace=""
root=0
initiative=""
session_org=""
load_context=0
blocked_by=""
hold=""
hold_until=""
hold_until_dado=0

while [ $# -gt 0 ]; do
  case "$1" in
    --brain) brain="${2:-}"; shift 2 ;;
    --text) text="${2:-}"; shift 2 ;;
    --org) org="${2:-}"; shift 2 ;;
    --workspace) workspace="${2:-}"; shift 2 ;;
    --root) root=1; shift ;;
    --initiative) initiative="${2:-}"; shift 2 ;;
    --session-org) session_org="${2:-}"; shift 2 ;;
    --load-context) load_context=1; shift ;;
    --blocked-by) blocked_by="${2:-}"; shift 2 ;;
    --hold) hold="${2:-}"; shift 2 ;;
    --hold-until) hold_until="${2:-}"; hold_until_dado=1; shift 2 ;;
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
[ "$root" = "0" ] || [ -z "$org" ] || os_die "--root y --org/--workspace son excluyentes"
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
# El operador siempre está cargado —`operator.md` se lee en cualquier arranque, a cualquier ámbito—
# así que la raíz no tiene escritura cross-nodo que custodiar: nunca pide `--session-org` ni
# `--load-context`.
if [ "$root" = "1" ]; then
  prefix=""
  ambito_label="la raíz"
else
  # Sin --org/--workspace y sin --root no hay ámbito que resolver: antes de esta spec ese caso caía
  # en el inbox; ahora no hay inbox al que caer, así que se declara sin tocar nada, con el mismo
  # criterio que la falta de iniciativa de más abajo — spec 057, decisión 2.
  if [ -z "$org" ]; then
    printf 'no se declaró ámbito: capture no escribe nada sin --org/--workspace o --root.\n' >&2
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
fi

# ---------------------------------------------------------------- nada entra sin clasificar
# Decisión 2 de la spec 057: sin iniciativa nombrada no
# se escribe nada, en ningún archivo. Frena antes de tocar el brain — inclusive antes del chequeo de
# escritura cross-nodo, que solo tiene sentido una vez que ya hay un destino.
if [ -z "$initiative" ]; then
  printf 'falta la iniciativa: capture no escribe nada sin --initiative.\n' >&2
  printf 'nombrala vos, o proponé una y esperá que el operador la confirme, y repetí con --initiative <slug>.\n' >&2
  exit 4
fi

if ! os_ini_existe "$brain" "$prefix" "$initiative"; then
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
if [ "$root" = "0" ] && [ "$session_org" != "$org" ]; then
  ctx="$wsdir/$org/$(os_head_file "$brain" || true)"
  res="$wsdir/$org/resolver.md"
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
