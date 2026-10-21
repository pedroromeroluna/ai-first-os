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
#      `LC_ALL=C sort` by path — for an area node (a product, a course, a channel, an account) that is
#      its generated `index.md` (spec 076, C20), **printed only between the lines `<!-- os:focus-start -->`
#      and `<!-- os:focus-end -->`** (neither included): the table of the initiatives in progress and
#      nothing else, not the title, the warning or what comes below (spec 079, C4). An index written by
#      spec 078 has only the end line and prints from its first line up to it; an index without the end
#      line prints whole, and so does one written by a person. A generated index whose table has no
#      initiative row prints nothing. An initiative has no generated index (spec 079, C10); a generated
#      `index.md` in its folder is not printed at all
#   3. when the focus is an area node: its own `.resolver.md`, when a `glob:` line reaches it (spec
#      076, C15), and its key decisions (see 6)
#   4. only if that head declares `about:` — for each path it names, in the order of the list (spec
#      076, C16): the head it names, the `.resolver.md` next to that head when a `glob:` line reaches
#      it, and that node's key decisions (see 6)
#   5. the **names** of what an `archive:` line reaches directly inside that node's folder — never
#      their bodies (spec 048)
#   6. key decisions (spec 069, revised by spec 076 C19): the decisions of the node's workspace
#      (`<workspaces-dir>/<ws>/decisions/`) whose frontmatter carries `key:`, that are not replaced and
#      whose `about:` names that node — read from each file's frontmatter, never from an index —
#      printed right after that node's head and resolver, under the fixed marker
#      `key-decisions: <workspaces-dir>/<ws>/decisions/`. Lines only, never the bodies they link to.
#      The key decisions that name no node are the startup read's (`session-read.sh`) and are not
#      repeated here.
#
# ONE JUMP IS ONE JUMP. Step 4 reads the `about:` of the focus and of nothing else: the head loaded
# there may declare its own `about:`, and it is not followed. The value of this system is that the
# startup never opens a body; a load that chains would read half the brain to answer one question,
# and it would do it silently, growing with every link an operator adds. The bound is not a number
# to tune — it is one level, always.
#
# WHAT IS NOT LOADED, AND WHY.
#   · The decisions about the node named by `about:`, except its key decisions (step 6): they are
#     unbounded, and what they hold is why past decisions were taken, not what this node is. Only the
#     key ones not replaced are loaded, as lines; every other one, and every body, stays out. The
#     `index.md` of that node is not loaded either: it is the node's own view, and the focus on an
#     initiative is about the initiative (spec 076, C20).
#   · Whatever a `content:` line reaches **under** that node —its `context/`, its `research/`—: those
#     are the documents the node accumulates, and loading them turns one jump into the whole folder.
#   · The body of any node other than the focus.
#   · Anything a second `about:` names.
#   · The body of anything an `archive:` line reaches. Step 5 prints file names and nothing else:
#     archiving a document is the operator saying it is no longer what you read to work, and a
#     listing that opened them would put back exactly the cost the archive exists to remove. The
#     folder is the index — there is no file to keep in sync — and `recall` is what searches inside.
# The pair loaded in step 4 —a head and the `.resolver.md` beside it— is the same pair the startup
# read already loads for a workspace (`session-read.sh`, steps 2 and 3): what "loading a
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
#   - The key decisions open with the fixed marker `key-decisions: <workspaces-dir>/<ws>/decisions/`
#     —English in both languages— and one index line per decision, its link relative to that folder.
#     A node with none prints no marker and no lines.
#   - With a list, each path is its own jump in the order written: an unresolved one prints its
#     `about-unresolved:` line and the next one still loads.
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

# indice_generado ARCHIVO -> 0 when the file is a generated `index.md`. Reads its frontmatter.
indice_generado() {
  [ "${1##*/}" = "index.md" ] || return 1
  [ -f "$1" ] || return 1
  fm_read "$1"
  [ "$fm_generated" = "true" ]
}

# region_del_foco ARCHIVO -> the lines of a generated node index that the AI reads: those between `OS_FOCUS_START`
# and `OS_FOCUS_END`, or from the first line when the index has no start line (spec 078).
region_del_foco() {
  local line buf="" dentro=0
  grep -qxF -- "$OS_FOCUS_START" "$1" || dentro=1
  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$line" = "$OS_FOCUS_END" ]; then break; fi
    if [ "$dentro" = "1" ]; then
      buf="$buf$line$nl"
    elif [ "$line" = "$OS_FOCUS_START" ]; then
      dentro=1
    fi
  done < "$1"
  printf '%s' "$buf"
}

