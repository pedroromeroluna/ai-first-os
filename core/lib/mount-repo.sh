#!/usr/bin/env bash
# Parte determinística de `mount-repo`: monta un repo git como cuerpo de un nodo. La entrevista la
# conduce core/skills/mount-repo.md. Interno: no es invocable.
#
# Uso: mount-repo.sh --brain DIR --head RUTA --remote REMOTE [--clone-root RUTA] [--new]
#
#   --head        la cabeza, relativa al brain: `workspaces/<slug>/initiatives/<nombre>/README.md`
#   --remote      lo que se escribe en `repo:` — el remote textual, nunca una ruta local
#   --clone-root  la raíz de clonado de esta máquina. Se pregunta una sola vez: si `mounts.md` ya la
#                 declara, esa gana y el argumento se ignora diciéndolo.
#   --new         the repo does not exist yet: instead of cloning, it is born from the product's
#                 scaffold (`templates/repo-scaffold/`), with its first commit on `main` and
#                 `origin` declared. The remote is never created and nothing is ever pushed: that
#                 escapes the system, and the commands to do it are printed for the operator (spec
#                 034, same pattern as `remote-backup.sh`).
#
# Los tres actos son uno solo —decidir construir y montar el repo son el mismo acto—: `repo:` en la
# cabeza, el clon plano fuera del brain, y la fila remote -> ruta local en la tabla del entorno.
# With `--new` the birth of the repo takes the clone's place: deciding to build, giving birth to the
# repo and mounting it are the same act too.
#
# Idempotente: montar dos veces el mismo remote no duplica la fila ni vuelve a clonar. Sobre una
# máquina nueva —la tabla no viaja— reconstruye el clon y la fila sin tocar la cabeza. `--new` is
# idempotent the same way: over a repo already born with this `origin`, it does not give birth again
# and the other four acts run — a birth interrupted halfway is resumed by re-running the same
# command.
#
# Everything the operator reads comes out of the bilingual catalog (`templates/strings.md`) in the
# brain's language, `en` as source (spec 033/034). What stays in Spanish and is not translated: the
# argument errors of `os_die` —they are read by whoever wires the command, not by the operator— and
# the header `mounts.md` is born with, which is file content and not a message.
#
# Exit: 0 montó o ya estaba · 2 argumentos o cabeza inválidos · 3 el remote no responde
#       4 la cabeza ya declara otro `repo:` · 5 la raíz de clonado falta o es inválida
#       6 falta `python3` — requisito duro del producto junto a `git` (spec 030)
#       7 `--new` on a remote that does answer: there is nothing to create (spec 034)
#       8 `--new`: the birth of the repo failed — the message names why (spec 034)
#
# Nada se escribe antes de que las seis validaciones pasen —siete con `--new`, que suma la del
# destino—: una negativa a mitad de camino deja el nodo montado a medias, que es peor que no
# montarlo.

set -u

here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"

brain=""
head_rel=""
remote=""
clone_root_arg=""
new=0

while [ $# -gt 0 ]; do
  case "$1" in
    --brain) brain="${2:-}"; shift 2 ;;
    --head) head_rel="${2:-}"; shift 2 ;;
    --remote) remote="${2:-}"; shift 2 ;;
    --clone-root) clone_root_arg="${2:-}"; shift 2 ;;
    # A flag with no value: the remote stays mandatory and textual with `--new` too — it is what
    # travels in `repo:` and what `origin` gets pointed at.
    --new) new=1; shift ;;
    *) os_die "argumento desconocido: $1" ;;
  esac
done

[ -n "$brain" ] || os_die "falta --brain"
[ -n "$head_rel" ] || os_die "falta --head"
[ -n "$remote" ] || os_die "falta --remote"
[ -d "$brain" ] || os_die "no existe el brain: $brain"

# Layout inválido frena acá, antes de escribir nada (P2, spec 039).
os_ws_check "$brain"

# ---------------------------------------------------------------- lo que se lee del remote
# remote_repo_name REMOTE -> the checkout name, the same one `git clone` uses with no destination
# argument. Stated once: the destination, the `--new` hint of exit 3 and the name offered to
# `gh repo create` all read it from here.
remote_repo_name() {
  local n="${1%/}"
  n="${n##*/}"
  n="${n##*:}"
  printf '%s' "${n%.git}"
}

