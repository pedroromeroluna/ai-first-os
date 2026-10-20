#!/usr/bin/env bash
# La mitad remota del respaldo del brain (spec 021). Interno: no es invocable.
# La conduce core/skills/bootstrap.md al cerrar el bootstrap, y la puede volver a correr cualquier
# sesión posterior — que es lo que la tarea pendiente del backlog le pide al operador.
#
# Uso: remote-backup.sh --brain DIR [--note]
#
# El script NUNCA crea el repo ni pushea: eso escapa del sistema —queda algo en la cuenta de una
# persona— y se hace con la confirmación del operador en la sesión. Acá se decide cuál de las dos
# mitades corresponde y se deja dicho:
#   - con `gh` autenticado: imprime el ofrecimiento y el comando exacto, para que lo corra la sesión
#     después del sí del operador;
#   - sin `gh`, o sin sesión iniciada: no escribe nada; imprime el paso pendiente y la pregunta del
#     catálogo («¿Te lo anoto para después?») y sale con 7. Nada se anota solo (Gate 2 final de la
#     spec 076): con el sí del operador en ese turno, la sesión lo vuelve a correr con `--note`, que
#     deja la tarea guiada en el backlog de la iniciativa tasks-to-sort del workspace personal.
#
# Exit: 0 decidió (o anotó con --note) · 1 si el brain no está versionado · 7 sin gh y sin --note: la
#       pregunta quedó impresa y no se escribió nada.

set -eu

here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"

brain=""
note=0

while [ $# -gt 0 ]; do
  case "$1" in
    --brain) brain="$2"; shift 2 ;;
    --note) note=1; shift ;;
    *) os_die "argumento desconocido: $1" ;;
  esac
done

[ -n "$brain" ] || os_die "falta --brain"
[ -d "$brain" ] || os_die "no existe el brain: $brain"
# Ruta física: ver el comentario de bootstrap.sh.
brain=$(cd "$brain" && pwd -P)

command -v git > /dev/null 2>&1 || os_die "git no está en el PATH: sin respaldo local no hay remoto que armar"
top=$(git -C "$brain" rev-parse --show-toplevel 2>/dev/null) || top=""
if [ "$top" != "$brain" ]; then
  os_die "el brain no es un repo git: el respaldo remoto va después del local"
fi

# Con remoto ya declarado no hay nada que decidir: el respaldo está armado.
remoto=$(git -C "$brain" remote get-url origin 2>/dev/null) || remoto=""
if [ -n "$remoto" ]; then
  printf 'respaldo remoto: ya está en %s\n' "$remoto"
  exit 0
fi

# `gh auth status` solo lee. Ningún otro comando de `gh` corre desde acá.
autenticado=0
if command -v gh > /dev/null 2>&1; then
  if gh auth status > /dev/null 2>&1; then
    autenticado=1
  fi
fi

if [ "$autenticado" = "1" ]; then
  printf 'respaldo remoto: gh autenticado — el repo lo crea el operador con su sí, nunca este script\n'
  printf '  comando: gh repo create %s --private --source %s --push\n' "$(basename "$brain")" "$brain"
  exit 0
fi

# Sin gh no se puede armar el remoto hoy: la tarea queda en el backlog del espacio de trabajo
# `personal` (spec 059: la raíz ya no tiene backlog propio), con la guía adentro, y el que la termina
# es cualquier sesión posterior. Un pendiente que nadie escribe es un pendiente que nadie completa.
# No pasa por `capture` (spec 057, decisión 2): este paso corre determinístico, sin ningún modelo
# que pueda nombrar una iniciativa — armar el remoto de respaldo no es trabajo de ninguna. Va al
# backlog de la iniciativa `tasks-to-sort` del workspace `personal` (spec 076, C29). La escritura vive
# en `os_personal_backlog_append`.
language=$(os_language "$brain")
os_lang_load "$language"
tarea="$S_BACKUP_TASK"
if [ "$note" = "0" ]; then
  printf "$S_NOTE_FOR_LATER_STEP\n" "$tarea"
  printf '%s\n' "$S_NOTE_FOR_LATER_QUESTION"
  exit 7
fi

os_ws_check "$brain"
rc=0
os_personal_backlog_append "$brain" "$tarea" || rc=$?
case "$rc" in
  0) printf 'respaldo remoto: pendiente — sin gh autenticado, la tarea guiada quedó en el backlog de la iniciativa tasks-to-sort del workspace personal\n' ;;
  1) printf 'respaldo remoto: la tarea pendiente ya estaba en el backlog de la iniciativa tasks-to-sort del workspace personal\n' ;;
  3) printf 'respaldo remoto: pendiente y sin escribir — el slug tasks-to-sort del workspace personal lo usa una iniciativa que trata sobre un nodo\n' ;;
  *) printf 'respaldo remoto: pendiente y sin escribir — el workspace personal no existe todavía; correr migrate-root.sh y repetir\n' ;;
esac
exit 0
