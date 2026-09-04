#!/usr/bin/env bash
# Focus read: what a session loads when the operator picks one node to work on (spec 049).
# Internal: not invocable — the session contract (core/CLAUDE.md) fires it the moment the operator
# names the focus, after the startup scan and the startup read.
#
# Usage: focus-read.sh --brain DIR --focus PATH
#
# `--focus` is the head of the node being worked on, relative to the brain — an initiative's head
# almost always, but any head a `glob:` line of `tree.md` reaches is a legitimate focus: the system
# has one primitive repeated at every height, and a command that only understood `initiatives/`
# would contradict it.
#
# READING ORDER — this comment is the only place the focus reading order is written down, and the
# body below is what executes it. Nothing else lists these files:
#
#   1. the head named by `--focus`
#   2. its body: the files a `content:` line reaches **directly inside** that node's folder,
#      `LC_ALL=C sort` by path
#   3. only if that head declares `about:` — the head it names
#   4. and the `resolver.md` next to that head, when a `glob:` line reaches it
#   5. the **names** of what an `archive:` line reaches directly inside that node's folder — never
#      their bodies (spec 048)
#
# ONE JUMP IS ONE JUMP. Step 3 reads the `about:` of the focus and of nothing else: the head loaded
# there may declare its own `about:`, and it is not followed. The value of this system is that the
# startup never opens a body; a load that chains would read half the brain to answer one question,
# and it would do it silently, growing with every link an operator adds. The bound is not a number
# to tune — it is one level, always.
#
# WHAT IS NOT LOADED, AND WHY.
#   · The `decisions.md` of the node named by `about:`: it is append-only and unbounded, and what it
#     holds is why past decisions were taken, not what this node is.
#   · Whatever a `content:` line reaches **under** that node —its `context/`, its `research/`—: those
#     are the documents the node accumulates, and loading them turns one jump into the whole folder.
#   · The body of any node other than the focus.
#   · Anything a second `about:` names.
#   · The body of anything an `archive:` line reaches. Step 5 prints file names and nothing else:
#     archiving a document is the operator saying it is no longer what you read to work, and a
#     listing that opened them would put back exactly the cost the archive exists to remove. The
#     folder is the index — there is no file to keep in sync — and `recall` is what searches inside.
# The pair loaded in steps 3 and 4 —a head and the `resolver.md` beside it— is the same pair the
# startup read already loads for a workspace (`session-read.sh`, steps 3 and 4): what "loading a
# node" means is stated once, and this command repeats the shape instead of inventing a second one.
#
# A file this command prints may carry the mark that says another file replaced it. Honouring that
# mark is the session's job and the rule is written once, in `core/CLAUDE.md`: this command does not
# follow it either — it prints files, it does not decide which of them is current.
#
# Output format, the same as `session-read.sh`:
#   - Header per file: `── <path relative to the brain>`.
#   - Body: the bytes of the file; a file that does not end in a newline gets one.
#   - A file that is not there prints `── missing: <path>` and no body, and never stops the read.
#   - Exactly one blank line between entries, nothing before the first.
#   - The jump opens with the fixed marker `about-jump: <path>` —English in both languages, like
#     `active-role:`— and the head's entry on the next line, with no blank line in between. The
#     marker is hyphenated because a plain `about:` at the start of a line is what the frontmatter
#     of a printed head looks like: a reader could not tell the jump from the file's own key.
#   - An `about:` that does not resolve prints `about-unresolved: <value> · <reason>` in place of
#     the jump and the read goes on: the startup scan is where a broken link is a finding, and a
#     read that dies over one leaves the operator with nothing.
#   - The archived listing opens with the fixed marker `archived: <n>` —English in both languages,
#     like `about-jump:`— and one `· <file name>` line per file, `LC_ALL=C sort`. A node with
#     nothing archived prints no marker and no lines.
#
# Exit: 0 the focus was read, with or without a jump and with or without missing files. 1 invalid
# arguments, or a `--focus` that is not a head the tree reaches. 2 the file named by `--focus` does
# not exist.
#
# No `set -e` on purpose: an unreadable file cannot abort the work the operator just picked.

