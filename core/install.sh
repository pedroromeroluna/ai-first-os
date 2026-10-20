#!/usr/bin/env bash
# command: install.sh
# Engancha el producto a un brain por symlink. Idempotente: correrlo dos veces no cambia nada.
#
# Uso: install.sh RUTA-BRAIN [--adopt]
#
# Qué deja en el brain:
#   AGENTS.md            -> symlink al contrato de sesión del producto (lo leen Codex, Cursor, OpenCode)
#   .claude/CLAUDE.md    -> symlink al mismo contrato (lo lee Claude Code)
#   .os/core             -> symlink a core/
#   .os/packs/<pack>     -> symlink a cada pack
#   .claude/agents/<n>   -> symlink a cada agente de core/agents/, uno por archivo (el harness del
#                            operador los lee de ahí; symlinkear el directorio entero se
#                            llevaría por delante configuración propia del operador en .claude/)
# No crea CLAUDE.md en la raíz (spec 076): un CLAUDE.md que ya sea un enlace al producto, de una
# instalación anterior, se deja como está.
#
# Los dos enlaces se crean siempre; el instalador no pregunta con qué agente se va a trabajar.
#
# Si el producto instalado es una copia (su raíz no tiene `.git`), el contrato queda en solo lectura:
# editarlo cambia el sistema de todos los que lo usan. En un checkout de desarrollo no se tocan los
# permisos y una línea lo dice.
#
# --adopt: si el brain ya tiene un reglamento que no es el de este producto —un archivo propio o un
# symlink a otro— en `CLAUDE.md`, `AGENTS.md` o `.claude/CLAUDE.md`, su contenido se agrega al final de
# `account/operator.md` (en ese orden), el archivo ajeno se borra y queda el enlace al producto. Sin
# --adopt el instalador para y no toca nada. `--adopt` necesita que `account/operator.md` exista (el
# bootstrap lo escribe): sin él, frena y no toca nada.

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

# El idioma del brain, leído una sola vez acá: lo usan los avisos del catálogo y la línea de versión,
# más abajo. Mismo criterio liviano que el resto de este script — sin `lib/`, porque el instalador es
# lo primero que corre.
lang="en"
# A brain not migrated yet still has its `operator.md` at the root: its language is read from there so
# the messages come out in the language the operator chose (the file is only read, never moved).
lang_file="$brain/account/operator.md"
[ -f "$lang_file" ] || lang_file="$brain/operator.md"
if [ -f "$lang_file" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      'language: '*)
        case "${line#language: }" in en) lang="en" ;; es) lang="es" ;; esac
        break
        ;;
    esac
  done < "$lang_file"
fi

claude="$brain/CLAUDE.md"
agents="$brain/AGENTS.md"
claude_dir="$brain/.claude/CLAUDE.md"
claude_target="$core/CLAUDE.md"
operator_file="$brain/account/operator.md"
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

# Destino real de un symlink, siguiendo la cadena de enlaces (hasta 10 saltos).
resolve_chain() {
  local cur="$1" hops=0 next
  while [ -L "$cur" ] && [ "$hops" -lt 10 ]; do
    next=$(resolve_link "$cur")
    [ -n "$next" ] || return 0
    cur="$next"
    hops=$(( hops + 1 ))
  done
  printf '%s' "$cur"
}

# Chequeo antes de tocar nada. Adoptar es para un reglamento **ajeno**: un archivo propio del
# operador, o un symlink vivo hacia otro producto. Lo que no es adopción es re-instalación, y se
# relinkea callado: un symlink colgado —el producto se movió— y uno que ya apunta acá escrito de
# otra forma. Comparar por cadena de ruta trataba a los dos como ajenos: al colgado lo "adoptaba"
# y al otro le pedía --adopt sin motivo. Se chequean los tres lugares donde un harness carga un
# reglamento: `CLAUDE.md`, `AGENTS.md` y `.claude/CLAUDE.md` (spec 076), en ese orden.
foreign=()
for loc in "$claude" "$agents" "$claude_dir"; do
  if [ -L "$loc" ]; then
    if [ -e "$loc" ] && [ "$(resolve_chain "$loc")" != "$core_real/CLAUDE.md" ]; then
      foreign+=("$loc")
    fi
  elif [ -e "$loc" ]; then
    foreign+=("$loc")
  fi
done

if [ "${#foreign[@]}" -gt 0 ]; then
  if [ "$adopt" = "0" ]; then
    formato=$(catalogo_linea INSTALL_FOREIGN_CONTRACT "$lang")
    printf "$formato\n" "${foreign[*]}" >&2
    exit 1
  fi
  if [ ! -f "$operator_file" ]; then
    formato=$(catalogo_linea INSTALL_ADOPT_NEEDS_OPERATOR "$lang")
    printf "$formato\n" "$operator_file" >&2
    exit 1
  fi
  # Snapshot of every foreign source, taken before ANY link is touched (`.os/core` included: a foreign
  # `AGENTS.md` that points at the `.os/core/CLAUDE.md` of another product reads that product's text
  # only until this installer relinks `.os/core`). Each source must resolve to a readable regular
  # file; a link to a folder, or an unreadable file, stops the run before anything is written.
  # Aliases are deduped by their resolved target (`AGENTS.md` -> `CLAUDE.md` is one text, not two).
  stage_dir=$(mktemp -d)
  trap 'rm -rf "$stage_dir"' EXIT
  n_snap=0
  seen_real=""
  snap_labels=()
  for loc in "${foreign[@]}"; do
    if [ -L "$loc" ]; then
      real=$(resolve_chain "$loc")
    else
      real="$(cd -P "$(dirname "$loc")" 2>/dev/null && pwd -P)/$(basename "$loc")"
    fi
    if [ -z "$real" ] || [ ! -f "$real" ] || [ ! -r "$real" ]; then
      formato=$(catalogo_linea INSTALL_ADOPT_NOT_A_FILE "$lang")
      printf "$formato\n" "$loc" >&2
      exit 1
    fi
    case "