# indice_oculto RUTA -> 0 when the AI reads nothing from that file (spec 078, C4, C5; spec 079, C4, C9, C10): the
# generated index of an initiative left by spec 078, and the generated index of a node whose region holds no
# row of an initiative in progress. The one place that decides it; `cuerpo` is the one place that prints, so no
# route (the head, a jump, the body of the node) can print what this hides, or what the markers cut.
indice_oculto() {
  local f="$brain/$1" region
  indice_generado "$f" || return 1
  case "$1" in */initiatives/*/index.md) return 0 ;; esac
  grep -qxF -- "$OS_FOCUS_END" "$f" || return 1
  region=$(region_del_foco "$f")
  case "$nl$region" in *"$nl| ["*) return 1 ;; esac
  return 0
}

# cuerpo ARCHIVO — the bytes of the file, plus the closing newline it may not have. A generated index with
# the end marker prints only its region; one that `indice_oculto` hides prints nothing.
cuerpo() {
  local last rel="${1#"$brain"/}" buf
  [ -s "$1" ] || return 0
  if indice_generado "$1"; then
    indice_oculto "$rel" && return 0
    if grep -qxF -- "$OS_FOCUS_END" "$1"; then
      buf=$(region_del_foco "$1")
      [ -z "$buf" ] || printf '%s\n' "$buf"
      return 0
    fi
  fi
  cat "$1"
  last=$(tail -c 1 "$1")
  if [ -n "$last" ]; then printf '\n'; fi
  return 0
}

# emitir RUTA — one entry: its header and its body, or its `missing:` line.
impresos="$nl"
emitir() {
  if [ -f "$brain/$1" ] && indice_oculto "$1"; then impresos="$impresos$1$nl"; return 0; fi
  separar
  impresos="$impresos$1$nl"
  if [ -f "$brain/$1" ]; then
    printf '── %s\n' "$1"
    cuerpo "$brain/$1"
  else
    printf '── '
    printf "$S_SESSION_READ_MISSING\n" "$1"
  fi
  return 0
}

wsdir=$(os_ws_dir "$brain")
tipo_foco=""

# claves HEAD — step 6: the key decisions about one area node, read from the frontmatter of each
# decision of its workspace. Nothing for a head that is not an area node.
claves() {
  local lineas ws
  case "$(os_head_kind "$wsdir" "$head_file" "$1")" in
    entity\ *) ws="${1#"$wsdir"/}"; ws="${ws%%/*}" ;;
    *) return 0 ;;
  esac
  lineas=$(os_key_decisions "$brain" "$wsdir/$ws" "$1")
  [ -n "$lineas" ] || return 0
  separar
  printf 'key-decisions: %s/decisions/\n' "$wsdir/$ws"
  printf '%s\n' "$lineas"
  return 0
}

# resolver_de HEAD — the `.resolver.md` beside a head, when a `glob:` line reaches it (spec 076, C15).
resolver_de() {
  local d="${1%/*}"
  [ "$d" != "$1" ] || return 0
  es_cabeza "$d/.resolver.md" || return 0
  case "$impresos" in *"$nl$d/.resolver.md$nl"*) return 0 ;; esac
  emitir "$d/.resolver.md"
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
  # `sort -u`: two `content:` lines that reach the same file —two sessions declaring it at once
  # (spec 072)— must not print its body twice.
  # What a generated index prints is decided in `cuerpo` and `indice_oculto`, for every route.
  while IFS= read -r f || [ -n "$f" ]; do
    [ -n "$f" ] || continue
    emitir "$f"
  done <<ORDENADOS
$(printf '%s' "$cuerpos" | LC_ALL=C sort -u)
ORDENADOS
fi

# ---------------------------------------------------------------- 3 · an area node's own resolver and key decisions
case "$(os_head_kind "$wsdir" "$head_file" "$focus")" in
  entity\ *) resolver_de "$focus"; claves "$focus" ;;
esac

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

# A value that is not written as a list but names more than one path is one unresolved value, as
# before spec 076; the list form `[<path>, <path>]` is split by `os_about_values`.
about_raw="$fm_about"
case "$about_raw" in
  '['*']') valores=$(os_about_values "$about_raw") ;;
  *) valores="$about_raw" ;;
esac

saltar() {
  # saltar VALUE — one jump: the checks, then the head, its resolver and its key decisions.
  local valor="$1" destino motivo=""
  destino=$(os_rel_norm "$valor")
  case "$valor" in
    *,*|*' '*|'') motivo="$S_ABOUT_IS_A_LIST" ;;
  esac
  if [ -z "$motivo" ] && ! os_rel_ok "$destino"; then motivo="$S_ABOUT_NOT_RELATIVE"; fi
  if [ -z "$motivo" ] && ! es_cabeza "$destino"; then motivo="$S_ABOUT_NOT_A_HEAD"; fi
  if [ -z "$motivo" ] && [ "$destino" = "$focus" ]; then motivo="$S_ABOUT_SELF"; fi
  if [ -z "$motivo" ] && [ -L "$brain/$destino" ]; then motivo="$S_ABOUT_IS_A_LINK"; fi
  if [ -z "$motivo" ] && ! os_inside_brain "$brain" "$destino"; then motivo="$S_ABOUT_OUT_OF_BRAIN"; fi

  if [ -n "$motivo" ]; then
    separar
    printf "$S_FOCUS_ABOUT_UNRESOLVED\n" "$valor" "$motivo"
    return 0
  fi

  separar
  # Fixed marker, in English, the same in both languages: `core/CLAUDE.md` matches it as a structural
  # identifier, not as translatable prose — the same criterion as `active-role:` (spec 009).
  printf 'about-jump: %s\n' "$destino"
  printf '── %s\n' "$destino"
  impresos="$impresos$destino$nl"
  cuerpo "$brain/$destino"
  resolver_de "$destino"
  claves "$destino"
  return 0
}

while IFS= read -r v || [ -n "$v" ]; do
  saltar "$v"
done <<VALORES
$valores
VALORES

listar_archivado

exit 0