set -u

here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"

nl=$(printf '\nx')
nl="${nl%x}"

brain=""
focus=""
# A flag that takes a value checks that the value is there before consuming it: with the flag as the
# last argument, `shift 2` fails without consuming anything and the loop repeats forever.
while [ $# -gt 0 ]; do
  case "$1" in
    --brain) [ $# -ge 2 ] || os_die "--brain needs a value"; brain="$2"; shift 2 ;;
    --focus) [ $# -ge 2 ] || os_die "--focus needs a value"; focus="$2"; shift 2 ;;
    *) os_die "unknown argument: $1" ;;
  esac
done

[ -n "$brain" ] || os_die "missing --brain"
[ -n "$focus" ] || os_die "missing --focus"
[ -d "$brain" ] || os_die "no such brain: $brain"
brain=$(cd "$brain" && pwd)

os_ws_check "$brain"
head_file=$(os_head_file "$brain") || true

lang=$(os_language "$brain")
os_lang_load "$lang"

focus=$(os_rel_norm "$focus")
os_rel_ok "$focus" || os_die "--focus is not a path relative to the brain: $focus"

# The two classes of tree line, read from the one reader of the format (`common.sh`). A brain whose
# tree cannot be read is not a brain this command can answer about: swallowing that would print the
# focus and no body, which reads exactly like a node with nothing in it.
heads=$(os_tree_files "$brain") || os_die "no tree.md to read in: $brain"
contents=$(os_tree_content_files "$brain") || os_die "no tree.md to read in: $brain"
archived=$(os_tree_archive_files "$brain") || archived=""

es_cabeza() {
  case "$nl$heads$nl" in *"$nl$1$nl"*) return 0 ;; esac
  return 1
}

if ! es_cabeza "$focus"; then
  if [ ! -f "$brain/$focus" ]; then
    printf "$S_FOCUS_NOT_A_HEAD\n" "$focus" >&2
    exit 2
  fi
  printf "$S_FOCUS_NOT_A_HEAD\n" "$focus" >&2
  exit 1
fi

primera=1

separar() {
  if [ "$primera" = "1" ]; then primera=0; else printf '\n'; fi
}

# cuerpo ARCHIVO — the bytes of the file, plus the closing newline it may not have.
cuerpo() {
  local last
  [ -s "$1" ] || return 0
  cat "$1"
  last=$(tail -c 1 "$1")
  if [ -n "$last" ]; then printf '\n'; fi
  return 0
}

# emitir RUTA — one entry: its header and its body, or its `missing:` line.
emitir() {
  separar
  if [ -f "$brain/$1" ]; then
    printf '── %s\n' "$1"
    cuerpo "$brain/$1"
  else
    printf '── '
    printf "$S_SESSION_READ_MISSING\n" "$1"
  fi
  return 0
}

# ---------------------------------------------------------------- 1 · the head of the focus
emitir "$focus"

# ---------------------------------------------------------------- 2 · its body
# Direct children of the node's folder, never everything underneath it. On an initiative the two are
# the same thing; on a node that keeps folders —a product with its `context/` and its `research/`—
# they are not, and reading everything underneath turns picking a focus into loading every dated
# document that node ever accumulated.
#
# A head that is not the node's folder head —a brain born before spec 040 keeps its initiatives as
# loose files— has no folder of its own: its siblings belong to other nodes, so nothing is added.
dir="${focus%/*}"
base="${focus##*/}"
if [ "$base" = "$head_file" ] && [ "$dir" != "$focus" ]; then
  cuerpos=""
  while IFS= read -r f || [ -n "$f" ]; do
    [ -n "$f" ] || continue
    [ "$f" = "$focus" ] && continue
    case "$f" in
      "$dir"/*) ;;
      *) continue ;;
    esac
    resto="${f#"$dir"/}"
    case "$resto" in */*) continue ;; esac
    cuerpos="$cuerpos$f$nl"
  done <<CONTENIDOS
$contents
CONTENIDOS
  while IFS= read -r f || [ -n "$f" ]; do
    [ -n "$f" ] || continue
    emitir "$f"
  done <<ORDENADOS
