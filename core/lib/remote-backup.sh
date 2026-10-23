#!/usr/bin/env bash
# La mitad remota del respaldo del brain (spec 021). Interno: no es invocable.
# La conduce core/skills/bootstrap.md al cerrar el bootstrap, y la puede volver a correr cualquier
# sesión posterior — que es lo que la tarea pendiente del backlog le pide al operador.
#
# Uso: remote-backup.sh --brain DIR [--service github|bitbucket|other|none] [--note]
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
# Spec 081: sin `--service` y sin `origin`, el script pregunta DÓNDE va el respaldo (GitHub, Bitbucket,
# otro servicio o ninguno): imprime la pregunta y las cuatro opciones del catálogo, no escribe nada y
# sale con 8; la sesión pregunta y vuelve a correr con `--service <lo elegido>`.
#   - github: lo de arriba, sin cambios (gh, o BACKUP_TASK y exit 7);
#   - bitbucket | other: no miran `gh`; imprimen BACKUP_TASK_GENERIC y la pregunta, exit 7; con
#     `--note` la tarea queda en el backlog, igual que la de GitHub;
#   - none: imprime BACKUP_NONE, exit 0, no escribe nada.
#
# Exit: 0 decidió (o anotó con --note, o `none`) · 1 si el brain no está versionado · 7 sin gh (o en
#       Bitbucket/otro) y sin --note: la pregunta quedó impresa y no se escribió nada · 8 sin
#       `--service`: la pregunta de dónde quedó impresa y no se escribió nada.

set -eu

here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"

brain=""
note=0
service=""

while [ $# -gt 0 ]; do
  case "$1" in
    --brain) brain="$2"; shift 2 ;;
    --note) note=1; shift ;;
    --service) [ $# -ge 2 ] || os_die "falta el valor de --service"; service="$2"; shift 2 ;;
    *) os_die "argumento desconocido: $1" ;;
  esac
done

[ -n "$brain" ] || os_die "falta --brain"
# Las banderas mal usadas frenan antes de tocar nada (spec 081, C8).
case "$service" in
  ''|github|bitbucket|other|none) ;;
  *) os_die "--service acepta github, bitbucket, other o none: $service" ;;
esac
if [ "$note" = "1" ] && [ -z "$service" ]; then os_die "--note necesita --service: sin saber dónde va el respaldo no hay tarea que anotar"; fi
if [ "$note" = "1" ] && [ "$service" = "none" ]; then os_die "--service none no anota nada: --note no aplica"; fi
[ -d "$brain" ] || os_die "no existe el brain: $brain"
# Ruta física: ver el comentario de bootstrap.sh.
brain=$(cd "$brain" && pwd -P)

command -v git > /dev/null 2>&1 || os_die "git no está en el PATH: sin respaldo local no hay remoto que armar"
if [ "$(os_brain_repo_state "$brain")" != "root" ]; then
  os_die "el brain no es un repo git: el respaldo remoto va después del local"
fi

# Con remoto ya declarado no hay nada que decidir: el respaldo está armado.
remoto=$(git -C "$brain" remote get-url origin 2>/dev/null) || remoto=""
if [ -n "$remoto" ]; then
  printf 'respaldo remoto: ya está en %s\n' "$remoto"
  exit 0
fi

language=$(os_language "$brain")
os_lang_load "$language"

# Sin `--service`: la pregunta de dónde va el respaldo. No corre `gh`, no escribe nada, sale con 8.
if [ -z "$service" ]; then
  printf '%s\n' "$S_BACKUP_WHERE_QUESTION"
  printf '  1. %s\n' "$S_BACKUP_OPTION_GITHUB"
  printf '  2. %s\n' "$S_BACKUP_OPTION_BITBUCKET"
  printf '  3. %s\n' "$S_BACKUP_OPTION_OTHER"
  printf '  4. %s\n' "$S_BACKUP_OPTION_NONE"
  printf '%s\n' "$S_CHOICE_REPLY_WITH_NUMBER"
  exit 8
fi

if [ "$service" = "none" ]; then
  printf '%s\n' "$S_BACKUP_NONE"
  exit 0
fi

# `gh auth status` solo lee. Ningún otro comando de `gh` corre desde acá, y solo con GitHub elegido.
if [ "$service" = "github" ]; then
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
  tarea="$S_BACKUP_TASK"
  causa="sin gh autenticado"
else
  # Bitbucket u otro servicio: pasos genéricos, sin `gh` ni github.com.
  if [ "$service" = "bitbucket" ]; then nombre="$S_BACKUP_OPTION_BITBUCKET"; else nombre="$S_BACKUP_SERVICE_OTHER"; fi
  tarea=$(printf "$S_BACKUP_TASK_GENERIC" "$nombre")
  causa="el repositorio remoto lo crea el operador"
fi

# Sin gh no se puede armar el remoto hoy: la tarea queda en el backlog del espacio de trabajo
# `personal` (spec 059: la raíz ya no tiene backlog propio), con la guía adentro, y el que la termina
# es cualquier sesión posterior. Un pendiente que nadie escribe es un pendiente que nadie completa.
# No pasa por `capture` (spec 057, decisión 2): este paso corre determinístico, sin ningún modelo
# que pueda nombrar una iniciativa — armar el remoto de respaldo no es trabajo de ninguna. Va al
# backlog de la iniciativa `tasks-to-sort` del workspace `personal` (spec 076, C29). La escritura vive
# en `os_personal_backlog_append`.
if [ "$note" = "0" ]; then
  printf "$S_NOTE_FOR_LATER_STEP\n" "$tarea"
  printf '%s\n' "$S_NOTE_FOR_LATER_QUESTION"
  exit 7
fi

os_ws_check "$brain"
rc=0
os_personal_backlog_append "$brain" "$tarea" || rc=$?
case "$rc" in
  0) printf 'respaldo remoto: pendiente — %s, la tarea guiada quedó en el backlog de la iniciativa tasks-to-sort del workspace personal\n' "$causa" ;;
  1) printf 'respaldo remoto: la tarea pendiente ya estaba en el backlog de la iniciativa tasks-to-sort del workspace personal\n' ;;
  3) printf 'respaldo remoto: pendiente y sin escribir — el slug tasks-to-sort del workspace personal lo usa una iniciativa que trata sobre un nodo\n' ;;
  *) printf 'respaldo remoto: pendiente y sin escribir — el workspace personal no existe todavía; correr migrate-root.sh y repetir\n' ;;
esac
exit 0