# remote_github_slug REMOTE -> `owner/name` when the remote is a GitHub one, empty otherwise.
# Reads the two forms that travel in `repo:` (`git@github.com:owner/name(.git)` and
# `https://github.com/owner/name(.git)`, plus `ssh://git@github.com/owner/name.git`). The owner is
# what makes the difference: `gh repo create <name>` creates it under the authenticated user, so a
# remote naming another owner would end up pointing at a repo that is not the one that was created.
remote_github_slug() {
  local r="${1%/}" rest owner name
  r="${r%.git}"
  case "$r" in
    git@github.com:*) rest="${r#git@github.com:}" ;;
    ssh://git@github.com/*) rest="${r#ssh://git@github.com/}" ;;
    https://github.com/*) rest="${r#https://github.com/}" ;;
    http://github.com/*) rest="${r#http://github.com/}" ;;
    *) return 0 ;;
  esac
  owner="${rest%%/*}"
  name="${rest#*/}"
  # Exactly two segments: anything else is not a repo address and is not guessed at.
  case "$name" in ''|*/*) return 0 ;; esac
  [ -n "$owner" ] || return 0
  printf '%s/%s' "$owner" "$name"
}

# python3 es requisito duro del producto, junto a git (spec 030): el cuarto acto —autorizar el
# checkout para el harness— lo necesita para leer y escribir el JSON de settings.local.json. Se
# chequea antes de la primera escritura, con el mismo criterio que el resto de las validaciones.
# The language of what gets written is the brain's, declared once in `operator.md` (spec 021), and
# it is loaded before the first message: `os_language` runs in a subshell of its own, so the
# frontmatter it reads never lands on the head's.
language=$(os_language "$brain")
os_lang_load "$language"

command -v python3 > /dev/null 2>&1 || {
  printf '%s\n' "$S_MOUNT_NO_PYTHON3" >&2
  printf '%s\n' "$S_MOUNT_NOTHING_WRITTEN" >&2
  exit 6
}
# `pwd -P`, acá y en la raíz de clonado: el guard anti-anidado compara las dos rutas como texto, y
# con una sola de las dos resuelta a físico un symlink en el medio lo evade — el clon termina adentro
# del brain o de otro repo, que es justo lo que la forma repo evita. Las dos mitades tienen que estar
# en el mismo sistema de coordenadas o la comparación no significa nada.
brain=$(cd "$brain" && pwd -P)

mounts="$brain/$OS_MOUNTS_ARCHIVO"

# ---------------------------------------------------------------- 1. la cabeza
# Relativa al brain, como todas las rutas del sistema. Una absoluta funciona en una sola máquina, y
# una que sube con `..` escribe fuera del árbol.
case "$head_rel" in
  /*) printf "$S_MOUNT_HEAD_ABSOLUTE\n" "$head_rel" >&2; exit 2 ;;
  *..*) printf "$S_MOUNT_HEAD_ESCAPES\n" "$head_rel" >&2; exit 2 ;;
esac
head_abs="$brain/$head_rel"
if [ ! -f "$head_abs" ]; then
  printf "$S_MOUNT_HEAD_MISSING\n" "$head_rel" >&2
  exit 2
fi

fm_read "$head_abs"
if [ -n "$fm_roto" ]; then
  printf "$S_MOUNT_HEAD_FM_BROKEN\n" "$head_rel" "$fm_roto" >&2
  exit 2
fi

# Un `repo:` distinto ya escrito es del operador: dos cuerpos para una cabeza no lo resuelve un
# script. Se frena antes de tocar nada.
if [ -n "$fm_repo" ] && [ "$fm_repo" != "$remote" ]; then
  printf "$S_MOUNT_HEAD_REPO_CONFLICT\n" "$head_rel" "$fm_repo" >&2
  printf "$S_MOUNT_HEAD_REPO_CONFLICT_TAIL\n" "$remote" >&2
  exit 4
fi

# ---------------------------------------------------------------- 2. el remote responde
# Si no responde, no hay nada que montar: negarse antes de escribir es más barato que dejar una
# cabeza apuntando a un remote que no existe.
# The same check, read in both directions (spec 034): `--new` is for a remote that does NOT answer,
# so a live remote is its refusal — there is nothing to create, and the plain command mounts it.
# `GIT_TERMINAL_PROMPT=0` and stdin closed: over HTTPS with no stored credential, git asks for a
# user and a password on the terminal and the whole command hangs waiting for an answer nobody is
# going to type. With the prompt off it fails, which is the answer this check needs.
if GIT_TERMINAL_PROMPT=0 git ls-remote "$remote" > /dev/null 2>&1 < /dev/null; then
  if [ "$new" = "1" ]; then
    printf "$S_MOUNT_NEW_REMOTE_ALIVE\n" "$remote" >&2
    printf '%s\n' "$S_MOUNT_NOTHING_WRITTEN" >&2
    exit 7
  fi
elif [ "$new" = "0" ]; then
  printf "$S_MOUNT_REMOTE_DOWN\n" "$remote" >&2
  # A repo already born locally is not a repo that is missing: pointing at `--new` there would send
  # the operator to a command that is going to refuse. The hint reads the standard path —the only
  # one `--new` writes to— without touching anything.
  hint_root=$(os_mounts_clone_root "$mounts")
  [ -n "$hint_root" ] || hint_root="$clone_root_arg"
  hint_path="$hint_root/$(remote_repo_name "$remote")"
  if [ -n "$hint_root" ] && [ -d "$hint_path/.git" ] \
     && [ "$(git -C "$hint_path" remote get-url origin 2>/dev/null)" = "$remote" ]; then
    printf "$S_MOUNT_NEW_ALREADY_BORN_HINT\n" "$hint_path" >&2
  else
    printf '%s\n' "$S_MOUNT_NEW_HINT" >&2
  fi
  printf '%s\n' "$S_MOUNT_NOTHING_WRITTEN" >&2
  exit 3
fi

# ---------------------------------------------------------------- 3. la raíz de clonado
clone_root=$(os_mounts_clone_root "$mounts")
declarada=0
if [ -n "$clone_root" ]; then
  declarada=1
  if [ -n "$clone_root_arg" ] && [ "$clone_root_arg" != "$clone_root" ]; then
    printf "$S_MOUNT_CLONE_ROOT_DECLARED\n" "$clone_root"
  fi
else
  clone_root="$clone_root_arg"
fi

if [ -z "$clone_root" ]; then
  printf "$S_MOUNT_CLONE_ROOT_MISSING\n" "$OS_MOUNTS_ARCHIVO" >&2
  exit 5
fi

case "$clone_root" in
  /*) ;;
  *) printf "$S_MOUNT_CLONE_ROOT_RELATIVE\n" "$clone_root" >&2; exit 5 ;;
esac

# El cuerpo se clona plano y afuera: adentro del brain el brain deja de clonarse liviano, y adentro
# de otro repo aparecen repos anidados —gitlinks o submódulos—, que es el terreno que la forma repo
# evita. Se mira el ancestro existente más cercano: la raíz puede no existir todavía.
ancestro="$clone_root"
while [ ! -d "$ancestro" ]; do
  case "$ancestro" in
    */*) ancestro="${ancestro%/*}"; [ -n "$ancestro" ] || ancestro="/" ;;
    *) ancestro="/"; break ;;
  esac
