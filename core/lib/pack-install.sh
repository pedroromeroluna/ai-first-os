#!/usr/bin/env bash
# El paso del pack, diferible (spec 029). Interno: no es invocable — tiene fila de capacidad en
# `core/resolver.md`, igual que `remote-backup.sh`, y lo conducen `core/skills/bootstrap.md` al
# cerrar el bootstrap y cualquier sesión posterior que lo rutee.
#
# Uso: pack-install.sh --brain DIR [--defer] [--line]
#
#   (sin flags)  el ofrecimiento: qué hay instalado, qué falta y el comando exacto.
#   --defer      la salida "después": deja la tarea en el backlog de la raíz, con el comando adentro.
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
# Exit: 0 el ofrecimiento o la tarea quedaron dichos · 1 el brain no existe.

set -eu

here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"

brain=""
modo="ofrecer"

while [ $# -gt 0 ]; do
  case "$1" in
    --brain) brain="$2"; shift 2 ;;
    --defer) modo="defer"; shift ;;
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
for d in "$brain"/.claude/skills/*/SKILL.md; do
  [ -f "$d" ] || continue
  d=$(dirname "$d")
  instalados="$instalados$(basename "$d") "
  n_instalados=$(( n_instalados + 1 ))
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

if [ "$modo" = "defer" ]; then
  if [ -f "$brain/backlog.md" ] && grep -qF "$tarea" "$brain/backlog.md"; then
    printf 'pack: la tarea pendiente ya estaba en el backlog de la raíz\n'
    exit 0
  fi
  "$here/capture.sh" --brain "$brain" --root --text "$tarea"
  printf 'pack: pendiente — la tarea quedó en el backlog de la raíz, con el comando adentro\n'
  exit 0
fi

# --------------------------------------------------------------------- el ofrecimiento
if [ "$n_instalados" = "0" ]; then
  printf 'pack: nada instalado todavía en .claude/skills\n'
else
  printf 'pack: ya instalado en .claude/skills: %s\n' "$instalados"
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