$(printf '%s' "$cuerpos" | LC_ALL=C sort)
ORDENADOS
fi

# ---------------------------------------------------------------- 5 · what is archived, by name
# Runs on every exit path of this script, because the operator's answer to "what does this node have
# that I am not reading" cannot depend on whether the head declared an `about:`.
#
# Same "direct children" rule as step 2, one level deeper: a file an `archive:` line reaches whose
# path, relative to the node's folder, is `<folder>/<name>` or `<name>`. A node that holds other
# nodes does not list the archives of the nodes under it: three segments away is somebody else's
# node, and listing those would make one focus grow with every node somebody adds beneath it.
listar_archivado() {
  local f resto lista="" n=0
  [ -n "$archived" ] || return 0
  [ "$base" = "$head_file" ] && [ "$dir" != "$focus" ] || return 0
  while IFS= read -r f || [ -n "$f" ]; do
    [ -n "$f" ] || continue
    case "$f" in
      "$dir"/*) ;;
      *) continue ;;
    esac
    resto="${f#"$dir"/}"
    case "$resto" in
      */*/*) continue ;;
    esac
    lista="$lista${f##*/}$nl"
    n=$(( n + 1 ))
  done <<ARCHIVADOS
$archived
ARCHIVADOS
  [ "$n" -gt 0 ] || return 0
  separar
  # Fixed marker, in English, the same in both languages — the criterion of `about-jump:` and
  # `active-role:`: a reader matches it as a structural identifier, not as translatable prose.
  printf 'archived: %s\n' "$n"
  while IFS= read -r f || [ -n "$f" ]; do
    [ -n "$f" ] || continue
    printf '· %s\n' "$f"
  done <<ORDENADOS
$(printf '%s' "$lista" | LC_ALL=C sort)
ORDENADOS
  return 0
}

# ---------------------------------------------------------------- 3 y 4 · the jump
# The same checks the startup scan applies to the key, because the answer to "does this link resolve"
# has to be the same in both places: normalised, relative to the brain, a single path, a head a
# `glob:` line reaches, not a symbolic link, and not resolving out of the brain.
fm_read "$brain/$focus"
if [ -n "$fm_roto" ]; then
  printf '\n'
  printf "$S_FOCUS_UNREADABLE_HEAD\n" "$fm_roto"
  listar_archivado
  exit 0
fi
if [ -z "$fm_about" ]; then
  listar_archivado
  exit 0
fi

destino=$(os_rel_norm "$fm_about")
motivo=""
case "$fm_about" in
  *,*|*' '*) motivo="$S_ABOUT_IS_A_LIST" ;;
esac
if [ -z "$motivo" ] && ! os_rel_ok "$destino"; then motivo="$S_ABOUT_NOT_RELATIVE"; fi
if [ -z "$motivo" ] && ! es_cabeza "$destino"; then motivo="$S_ABOUT_NOT_A_HEAD"; fi
if [ -z "$motivo" ] && [ "$destino" = "$focus" ]; then motivo="$S_ABOUT_SELF"; fi
if [ -z "$motivo" ] && [ -L "$brain/$destino" ]; then motivo="$S_ABOUT_IS_A_LINK"; fi
if [ -z "$motivo" ] && ! os_inside_brain "$brain" "$destino"; then motivo="$S_ABOUT_OUT_OF_BRAIN"; fi

if [ -n "$motivo" ]; then
  printf '\n'
  printf "$S_FOCUS_ABOUT_UNRESOLVED\n" "$fm_about" "$motivo"
  listar_archivado
  exit 0
fi

printf '\n'
# Fixed marker, in English, the same in both languages: `core/CLAUDE.md` matches it as a structural
# identifier, not as translatable prose — the same criterion as `active-role:` (spec 009).
printf 'about-jump: %s\n' "$destino"
printf '── %s\n' "$destino"
cuerpo "$brain/$destino"

destino_dir="${destino%/*}"
if [ "$destino_dir" != "$destino" ] && es_cabeza "$destino_dir/resolver.md"; then
  primera=0
  emitir "$destino_dir/resolver.md"
fi

primera=0
listar_archivado

exit 0