done
ancestro=$(cd "$ancestro" && pwd -P)

case "$ancestro/" in
  "$brain"/*) printf "$S_MOUNT_CLONE_ROOT_IN_BRAIN\n" "$clone_root" >&2
              exit 5 ;;
esac

dentro_de_repo=""
d="$ancestro"
while :; do
  [ -e "$d/.git" ] && dentro_de_repo="$d"
  [ "$d" = "/" ] && break
  d="${d%/*}"
  [ -n "$d" ] || d="/"
done
if [ -n "$dentro_de_repo" ]; then
  printf "$S_MOUNT_CLONE_ROOT_IN_REPO\n" "$dentro_de_repo" >&2
  exit 5
fi

# ---------------------------------------------------------------- 4. el destino
nombre=$(remote_repo_name "$remote")
if [ -z "$nombre" ]; then
  printf "$S_MOUNT_NAME_UNDERIVABLE\n" "$remote" >&2
  exit 2
fi
destino="$clone_root/$nombre"
# The standard path is kept: with `--new` it is the only one where a repo is born, however the table
# may have moved `destino`.
destino_estandar="$destino"

# ---------------------------------------------------------------- 5. qué había ya montado
# Las filas del remote se juntan todas, no solo la última: una tabla con el mismo remote dos veces es
# ambigua, y elegir en silencio es la clase de barrido incompleto que el sistema prohíbe. Se usa la
# última —la más reciente— y se declara cuáles había.
fila_previa=""
filas_remote=""
n_filas=0
escanear_filas() {
  fila_previa=""
  filas_remote=""
  n_filas=0
  while IFS="$OS_SEP" read -r n r_remote r_ruta || [ -n "$n" ]; do
    [ -n "$n" ] || continue
    [ "$r_remote" = "$remote" ] || continue
    n_filas=$(( n_filas + 1 ))
    fila_previa="$n"
    [ -n "$filas_remote" ] && filas_remote="$filas_remote $n" || filas_remote="$n"
    [ -n "$r_ruta" ] && destino="$r_ruta"
  done <<FILAS
$(os_mounts_filas "$mounts")
FILAS
}

# lista_lineas "4 6 8" -> "line 4, 6 and 8", in the brain's language.
lista_lineas() {
  local acc="" x total=0 i=0
  for x in $1; do total=$(( total + 1 )); done
  for x in $1; do
    i=$(( i + 1 ))
    if [ "$i" = "1" ]; then acc="$x"
    elif [ "$i" = "$total" ]; then acc="$acc $S_MOUNT_TABLE_LINE_AND $x"
    else acc="$acc, $x"; fi
  done
  printf "$S_MOUNT_TABLE_LINE_LIST" "$acc"
}

escanear_filas

clonado=0
if [ -d "$destino/.git" ]; then
  clonado=1
fi

# ---------------------------------------------------------------- 6. el destino con `--new`
# A row pointing this remote somewhere else does not move a birth: with `--new` the repo is born at
# `<clone root>/<name>` and nowhere else — a stale row would give birth anywhere on the disk. Which
# one stays belongs to the operator, same criterion as a head that already declares another `repo:`.
ya_nacio=0
if [ "$new" = "1" ]; then
  if [ "$destino" != "$destino_estandar" ]; then
    printf "$S_MOUNT_NEW_ROW_ELSEWHERE\n" \
      "$OS_MOUNTS_ARCHIVO" "$destino" "$fila_previa" "$destino_estandar" >&2
    printf '%s\n' "$S_MOUNT_NOTHING_WRITTEN" >&2
    exit 5
  fi
  # A repo already born with this `origin` is the birth that already happened: same treatment as
  # "the checkout was already there" on the clone side. That is what makes an interrupted birth
  # resumable — without it, re-running is exit 5 and there is no way back.
  if [ -d "$destino/.git" ] \
     && [ "$(git -C "$destino" remote get-url origin 2>/dev/null)" = "$remote" ]; then
    ya_nacio=1
  elif [ -e "$destino" ]; then
    printf "$S_MOUNT_NEW_DEST_EXISTS\n" "$destino" >&2
    printf '%s\n' "$S_MOUNT_NOTHING_WRITTEN" >&2
    exit 5
  fi
fi

# repo_birth DEST NAME
# Writes the product's scaffold into DEST, makes the first commit on `main` and declares `origin`.
# The prose of every file comes out of `templates/strings.md` in the brain's language: one template
# tree, one translation per string — never a copy of the scaffold per language (spec 021).
# It never creates the remote and it never pushes: that escapes the system —something ends up in a
# person's account— and it is left printed for the operator, same pattern as `remote-backup.sh`.
# Leaves `generic_identity` at 1 when git had no identity configured and the commit had to be signed
# with the product's, and `birth_error` with the reason when it returns 1.
generic_identity=0
birth_error=""
repo_birth() {
  local dest="$1" name="$2" tpl="$here/../templates/repo-scaffold" d
  birth_error=""
  mkdir -p "$dest/.claude" "$dest/specs/done" "$dest/docs/postmortems" "$dest/docs/research" \
           "$dest/learnings" "$dest/evals" || { birth_error="mkdir $dest"; return 1; }
  os_render_lang "$tpl/CLAUDE.md" "$language" "NAME=$name" > "$dest/CLAUDE.md" \
    || { birth_error="CLAUDE.md"; return 1; }
  os_render_lang "$tpl/ARCHITECTURE.md" "$language" "NAME=$name" > "$dest/ARCHITECTURE.md" \
    || { birth_error="ARCHITECTURE.md"; return 1; }
  os_render_lang "$tpl/decisions.md" "$language" "NAME=$name" > "$dest/decisions.md" \
    || { birth_error="decisions.md"; return 1; }
  os_render_lang "$tpl/evals-run.sh" "$language" "NAME=$name" > "$dest/evals/run.sh" \
    || { birth_error="evals/run.sh"; return 1; }
  chmod +x "$dest/evals/run.sh" || { birth_error="chmod evals/run.sh"; return 1; }
  # The two files with no prose travel as they are: the harness guardrails —agents neither push nor
  # merge— and the ignore list that keeps a secret out of the first commit.
  cp "$tpl/settings.json" "$dest/.claude/settings.json" || { birth_error=".claude/settings.json"; return 1; }
  cp "$tpl/gitignore" "$dest/.gitignore" || { birth_error=".gitignore"; return 1; }
  # git does not track empty folders: without a keep file the taxonomy does not survive the first
  # clone, and the next agent finds a tree that is not the one that was born.
  for d in specs/done docs/postmortems docs/research learnings; do
    : > "$dest/$d/.gitkeep" || { birth_error="$d/.gitkeep"; return 1; }
  done

  git init --quiet "$dest" > /dev/null 2>&1 || { birth_error="git init"; return 1; }
  # `main` without depending on the git version: `git init -b main` needs 2.28 and the product asks
  # for no version of git. On an empty repo, moving HEAD is the same thing.
  git -C "$dest" symbolic-ref HEAD refs/heads/main > /dev/null 2>&1 \
    || { birth_error="git symbolic-ref"; return 1; }
  # `core.excludesFile` off for this one command: the operator's global ignore list is theirs, and
  # more than one has `.claude/` in it — with it applied, the repo would be born without the
  # guardrails file and the command would say it went fine. The scaffold's own `.gitignore` keeps
  # applying: what is off is the global list, not the repo's.
  git -C "$dest" -c core.excludesFile=/dev/null add -A > /dev/null 2>&1 \
    || { birth_error="git add"; return 1; }
  if ! git -C "$dest" commit -q -m "$S_REPO_FIRST_COMMIT" > /dev/null 2>&1; then
    # Same fallback as `bootstrap.sh` for a machine with no git identity configured: the repo being
    # born is worth more than the signature, and the fallback is declared, never silent.
    git -C "$dest" -c user.name="AI First OS" -c user.email="bootstrap@ai-first-os.local" \
      commit -q -m "$S_REPO_FIRST_COMMIT" > /dev/null 2>&1 || { birth_error="git commit"; return 1; }
    generic_identity=1
  fi
  # The guardrails are checked in the commit, not in the folder: whatever kept them out —a global
  # ignore, a failed copy— makes this a failed birth, never a birth reported as fine.
  git -C "$dest" ls-files --error-unmatch .claude/settings.json > /dev/null 2>&1 \
    || { birth_error=".claude/settings.json did not make it into the first commit"; return 1; }
  git -C "$dest" remote add origin "$remote" > /dev/null 2>&1 || { birth_error="git remote add"; return 1; }
  return 0
}

# ---------------------------------------------------------------- los cuatro actos
printf '%s\n' "$S_MOUNT_TITLE"

# --- el clon, o el nacimiento
if [ "$new" = "1" ]; then
  if [ "$ya_nacio" = "1" ]; then
    printf "$S_MOUNT_NEW_ALREADY_BORN\n" "$destino"
  else
    # Whether the clone root existed before decides what the cleanup can remove: "nothing was
    # written" is only true if what the command created is what gets removed.
    clone_root_existia=1
    [ -d "$clone_root" ] || clone_root_existia=0
    mkdir -p "$clone_root" || {
      printf "$S_MOUNT_CLONE_ROOT_UNWRITABLE\n" "$clone_root" >&2; exit 5; }
    if ! repo_birth "$destino" "$nombre"; then
      printf "$S_MOUNT_NEW_FAILED\n" "$birth_error" >&2
      rm -rf "$destino" 2>/dev/null
      [ "$clone_root_existia" = "1" ] || rmdir "$clone_root" 2>/dev/null
      if [ -e "$destino" ]; then
        printf "$S_MOUNT_NEW_LEFTOVER\n" "$destino" >&2
      else
        printf "$S_MOUNT_NEW_CLEANED\n" "$destino" >&2
        printf '%s\n' "$S_MOUNT_NOTHING_WRITTEN" >&2
      fi
      exit 8
    fi
    printf "$S_MOUNT_NEW_BORN\n" "$destino"
    [ "$generic_identity" = "0" ] || printf '%s\n' "$S_MOUNT_NEW_GENERIC_IDENTITY"
  fi
elif [ "$clonado" = "1" ]; then
  printf "$S_MOUNT_CHECKOUT_ALREADY\n" "$destino"
else
  if [ -e "$destino" ]; then
    printf "$S_MOUNT_DEST_NOT_REPO\n" "$destino" >&2
    printf '%s\n' "$S_MOUNT_NOTHING_WRITTEN" >&2
    exit 5
  fi
  mkdir -p "$clone_root" || {
    printf "$S_MOUNT_CLONE_ROOT_UNWRITABLE\n" "$clone_root" >&2; exit 5; }
  if ! git clone --quiet "$remote" "$destino" > /dev/null 2>&1; then
    printf "$S_MOUNT_CLONE_FAILED\n" "$remote" "$destino" >&2
    printf '%s\n' "$S_MOUNT_NOTHING_WRITTEN" >&2
    exit 3
  fi
  printf "$S_MOUNT_CHECKOUT\n" "$destino"
fi

# --- `repo:` en la cabeza
# En una máquina nueva la cabeza ya lo tiene —viaja con el brain— y la tabla no: reconstruir el
# montaje no la toca.
if [ "$fm_repo" = "$remote" ]; then
  printf "$S_MOUNT_HEAD_REPO_ALREADY\n" "$head_rel"
else
  if os_fm_set "$head_abs" repo "$remote"; then
    printf "$S_MOUNT_HEAD_REPO_WRITTEN\n" "$head_rel" "$remote"
  else
    printf "$S_MOUNT_HEAD_REPO_WRITE_FAILED\n" "$head_rel" >&2
    exit 2
  fi
fi

# --- la fila de la tabla del entorno
nacio=0
if [ ! -f "$mounts" ]; then
  nacio=1
  {
    printf '# Montajes — el entorno de esta máquina\n\n'
    printf 'Remote -> ruta local. Es dato de esta máquina y **no viaja**: en una máquina nueva no\n'
    printf 'está, los barridos reportan el montaje como no alcanzado y `mount-repo` sobre el mismo\n'
    printf 'remote lo reconstruye. Lo escribe `mount-repo`.\n\n'
    printf 'clone-root: `%s`\n\n' "$clone_root"
    printf '| Remote | Ruta local |\n'
    printf '|---|---|\n'
  } > "$mounts"
fi

# La raíz de clonado se pregunta una vez y queda escrita — también cuando la tabla la escribió alguien
# a mano y le falta la línea. Sin esto, una tabla nacida a mano vuelve a pedirla en cada corrida, que
# es la pregunta repetida que la decisión evita. Se inserta antes de la primera fila, y las filas
# corren dos líneas: por eso se vuelve a escanear.
if [ "$nacio" = "0" ] && [ "$declarada" = "0" ]; then
  tmp_mounts="$mounts.os-tmp"
  : > "$tmp_mounts"
  puesto=0
  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$puesto" = "0" ]; then
      case "$line" in
        '|'*) printf 'clone-root: `%s`\n\n' "$clone_root" >> "$tmp_mounts"; puesto=1 ;;
      esac
    fi
    printf '%s\n' "$line" >> "$tmp_mounts"
  done < "$mounts"
  [ "$puesto" = "1" ] || printf 'clone-root: `%s`\n' "$clone_root" >> "$tmp_mounts"
  mv "$tmp_mounts" "$mounts"
  printf "$S_MOUNT_TABLE_CLONE_ROOT_ADDED\n" "$OS_MOUNTS_ARCHIVO" "$clone_root"
  escanear_filas
fi

# Dos filas para el mismo remote no se resuelven en silencio: se usa la última y se dice cuáles había.
if [ "$n_filas" -gt 1 ]; then
  printf "$S_MOUNT_TABLE_MANY_ROWS\n" \
    "$OS_MOUNTS_ARCHIVO" "$n_filas" "$(lista_lineas "$filas_remote")"
fi

if [ -n "$fila_previa" ]; then
  printf "$S_MOUNT_TABLE_ROW_ALREADY\n" "$OS_MOUNTS_ARCHIVO" "$fila_previa"
else
  printf '| `%s` | `%s` |\n' "$remote" "$destino" >> "$mounts"
  printf '  %s: | `%s` | `%s` |\n' "$OS_MOUNTS_ARCHIVO" "$remote" "$destino"
fi
[ "$nacio" = "1" ] && printf "$S_MOUNT_TABLE_BORN\n" "$OS_MOUNTS_ARCHIVO"

# --- la autorización del checkout (spec 030)
# Montar y autorizar son el mismo acto: el checkout queda legible sin prompt para el harness desde
# la próxima sesión, sin que el operador tenga que ponerlo a mano.
os_settings_authorize "$brain" "$destino"
case "$?" in
  0) printf "$S_MOUNT_SETTINGS_ADDED\n" "$OS_SETTINGS_ARCHIVO" "$destino" ;;
  1) printf "$S_MOUNT_SETTINGS_ALREADY\n" "$OS_SETTINGS_ARCHIVO" ;;
  2) printf "$S_MOUNT_SETTINGS_INVALID\n" "$OS_SETTINGS_ARCHIVO" "$brain/$OS_SETTINGS_ARCHIVO" ;;
esac

# La tabla no viaja: la frontera es el gitignore del brain, y la escribe el comando que crea el
# archivo. Y como todo archivo de solo contenido, declara su altura: el `tree.md` del brain es una
# copia del template, así que agregar el glob al template no lo agrega a los brains ya bootstrapeados.
if os_gitignore_ensure "$brain" "$OS_MOUNTS_ARCHIVO"; then
  printf "$S_MOUNT_GITIGNORE_DECLARED\n" "$OS_MOUNTS_ARCHIVO"
fi
if os_gitignore_ensure "$brain" "$OS_SETTINGS_ARCHIVO"; then
  printf "$S_MOUNT_GITIGNORE_DECLARED\n" "$OS_SETTINGS_ARCHIVO"
fi
os_tree_ensure "$brain" "$OS_MOUNTS_ARCHIVO"
case "$?" in
  0) printf "$S_MOUNT_TREE_GLOB_DECLARED\n" "$OS_MOUNTS_ARCHIVO" ;;
  2) printf "$S_MOUNT_TREE_MISSING\n" "$OS_MOUNTS_ARCHIVO" ;;
esac

# --- el remoto que todavía no existe (spec 034)
# Last lines of the birth, and the only thing left outside the system: the repo lives locally with
# `origin` declared, and creating the remote is the operator's act. `gh auth status` only reads; no
# other `gh` command runs from here, and nothing is ever pushed.
# Two commands, never `--source … --push`: over a checkout that already declares `origin`, gh adds
# the remote unconditionally, fails with "Unable to add remote origin" and does not push. And the
# name it is given is `owner/name` read from the remote itself: `gh repo create <name>` creates it
# under the authenticated user, which is not the owner the remote names.
if [ "$new" = "1" ]; then
  slug=$(remote_github_slug "$remote")
  autenticado=0
  if command -v gh > /dev/null 2>&1; then
    if gh auth status > /dev/null 2>&1 < /dev/null; then
      autenticado=1
    fi
  fi
  if [ "$autenticado" = "1" ] && [ -n "$slug" ]; then
    printf '%s\n' "$S_MOUNT_NEW_REMOTE_GH"
    printf "$S_MOUNT_NEW_REMOTE_GH_CREATE\n" "$slug"
  else
    printf "$S_MOUNT_NEW_REMOTE_MANUAL\n" "${slug:-$nombre}"
  fi
  printf "$S_MOUNT_NEW_REMOTE_PUSH\n" "$destino"
fi

exit 0
