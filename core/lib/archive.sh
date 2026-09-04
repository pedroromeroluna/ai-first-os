#!/usr/bin/env bash
# The command behind the rule that `core/CLAUDE.md` states about `archive/` (spec 048). Internal: not
# invocable — the invocable is `skills/archive.md`. The rule itself is not restated here.
#
# Usage: archive.sh --brain DIR --file PATH [--file PATH …]
#        archive.sh --brain DIR --file PATH [--file PATH …] --unarchive --to FOLDER
#        archive.sh --brain DIR --stale
#
# WHY A FOLDER, AND NOT A KEY. A frontmatter key that leaves the file where it is forces every read
# to open every document to learn whether it loads it, and that is exactly the property this system
# sells: what gets read is decided without opening anything. The folder is the answer, the same way
# the folder is what gives a node its type. It is PARA's Archive.
#
# WHAT ARCHIVING CHANGES, AND WHAT IT DOES NOT. It changes what a read **loads**: `focus-read.sh`
# prints the names of what an `archive:` line reaches and opens none of them. It changes nothing
# else — `supersede --check` still audits the file, `recall` still searches inside it, and the
# startup scan still counts it as reached. A document that stopped being loaded and also stopped
# being findable is a document that was lost, not archived.
#
# THE FILE IS MOVED, NEVER REWRITTEN. Same bytes, same name, same date in the name. `git mv` in a
# git brain — so the index records a rename and the history follows the file — and `mv -n` otherwise,
# never one that overwrites.
#
# THE ORDER, AND WHY IT IS THIS ONE (the same as `rename-heads.sh`):
#
#   1. The plan. Every `--file` is checked and its destination computed **before one byte moves**.
#      One file that fails a precondition cancels the whole batch: a half-applied batch whose
#      references were never rewritten is a brain that points at files that are not there, and the
#      operator would have to reconstruct by hand which half went through.
#   2. The moves, in the order of the plan.
#   3. The rewriting of references, once, with the map of everything that moved. Running it per file
#      would leave a reference pointing at a file that a later move takes away again.
#
# A MOVE THAT FAILS AFTER THE PLAN STOPS THE BATCH; IT DOES NOT ROLL IT BACK. A rollback is a second
# write path that can itself fail, and a failed rollback leaves a state nobody planned for. What
# stopping leaves is a state that re-running the same command finishes: the files that moved are
# already in `archive/` and their references already point there, and the ones that did not are
# exactly where they were.
#
# `superseded_by:` GETS NO SPECIAL CASE. Its value is a path, the rewrite is over paths, and the one
# walk covers both directions — the mark written **on** the file that moved, and the mark on another
# file that **names** it. A file whose `superseded_by:` names another file in the same batch resolves
# because the rewrite runs after every move, over the full map.
#
# `--stale` IS THE ONLY THING THAT SUGGESTS ANYTHING, AND IT IS NOT AGE. It lists the files that
# carry a `superseded_by:` and are not reached by an `archive:` line — documents the brain itself
# already declared out of date and still keeps in the loaded set. Age is not staleness: a brief from
# July can be the most current document a node has. The startup scan gains no line for this: it reads
# the frontmatter of heads and never opens a content file (spec 045 decision 1, spec 046), so a line
# there would count half the files and present it as a check.
#
# Exit: 0 moved, or nothing to do · 1 invalid arguments, a refusal, or `--stale` with findings ·
#       2 a named file does not exist · 3 the batch stopped part-way through the moves.
#
# No `set -e`: a refusal is reported, never a stack trace.

set -u

here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"

nl=$(printf '\nx')
nl="${nl%x}"

# The name of the folder. One word, written once: the tree lines of `templates/tree.md`, the
# destination this command computes and the listing of `focus-read.sh` all mean this folder.
ARCHIVE_DIR="archive"

brain=""
files=""
unarchive=0
to=""
stale=0

