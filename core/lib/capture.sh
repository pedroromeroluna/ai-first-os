#!/usr/bin/env bash
# Parte determinística de `capture`: archiva un texto donde el resolver del nodo diga.
# La clasificación la hace core/skills/capture.md. Interno: no es invocable.
#
# Uso: capture.sh --brain DIR --text "TEXTO"
#                 [--org SLUG] [--session-org SLUG] [--load-context]
#                 [--blocked-by REF] [--hold RAZON] [--hold-until FECHA]
#
# Con `--org` la tarea va al `backlog.md` de esa organización, en el formato de línea que el arranque
# de sesión ya lee. Sin `--org` el texto no se pudo clasificar y va al `inbox.md` de la raíz, dicho:
# el inbox es tránsito de lo sin clasificar, nunca destino por comodidad.
#
# Los dos archivos nacen con su primer dato y el comando que los crea declara su glob en `tree.md`.
#
# Exit: 0 escribió · 2 la organización no existe · 3 escritura cross-nodo sin el context cargado.

set -u

here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"

brain=""
text=""
org=""
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
    --session-org) session_org="${2:-}"; shift 2 ;;
    --load-context) load_context=1; shift ;;
    --blocked-by) blocked_by="${2:-}"; shift 2 ;;
    --hold) hold="${2:-}"; shift 2 ;;
    --hold-until) hold_until="${2:-}"; hold_until_dado=1; shift 2 ;;
    *) os_die "argumento desconocido: $1" ;;
  esac
done

[ -n "$brain" ] || os_die "falta --brain"
[ -n "$text" ] || os_die "falta --text"
[ -d "$brain" ] || os_die "no existe el brain: $brain"
brain=$(cd "$brain" && pwd)
# Una captura es UNA línea, siempre — vale para el backlog y para el inbox. Un texto con saltos
# escribía varias líneas y cualquiera de ellas podía tener la forma de una tarea. Se colapsa y no se
# rechaza: `capture` existe para tirar cosas al vuelo.
text=$(os_una_linea "$text")
[ -n "$text" ] || os_die "el texto está vacío"

hoy=$(date +%Y-%m-%d)

# ---------------------------------------------------------------- declarar la altura
# `tree.md` del brain es una copia del template, no un symlink: agregar un glob al template no lo
# agrega a los brains ya bootstrapeados. Lo declara el comando que crea el archivo.
declarar_glob() {
  os_tree_ensure "$brain" "$1"
  case "$?" in
    0) printf '  tree.md — glob declarado: %s\n' "$1" ;;
    2) printf '  falta tree.md — el glob "%s" quedó sin declarar\n' "$1" ;;
  esac
}

# ---------------------------------------------------------------- lo inclasificable va al inbox
if [ -z "$org" ]; then
  if [ ! -f "$brain/inbox.md" ]; then
    printf '# Inbox\n\nLo que todavía no se pudo clasificar. Es tránsito, no destino.\n\n' \
      > "$brain/inbox.md"
    nacio=1
  else
    nacio=0
  fi
  printf -- '- %s (%s)\n' "$text" "$hoy" >> "$brain/inbox.md"
  printf 'sin clasificar — no se pudo decidir la organización, así que va al inbox\n'
  printf '  inbox.md — %s\n' "$text"
  [ "$nacio" = "1" ] && printf '  inbox.md nació con este dato\n'
  declarar_glob "inbox.md"
  exit 0
fi

# ---------------------------------------------------------------- el ámbito destino
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

# ---------------------------------------------------------------- escribir en otro nodo exige cargarlo
# El arranque de sesión ya cargó el `context` del nodo donde se trabaja: ahí no hay nada que
# recordar. La excepción es la escritura cross-nodo — el resolver del destino no está cargado y el
# agente archiva a ciegas, dejando el dato mal archivado en el nodo equivocado y en silencio.
# Un ámbito de sesión sin declarar cuenta como no cargado: suponer lo contrario es la misma ceguera.
if [ "$session_org" != "$org" ]; then
  ctx="orgs/$org/context.md"
  res="orgs/$org/resolver.md"
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

# ---------------------------------------------------------------- el backlog de la organización
backlog="$brain/orgs/$org/backlog.md"
nacio=0
os_backlog_asegurar "$brain" "$org" || nacio=1

# El id sale del máximo que ya haya en el archivo: dos corridas nunca escriben el mismo. El id se lee
# con el mismo helper que el resto del formato, así que un `tsk-999` adentro del texto de una tarea
# no cuenta como id de nadie.
max=0
while IFS= read -r line || [ -n "$line" ]; do
  os_backlog_lee "$line" || continue
  num="${bl_id#tsk-}"
  case "$num" in
    ''|*[!0-9]*) continue ;;
  esac
  while [ "${num#0}" != "$num" ] && [ -n "${num#0}" ]; do num="${num#0}"; done
  [ "$num" -gt "$max" ] && max="$num"
done < "$backlog"
id=$(printf 'tsk-%03d' "$(( max + 1 ))")

# El formato de línea vive en common.sh y lo comparten quien escribe y quien lee. Los marcadores son
# grupos al final; el texto del operador queda verbatim y nunca se interpreta.
linea=$(os_backlog_linea "$id" "$text" "$blocked_by" "$hold" "$hold_until" "$hold_until_dado" "$hoy")
printf '%s\n' "$linea" >> "$backlog"

printf 'clasificado en "%s"\n' "$org"
printf '  orgs/%s/backlog.md — %s\n' "$org" "$linea"
[ "$nacio" = "1" ] && printf '  orgs/%s/backlog.md nació con este dato\n' "$org"
declarar_glob "orgs/*/backlog.md"
exit 0
