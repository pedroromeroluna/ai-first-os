#!/usr/bin/env bash
# El paso del pack, diferible (spec 029). Interno: no es invocable — tiene fila de capacidad en
# `core/resolver.md`, igual que `remote-backup.sh`, y lo conducen `core/skills/bootstrap.md` al
# cerrar el bootstrap y cualquier sesión posterior que lo rutee.
#
# Uso: pack-install.sh --brain DIR [--defer [--note]] [--line]
#
#   (sin flags)  el ofrecimiento: qué hay instalado, qué falta y el comando exacto.
#   --defer      la salida "después", sin escribir nada: imprime el paso pendiente y la pregunta del
#                catálogo («¿Te lo anoto para después?») y sale con 7. Nada se anota solo (Gate 2 final
#                de la spec 076).
#   --defer --note  el sí del operador en ese turno: deja la tarea, con el comando adentro, en el
#                backlog de la iniciativa tasks-to-sort del workspace personal, que nace si no está
#                (`os_personal_backlog_append`). Sin pasar por `capture` (spec 057): este paso es
#                determinístico, sin ningún modelo que pueda nombrar una iniciativa.
#   --line       una línea, para el aviso de capacidad no instalada del arranque de sesión.
#
# El script NUNCA corre `npx`: bajar software a la máquina del operador escapa del sistema y se hace
# con su sí, en la sesión — mismo criterio que `remote-backup.sh` con `gh repo create`.
#
# Node se chequea ACÁ y en ningún otro lado del sistema (decisión 1 de la spec 029): instalar el OS
# pide git y nada más, y Node es requisito de este momento. Sin Node el script no falla: dice qué
# falta, dónde se consigue, y ofrece la salida "después".
#
# El nombre del repo del pack se escribe una sola vez —el default de `scripts/release-public.sh`— y
# el release lo inyecta acá donde el fuente lleva `pedroromeroluna/ai-first-product-skills`.
#
# Exit: 0 el ofrecimiento o la tarea quedaron dichos · 1 el brain no existe · 7 --defer sin --note:
#       la pregunta quedó impresa y no se escribió nada.

set -eu

here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"

brain=""
modo="ofrecer"
note=0

while [ $# -gt 0 ]; do
  case "$1" in
    --brain) brain="$2"; shift 2 ;;
    --defer) modo="defer"; shift ;;
    --note) note=1; shift ;;
    --line) modo="line"; shift ;;
    *) os_die "argumento desconocido: $1" ;;
  esac
done

[ -n "$brain" ] || os_die "falta --brain"
[ -d "$brain" ] || os_die "no existe el brain: $brain"
brain=$(cd "$brain" && pwd -P)

# El nombre del repo del pack: el fuente lleva el placeholder y el release lo resuelve al generar el
# chasis. El comando exacto se arma una sola vez acá y lo leen las tres salidas.
pack_repo="pedroromeroluna/ai-first-product-skills"
comando="npx skills add $pack_repo"

# Qué del pack ya está donde el CLI lo deja. No es una lista escrita: es lo que hay en el brain.
instalados=""
n_instalados=0
for sd in $OS_SKILL_DIRS; do
  for d in "$brain/$sd"/*/SKILL.md; do
    [ -f "$d" ] || continue
    d=$(dirname "$d")
    # A skill present in both folders (the link `npx skills add` leaves) counts once.
    case " $instalados" in *" $(basename "$d") "*) continue ;; esac
    instalados="$instalados$(basename "$d") "
    n_instalados=$(( n_instalados + 1 ))
  done
done

if [ "$modo" = "line" ]; then
  # El aviso corto: la demanda dispara la oferta (decisión 3 de la spec 029). Con algo del pack ya
  # instalado no hay nada que ofrecer — lo que falte es otro problema y este no es su mensaje.
  [ "$n_instalados" = "0" ] || exit 0
  printf 'el pack no está instalado: %s\n' "$comando"
  exit 0
fi

language=$(os_language "$brain")
os_lang_load "$language"
tarea="$S_PACK_TASK \`$comando\`"

if [ "$modo" = "defer" ] && [ "$note" = "0" ]; then
  # Nothing is noted down on its own (spec 076, final Gate 2): the step and the plain question, and the
  # skill that drives this step asks it; only a yes in that turn re-runs this with --note.
  printf "$S_NOTE_FOR_LATER_STEP\n" "$tarea"
  printf '%s\n' "$S_NOTE_FOR_LATER_QUESTION"
  exit 7
fi

if [ "$modo" = "defer" ]; then
  # No pasa por `capture` (spec 057, decisión 2: nada entra sin clasificar): instalar el pack de
  # skills no es trabajo de ninguna iniciativa, es un paso pendiente del propio sistema. Va al
  # backlog de la iniciativa `tasks-to-sort` del workspace `personal` (spec 076, C29: ningún backlog
  # vive fuera de una iniciativa), que nace con esta tarea si no existía.
  os_ws_check "$brain"
  rc=0
  os_personal_backlog_append "$brain" "$tarea" || rc=$?
  case "$rc" in
    0) printf 'pack: pendiente — la tarea quedó en el backlog de la iniciativa tasks-to-sort del workspace personal, con el comando adentro\n' ;;
    1) printf 'pack: la tarea pendiente ya estaba en el backlog de la iniciativa tasks-to-sort del workspace personal\n' ;;
    3) printf 'pack: pendiente y sin escribir — el slug tasks-to-sort del workspace personal lo usa una iniciativa que trata sobre un nodo\n' ;;
    *) printf 'pack: pendiente y sin escribir — el workspace personal no existe todavía; correr migrate-root.sh y repetir\n' ;;
  esac
  exit 0
fi

# --------------------------------------------------------------------- el ofrecimiento
if [ "$n_instalados" = "0" ]; then
  printf 'pack: nada instalado todavía en .agents/skills ni en .claude/skills\n'
else
  printf 'pack: ya instalado en las carpetas de skills: %s\n' "$instalados"
fi

# El comando baja solo lo que el pack ofrece: lo que el chasis ya provee viaja marcado interno y el
# CLI lo saltea sin que nadie tenga que nombrarlo (spec 029). Nunca se instala para después borrar.
if command -v node > /dev/null 2>&1; then
  printf 'node: %s\n' "$(node --version 2>/dev/null || printf 'presente')"
  printf '  comando: %s\n' "$comando"
  printf '  tal cual: sin --all y sin --skill "*", que bajan también lo que el chasis ya provee\n'
  printf '  lo corre la sesión con el sí del operador, desde la carpeta del brain; este script nunca lo corre\n'
else
  printf 'node: falta — el instalador LTS está en nodejs.org, y lo instala el operador, nunca el agente\n'
  printf '  con node presente: %s\n' "$comando"
  printf '  o dejarlo para después: %s --brain %s --defer\n' "$here/pack-install.sh" "$brain"
fi