while [ $# -gt 0 ]; do
  case "$1" in
    --brain) [ $# -ge 2 ] || os_die "--brain needs a value"; brain="$2"; shift 2 ;;
    --file) [ $# -ge 2 ] || os_die "--file needs a value"; files="$files$2$nl"; shift 2 ;;
    --to) [ $# -ge 2 ] || os_die "--to needs a value"; to="$2"; shift 2 ;;
    --unarchive) unarchive=1; shift ;;
    --stale) stale=1; shift ;;
    *) os_die "unknown argument: $1" ;;
  esac
done

[ -n "$brain" ] || os_die "missing --brain"
[ -d "$brain" ] || os_die "no such brain: $brain"
brain=$(cd "$brain" && pwd)

if [ "$stale" = "1" ]; then
  [ -z "$files" ] || os_die "--stale takes no --file"
  [ "$unarchive" = "0" ] || os_die "--stale and --unarchive are two different questions"
else
  [ -n "$files" ] || os_die "missing --file"
fi
if [ "$unarchive" = "1" ]; then
  # The folder a document came from is recorded nowhere — the move keeps the bytes and the name, and
  # nothing else. Guessing `research/` because most of them came from there is inventing a fact.
  [ -n "$to" ] || os_die "--unarchive needs --to <folder>: the folder a document came from is not recorded anywhere"
  case "$to" in
    */*|.|..|"$ARCHIVE_DIR") os_die "--to takes one folder name inside the node, and it is not $ARCHIVE_DIR" ;;
  esac
else
  [ -z "$to" ] || os_die "--to is only for --unarchive"
fi

os_ws_check "$brain"
lang=$(os_language "$brain")
os_lang_load "$lang"

# The three classes of the tree, from the one reader of the format.
heads=$(os_tree_files "$brain") || os_die "no tree.md to read in: $brain"
contents=$(os_tree_content_files "$brain") || os_die "no tree.md to read in: $brain"
archived=$(os_tree_archive_files "$brain") || archived=""

en_lista() {
  # en_lista RUTA LISTA
  case "$nl$2$nl" in *"$nl$1$nl"*) return 0 ;; esac
  return 1
}

alcanzado() {
  en_lista "$1" "$heads" && return 0
  en_lista "$1" "$contents" && return 0
  en_lista "$1" "$archived" && return 0
  return 1
}

head_file=$(os_head_file "$brain") || head_file="README.md"

# nodo_de CARPETA -> the nearest folder at or above CARPETA that holds a head, by stdout; empty if
# there is none. Walking up instead of counting slashes is what makes one command serve an
# initiative —whose documents sit in its own folder— and a product —whose documents sit one level
# down, in `research/` or `context/`— without either of them being a special case.
nodo_de() {
  local d="$1"
  while [ -n "$d" ] && [ "$d" != "." ]; do
    if en_lista "$d/$head_file" "$heads"; then printf '%s' "$d"; return 0; fi
    case "$d" in
      */*) d="${d%/*}" ;;
      *) d="" ;;
    esac
  done
  return 1
}

# ================================================================ --stale
# Writes nothing. Exits non-zero with findings, the shape of `supersede --check`, so it can hang off
# anything that reads an exit code.
if [ "$stale" = "1" ]; then
  n=0
  vistos="$nl"
  todos="$heads$nl$contents"
  while IFS= read -r f || [ -n "$f" ]; do
    [ -n "$f" ] || continue
    case "$vistos" in *"$nl$f$nl"*) continue ;; esac
    vistos="$vistos$f$nl"
    en_lista "$f" "$archived" && continue
    fm_read "$brain/$f"
    [ -n "$fm_superseded_by" ] || continue
    printf "$S_ARCHIVE_STALE_ROW\n" "$f" "$fm_superseded_by"
    n=$(( n + 1 ))
  done <<TODOS
$todos
TODOS
  if [ "$n" = "0" ]; then
    printf "$S_ARCHIVE_STALE_NONE\n"
    exit 0
  fi
  printf "$S_ARCHIVE_STALE_TOTAL\n" "$n"
  exit 1
fi

# ================================================================ (1) the plan
# Nothing below this point writes anything until the whole batch has passed. A refusal names the file
# and the reason, and the command exits without having touched the brain.
plan=""
destinos="$nl"
origenes="$nl"
rechazos=""
falta=0