$seen_real
" in
      *"
$real
"*) continue ;;
    esac
    seen_real="$seen_real
$real"
    n_snap=$(( n_snap + 1 ))
    cp "$real" "$stage_dir/src-$n_snap"
    snap_labels+=("${loc#$brain/}")
  done
  # The complete new `account/operator.md`, staged: written in one step further down, so a stop
  # anywhere before it leaves the file as it was and a retry never doubles the heading or a text.
  cat "$operator_file" > "$stage_dir/operator.new"
  if [ -s "$operator_file" ] && [ -n "$(tail -c 1 "$operator_file")" ]; then
    printf '\n' >> "$stage_dir/operator.new"
  fi
  printf '\n## %s\n' "$(catalogo_linea INSTALL_ADOPTED_HEADING "$lang")" >> "$stage_dir/operator.new"
  i_snap=0
  for label in "${snap_labels[@]}"; do
    i_snap=$(( i_snap + 1 ))
    printf '\n### %s\n\n' "$label" >> "$stage_dir/operator.new"
    cat "$stage_dir/src-$i_snap" >> "$stage_dir/operator.new"
    if [ -s "$stage_dir/src-$i_snap" ] && [ -n "$(tail -c 1 "$stage_dir/src-$i_snap")" ]; then
      printf '\n' >> "$stage_dir/operator.new"
    fi
  done
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
guard_selflink "$agents" "$claude_target"
guard_selflink "$claude_dir" "$claude_target"

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

# Adoptar (spec 076, C4): el contenido de cada reglamento ajeno va al final de `account/operator.md`,
# bajo un encabezado fijo del catálogo y en el orden CLAUDE.md, AGENTS.md, .claude/CLAUDE.md; el
# archivo ajeno se borra y queda el enlace. Nada de esto corre antes de que todos los chequeos de
# arriba hayan pasado.
if [ "${#foreign[@]}" -gt 0 ]; then
  cat "$stage_dir/operator.new" > "$operator_file"
  # `AGENTS.md` and `.claude/CLAUDE.md` are replaced by their links below; only a foreign root
  # `CLAUDE.md` (file or link) has no link to take its place and is removed.
  for loc in "${foreign[@]}"; do
    [ "$loc" = "$claude" ] && rm -f "$claude"
  done
  formato=$(catalogo_linea INSTALL_ADOPTED_NOTICE "$lang")
  printf "$formato\n" "account/operator.md" >&2
fi

mkdir -p "$brain/.claude"
ln -sfn "$claude_target" "$agents"
ln -sfn "$claude_target" "$claude_dir"
# Un CLAUDE.md de la raíz que es un enlace roto, o ya apunta al producto, de una instalación anterior,
# se refresca para que no quede colgado; nunca se crea uno.
if [ -L "$claude" ]; then
  ln -sfn "$claude_target" "$claude"
fi

printf 'brain: %s\n' "$brain"
printf 'AGENTS.md -> %s\n' "$claude_target"
printf '.claude/CLAUDE.md -> %s\n' "$claude_target"
printf '.os/core -> %s\n' "$core"
for pack in "$product"/packs/*; do
  [ -d "$pack" ] || continue
  printf '.os/packs/%s -> %s\n' "$(basename "$pack")" "$pack"
done
for agent in "$core"/agents/*.md; do
  [ -f "$agent" ] || continue
  printf '.claude/agents/%s -> %s\n' "$(basename "$agent")" "$agent"
done

# ---------------------------------------------------------------- el contrato, en solo lectura (spec 076, C6)
# Una copia instalada del producto (su raíz no tiene `.git`) deja el contrato sin permiso de escritura:
# editarlo cambia el sistema de todos los que lo usan, y las reglas propias van en
# `account/operator.md`. Un checkout de desarrollo (con `.git`, carpeta o archivo de worktree) es
# donde el contrato se edita: no se toca ningún permiso y una línea lo dice. Solo se bloquea el
# contrato; nada más del brain ni del producto.
if [ -e "$product/.git" ]; then
  formato=$(catalogo_linea INSTALL_CONTRACT_DEV "$lang")
  [ -z "$formato" ] || printf '%s\n' "$formato"
else
  chmod a-w "$core/CLAUDE.md" 2>/dev/null || true
  # Say what actually happened: the permission is checked after the `chmod`, never assumed from it.
  if [ -w "$core/CLAUDE.md" ]; then
    formato=$(catalogo_linea INSTALL_CONTRACT_NOT_LOCKED "$lang")
    [ -z "$formato" ] || printf '%s\n' "$formato" >&2
  else
    formato=$(catalogo_linea INSTALL_CONTRACT_LOCKED "$lang")
    [ -z "$formato" ] || printf '%s\n' "$formato"
  fi
fi

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
