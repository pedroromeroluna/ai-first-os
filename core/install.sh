#!/usr/bin/env bash
# command: install.sh
# Engancha el producto a un brain por symlink. Idempotente: correrlo dos veces no cambia nada.
#
# Uso: install.sh RUTA-BRAIN [--adopt]
#
# Qué deja en el brain:
#   CLAUDE.md            -> symlink al contrato de sesión del producto
#   .os/core             -> symlink a core/
#   .os/packs/<pack>     -> symlink a cada pack
#   .claude/agents/<n>   -> symlink a cada agente de core/agents/, uno por archivo (el harness del
#                            operador los lee de ahí; symlinkear el directorio entero se
#                            llevaría por delante configuración propia del operador en .claude/)
#
# --adopt: si el brain ya tiene un CLAUDE.md que no es el de este producto —propio, o symlink a
# otro— lo guarda como CLAUDE.md.adopted, un nombre que ningún harness carga, y engancha el
# symlink. Sin --adopt el instalador para y no toca nada.

set -eu

core=$(cd "$(dirname "$0")" && pwd)
product=$(cd "$core/.." && pwd)

brain=""
adopt=0

while [ $# -gt 0 ]; do
  case "$1" in
    --adopt) adopt=1; shift ;;
    -*) printf 'error: argumento desconocido: %s\n' "$1" >&2; exit 1 ;;
    *) brain="$1"; shift ;;
  esac
done

if [ -z "$brain" ]; then
  printf 'uso: install.sh RUTA-BRAIN [--adopt]\n' >&2
  exit 1
fi

mkdir -p "$brain"
brain=$(cd "$brain" && pwd)

claude="$brain/CLAUDE.md"
claude_target="$core/CLAUDE.md"
adopted="$brain/CLAUDE.md.adopted"
# Ruta física de este producto, para comparar destinos y no cadenas. El instalador resuelve esto
# solo, sin lib/: es lo primero que se corre y no puede depender del layout de lo que instala.
core_real=$(cd "$core" && pwd -P)

# Destino real de un symlink: un readlink, y el directorio resuelto con `cd -P`, que atraviesa los
# symlinks que haya en el medio del camino. Vacío si no se puede resolver.
resolve_link() {
  local link="$1" t d
  t=$(readlink "$link") || return 0
  case "$t" in
    /*) ;;
    *) t="$(dirname "$link")/$t" ;;
  esac
  d=$(cd "$(dirname "$t")" 2>/dev/null && pwd -P) || return 0
  [ -n "$d" ] || return 0
  printf '%s/%s' "$d" "$(basename "$t")"
}

# Chequeo antes de tocar nada. Adoptar es para un CLAUDE.md **ajeno**: un archivo propio del
# operador, o un symlink vivo hacia otro producto. Lo que no es adopción es re-instalación, y se
# relinkea callado: un symlink colgado —el producto se movió— y uno que ya apunta acá escrito de
# otra forma. Comparar por cadena de ruta trataba a los dos como ajenos: al colgado lo "adoptaba"
# dejando un CLAUDE.md.adopted roto, y al otro le pedía --adopt sin motivo.
needs_adopt=0
if [ -L "$claude" ]; then
  if [ -e "$claude" ] && [ "$(resolve_link "$claude")" != "$core_real/CLAUDE.md" ]; then
    needs_adopt=1
  fi
elif [ -e "$claude" ]; then
  needs_adopt=1
fi

if [ "$needs_adopt" = "1" ]; then
  if [ "$adopt" = "0" ]; then
    printf 'error: %s ya existe y no es el contrato de este producto.\n' "$claude" >&2
    printf '       Correlo con --adopt: lo guarda como CLAUDE.md.adopted y engancha el symlink.\n' >&2
    printf '       Ese nombre no lo carga ningún harness. Lo que valga de ahí se mueve a mano a\n' >&2
    printf '       operator.md.\n' >&2
    exit 1
  fi
  if [ -e "$adopted" ] || [ -L "$adopted" ]; then
    printf 'error: %s ya existe. Resolvelo a mano antes de volver a correr --adopt.\n' "$adopted" >&2
    exit 1
  fi
fi

mkdir -p "$brain/.os/packs"
ln -sfn "$core" "$brain/.os/core"

for pack in "$product"/packs/*; do
  [ -d "$pack" ] || continue
  ln -sfn "$pack" "$brain/.os/packs/$(basename "$pack")"
done

mkdir -p "$brain/.claude/agents"
for agent in "$core"/agents/*.md; do
  [ -f "$agent" ] || continue
  ln -sfn "$agent" "$brain/.claude/agents/$(basename "$agent")"
done

if [ "$needs_adopt" = "1" ]; then
  mv "$claude" "$adopted"
  printf 'aviso: el CLAUDE.md que estaba en el brain quedó como CLAUDE.md.adopted.\n' >&2
  printf '       Ningún harness lo carga. Lo que valga de ahí va a operator.md.\n' >&2
fi
ln -sfn "$claude_target" "$claude"

printf 'brain: %s\n' "$brain"
printf 'CLAUDE.md -> %s\n' "$claude_target"
printf '.os/core -> %s\n' "$core"
for pack in "$product"/packs/*; do
  [ -d "$pack" ] || continue
  printf '.os/packs/%s -> %s\n' "$(basename "$pack")" "$pack"
done
for agent in "$core"/agents/*.md; do
  [ -f "$agent" ] || continue
  printf '.claude/agents/%s -> %s\n' "$(basename "$agent")" "$agent"
done