rechazar() {
  rechazos="$rechazos$(printf "$S_ARCHIVE_REFUSED" "$1" "$2")$nl"
}

while IFS= read -r raw || [ -n "$raw" ]; do
  [ -n "$raw" ] || continue

  # The spelling of a path is not a way around the checks (spec 047): `./d/a.md`, `d//a.md` and
  # `d/a.md` are the same file here, and the plan is always built on the normalised form.
  f=$(os_rel_norm "$raw")
  if ! os_rel_ok "$f"; then rechazar "$raw" "$S_ARCHIVE_NOT_RELATIVE"; continue; fi
  case "$f" in
    *.md) ;;
    *) rechazar "$f" "$S_ARCHIVE_NOT_MD"; continue ;;
  esac
  # A file that is not there is said to be not there. `os_inside_brain` resolves the parent folder
  # and fails when it does not exist, so asking it first turns every typo into "resolves outside the
  # brain" — a refusal that sends the operator looking for a symlink that was never there. `..` and
  # an absolute path are already refused above, by `os_rel_ok`.
  if [ -L "$brain/$f" ]; then rechazar "$f" "$S_ARCHIVE_IS_A_LINK"; continue; fi
  if [ ! -f "$brain/$f" ]; then rechazar "$f" "$S_ARCHIVE_NOT_THERE"; falta=1; continue; fi
  if ! os_inside_brain "$brain" "$f"; then rechazar "$f" "$S_ARCHIVE_OUT_OF_BRAIN"; continue; fi
  if ! alcanzado "$f"; then rechazar "$f" "$S_ARCHIVE_NOT_IN_TREE"; continue; fi
  case "$origenes" in *"$nl$f$nl"*) rechazar "$f" "$S_ARCHIVE_TWICE"; continue ;; esac

  # Which node owns this file. It is not derivable from how deep the path is: an initiative keeps
  # its documents directly in its own folder (`<node>/x.md`) and a product keeps them one level
  # down (`<node>/research/x.md`). The node is the nearest folder above the file that holds a head
  # a `glob:` line reaches — the same definition of "node" the rest of the system uses, read again
  # instead of a second rule about depth.
  carpeta="${f%/*}"
  base="${f##*/}"
  nodo=$(nodo_de "$carpeta")
  if [ -z "$nodo" ]; then rechazar "$f" "$S_ARCHIVE_NOT_IN_A_NODE"; continue; fi

  if [ "$unarchive" = "1" ]; then
    if [ "$carpeta" != "$nodo/$ARCHIVE_DIR" ]; then rechazar "$f" "$S_ARCHIVE_NOT_ARCHIVED"; continue; fi
    destino="$nodo/$to/$base"
  else
    if [ "$carpeta" = "$nodo/$ARCHIVE_DIR" ]; then rechazar "$f" "$S_ARCHIVE_ALREADY"; continue; fi
    destino="$nodo/$ARCHIVE_DIR/$base"
  fi

  if [ -e "$brain/$destino" ]; then rechazar "$f" "$(printf "$S_ARCHIVE_DEST_TAKEN" "$destino")"; continue; fi
  case "$destinos" in *"$nl$destino$nl"*) rechazar "$f" "$(printf "$S_ARCHIVE_DEST_TAKEN" "$destino")"; continue ;; esac

  # The destination has to be a path the tree reaches, in the right class. Archiving into a folder no
  # `archive:` line reaches produces a document invisible to `supersede --check` and to `recall`: the
  # mark of vigency would be a promise nobody keeps (spec 047). Unarchiving into a folder no
  # `content:` line reaches is the same hole in the other direction.
  if [ "$unarchive" = "1" ]; then
    if ! os_tree_class_matches "$brain" "content" "$destino"; then
      rechazar "$f" "$(printf "$S_ARCHIVE_DEST_NOT_CONTENT" "$destino")"; continue
    fi
  else
    if ! os_tree_class_matches "$brain" "archive" "$destino"; then
      rechazar "$f" "$(printf "$S_ARCHIVE_DEST_NOT_ARCHIVE" "$destino")"; continue
    fi
  fi

  origenes="$origenes$f$nl"
  destinos="$destinos$destino$nl"
  plan="$plan$f$OS_SEP$destino$nl"
