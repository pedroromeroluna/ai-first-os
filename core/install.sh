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

# Ruta física, no lógica (spec 016): invocado a través del symlink instalado en un brain,
# `pwd` lógico devuelve la ruta del symlink y cada `ln` posterior escribe un enlace sobre sí
# mismo — el brain entero queda circular. `pwd -P` atraviesa el symlink hasta el checkout real.
core=$(cd "$(dirname "$0")" && pwd -P)
product=$(cd "$core/.." && pwd -P)

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

# El idioma del brain, leído una sola vez acá: lo usan tanto el aviso del nombre anterior de la
# carpeta de espacios de trabajo como la línea de versión, más abajo. Mismo criterio liviano que el
# resto de este script — sin `lib/`, porque el instalador es lo primero que corre.
lang="en"
if [ -f "$brain/operator.md" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      'language: '*)
        case "${line#language: }" in en) lang="en" ;; es) lang="es" ;; esac
        break
        ;;
    esac
  done < "$brain/operator.md"
fi

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

# La guarda del self-link (spec 016): si el destino de un enlace por escribir resuelve —tras
# atravesar los symlinks del camino— a su propio origen, no se escribe nada y se aborta. Cubre
# el brain cuyo `.os` es symlink a la raíz del producto: ahí cada `ln` escribiría adentro del
# producto un enlace sobre sí mismo. Se chequean todos los pares antes del primer mkdir/ln.
guard_selflink() {
  local dest="$1" src="$2" ddir dreal sreal
  ddir=$(cd -P "$(dirname "$dest")" 2>/dev/null && pwd -P) || return 0
  dreal="$ddir/$(basename "$dest")"
  if [ -d "$src" ]; then
    sreal=$(cd -P "$src" && pwd -P)
  else
    sreal="$(cd -P "$(dirname "$src")" && pwd -P)/$(basename "$src")"
  fi
  if [ "$dreal" = "$sreal" ]; then
    printf 'error: el enlace %s resolvería a sí mismo (%s).\n' "$dest" "$sreal" >&2
    printf '       No se escribió nada. Corré install.sh desde el checkout del producto,\n' >&2
    printf '       nunca a través de un enganche ya instalado.\n' >&2
    exit 1
  fi
}

guard_selflink "$brain/.os/core" "$core"
for pack in "$product"/packs/*; do
  [ -d "$pack" ] || continue
  guard_selflink "$brain/.os/packs/$(basename "$pack")" "$pack"
done
for agent in "$core"/agents/*.md; do
  [ -f "$agent" ] || continue
  guard_selflink "$brain/.claude/agents/$(basename "$agent")" "$agent"
done
guard_selflink "$claude" "$claude_target"

mkdir -p "$brain/.os/packs"
ln -sfn "$core" "$brain/.os/core"

for pack in "$product"/packs/*; do
  [ -d "$pack" ] || continue
  ln -sfn "$pack" "$brain/.os/packs/$(basename "$pack")"
done

mkdir -p "$brain/.claude/agents"

# Removes dangling symlinks from a previous install: a renamed agent (spec 033) leaves its old
# symlink behind, which `ln -sfn` does not overwrite because the file name changed, not the
# content. It only gets removed if both conditions hold at once:
#   1. it is dangling — `[ -e ]` on the symlink follows the link and is false if the target does
#      not exist. A live symlink (the agent is still there, or the operator points somewhere else
#      on purpose) is never touched.
#   2. the link's text — unresolved, exactly as `ln` wrote it — ends in `/core/agents/<name>.md`.
#      It does not require resolving INSIDE this checkout: if the whole product moved folders, or
#      the brain was installed from a different checkout of this same product, the old symlink
#      points at a `core/agents/` that is no longer there — resolving it by physical path would
#      give nothing and it would stay dangling next to the new one. The raw text is still
#      recognizable even when the path no longer exists.
# A real file never enters here: the first check is `[ -L ]`.
for existing in "$brain/.claude/agents"/*; do
  [ -L "$existing" ] || continue
  [ -e "$existing" ] && continue
  raw=$(readlink "$existing") || continue
  case "$raw" in
    */core/agents/*.md) rm -f "$existing" ;;
  esac
done

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

# ---------------------------------------------------------------- lectura liviana del catálogo
# Sin `lib/`: el instalador es lo primero que se corre y no puede depender del layout de lo que
# instala. La usan el aviso del nombre anterior de la carpeta y la línea de versión, más abajo.
catalogo_linea() {
  local key="$1" lang="$2" file="$core/templates/strings.md" line dentro=0 valor=""
  [ -f "$file" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      "key: $key") dentro=1; continue ;;
      'key: '*) [ "$dentro" = "1" ] && break; continue ;;
    esac
    [ "$dentro" = "1" ] || continue
    case "$line" in
      "$lang: "*) valor="${line#$lang: }"; break ;;
      'en: '*) [ -n "$valor" ] || valor="${line#en: }" ;;
    esac
  done < "$file"
  printf '%s' "$valor"
}

# ---------------------------------------------------------------- aviso del nombre anterior (P6, spec 039)
# Un brain con la carpeta de espacios de trabajo todavía en su nombre anterior sigue funcionando
# igual: esto avisa una vez, sin tocar nada — adoptar el nombre actual es `rename-workspaces`, a
# pedido del operador. Con las dos carpetas a la vez el layout es inválido y lo declara cualquier
# otro comando que lea o escriba el brain; el instalador no valida layout, solo avisa del caso simple.
if [ -d "$brain/orgs" ] && [ ! -d "$brain/workspaces" ]; then
  formato=$(catalogo_linea INSTALL_WS_OLD_NAME "$lang")
  [ -n "$formato" ] && printf '%s\n' "$formato"
fi

# ---------------------------------------------------------------- la versión que quedó instalada
# Última línea: el nombre del producto y la versión de `core/VERSION` (spec 038). El texto sale del
# catálogo (`core/templates/strings.md`, clave `INSTALL_VERSION_LINE`), nunca escrito acá: hasta el
# rename, el nombre que viaja adentro del producto vive en una clave y cambiarlo es un cambio de
# catálogo. Sin VERSION o sin la clave, no hay línea.
version=""
[ -f "$core/VERSION" ] && { IFS= read -r version < "$core/VERSION" || true; }
# Mismo saneo que `os_version` en `lib/common.sh`: un `\r` de fin de línea o un espacio de más en el
# archivo haría que el instalador imprima una versión y el barrido otra.
version="${version%$'\r'}"
while [ "${version# }" != "$version" ]; do version="${version# }"; done
while [ "${version% }" != "$version" ]; do version="${version% }"; done
if [ -n "$version" ]; then
  formato=$(catalogo_linea INSTALL_VERSION_LINE "$lang")
  [ -n "$formato" ] && printf "$formato\n" "$version"
fi