done <<ARCHIVOS
$files
ARCHIVOS

if [ -n "$rechazos" ]; then
  printf '%s' "$rechazos" >&2
  printf "$S_ARCHIVE_NOTHING_MOVED\n" >&2
  [ "$falta" = "1" ] && exit 2
  exit 1
fi

if [ -z "$plan" ]; then
  printf "$S_ARCHIVE_NOTHING_TO_DO\n"
  exit 0
fi

# ================================================================ (2) the moves
es_git=0
[ -d "$brain/.git" ] && es_git=1

mover() {
  if [ "$es_git" = "1" ]; then
    git -C "$brain" mv "$1" "$2" > /dev/null 2>&1 && return 0
  fi
  mv -n "$brain/$1" "$brain/$2" 2>/dev/null || return 1
  [ -e "$brain/$1" ] && return 1
  [ -e "$brain/$2" ] || return 1
  return 0
}

mapa=""
movidos=""
no_movidos=""
corte=0

while IFS= read -r registro || [ -n "$registro" ]; do
  [ -n "$registro" ] || continue
  origen="${registro%%$OS_SEP*}"
  destino="${registro#*$OS_SEP}"
  if [ "$corte" = "1" ]; then
    no_movidos="$no_movidos  $origen$nl"
    continue
  fi
  if ! mkdir -p "$brain/${destino%/*}" 2>/dev/null; then
    corte=1; no_movidos="$no_movidos  $origen$nl"; continue
  fi
  if ! mover "$origen" "$destino"; then
    corte=1; no_movidos="$no_movidos  $origen$nl"; continue
  fi
  mapa="$mapa$origen$OS_SEP$destino$nl"
  movidos="$movidos  $origen -> $destino$nl"
done <<PLAN
$plan
PLAN

# ================================================================ (3) the rewriting of references
# Once, with the full map. The rule —an exact token match, never by suffix; a bare name with no
# slash is never resolved against the folder— lives in `common.sh` and is shared with
# `rename-heads.sh`.
#
# The targets are every file the tree reaches, in all three classes: a reference to a research
# document lives in a resolver, in a decision, in another research document, and in an archived one.
# The list is what the tree says, never a hardcoded set — a hardcoded set is a reference this command
# silently leaves broken the day somebody adds a height.
reescritos=""
if [ -n "$mapa" ]; then
  OS_RW_MAP="$mapa"
  vistos="$nl"
  while IFS= read -r rel || [ -n "$rel" ]; do
    [ -n "$rel" ] || continue
    case "$vistos" in *"$nl$rel$nl"*) continue ;; esac
    vistos="$vistos$rel$nl"
    os_rw_file "$brain" "$rel"; rc_rw=$?
    case "$rc_rw" in
      0) reescritos="$reescritos  $rel$nl" ;;
      2) printf "$S_ARCHIVE_REWRITE_FAILED\n" "$rel" >&2; corte=1 ;;
    esac
  done <<OBJETIVOS
$heads
$contents
$archived
$destinos
OBJETIVOS
fi

# ================================================================ what happened
if [ -n "$movidos" ]; then
  if [ "$unarchive" = "1" ]; then printf "$S_ARCHIVE_UNARCHIVED\n"; else printf "$S_ARCHIVE_ARCHIVED\n"; fi
  printf '%s' "$movidos"
fi
if [ -n "$reescritos" ]; then
  printf "$S_ARCHIVE_REWROTE\n"
  printf '%s' "$reescritos"
fi
if [ -n "$no_movidos" ]; then
  printf "$S_ARCHIVE_STOPPED\n" >&2
  printf '%s' "$no_movidos" >&2
fi

# The brain is not committed here: the session commits, like everything else it writes.
[ "$corte" = "1" ] && exit 3
exit 0
