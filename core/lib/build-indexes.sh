#!/usr/bin/env bash
# Generates the indexes of one workspace (spec 076, C18). Internal: not invocable — the startup read
# (`session-read.sh`) runs it on every read; the startup scan never does, because the scan never
# writes (spec 072).
#
# Usage: build-indexes.sh --brain DIR --workspace SLUG
#
# What it writes, all of it derived and none of it edited by a person:
#   - `<ws>/decisions/index.md` — every decision of the workspace, newest `date:` first.
#   - `<ws>/learnings/index.md` — every learning of the workspace, the same way.
#   - `<node>/index.md` — at the root of each area node (a product, a course, a channel, an account)
#     that an initiative, a decision or a learning of the workspace names in `about:`, with three
#     sections: Initiatives (a table: title · status · horizon), Decisions, Learnings.
# The workspace itself has no `index.md` (Gate 1, P4): its folders already show its initiatives,
# decisions and learnings.
#
# Every line is a link relative to the index. A decision or learning line is `os_doc_index_line`
# (common.sh), the one place that knows the shape. Every file opens with `generated: true` in its
# frontmatter and then the three-line warning of D8, in the language of the brain; the third line
# names where that index comes from.
#
# Rules, each in its one place here:
#   - Content unchanged, file untouched: the comparison is against the bytes on disk, so a second read
#     keeps the `mtime`, and a hand edit of a generated index is gone on the next read.
#   - An `index.md` that exists without `generated: true` was written by a person: it is skipped,
#     never overwritten (the scan names it as a finding).
#   - A generated node index whose node nobody names any more is removed: it is derived, and a stale
#     one would list what is no longer about that node.
#   - Before a path is written its entry goes to the brain's `.gitignore`: that exact path anchored at
#     the root (`/<path>`), its pattern characters escaped — never a pattern that could reach an
#     `index.md` a person wrote — and the line `gitignore-declared: <path>` is printed. If the entry
#     cannot be written, `gitignore-declare-failed: <path>` is printed and the index is not written.
#     The session contract (`core/CLAUDE.md`) says what the session does with either.
#
# Deterministic and offline: it reads frontmatter and first titles, nothing else. Exit 0 always —
# an index that cannot be written never stops the read that called it.

set -u

here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"

nl=$(printf '\nx')
nl="${nl%x}"

brain=""
ws_slug=""
while [ $# -gt 0 ]; do
  case "$1" in
    --brain) [ $# -ge 2 ] || os_die "--brain needs a value"; brain="$2"; shift 2 ;;
    --workspace) [ $# -ge 2 ] || os_die "--workspace needs a value"; ws_slug="$2"; shift 2 ;;
    *) os_die "unknown argument: $1" ;;
  esac
done
[ -n "$brain" ] || os_die "missing --brain"
[ -n "$ws_slug" ] || os_die "missing --workspace"
[ -d "$brain" ] || os_die "no such brain: $brain"
brain=$(cd "$brain" && pwd)

os_ws_check "$brain"
wsdir=$(os_ws_dir "$brain")
head=$(os_head_file "$brain") || true
os_org_existe "$brain" "$ws_slug" || exit 0
ws="$wsdir/$ws_slug"

os_lang_load "$(os_language "$brain")"

heads=$(os_tree_files "$brain" 2>/dev/null) || heads=""

# ---------------------------------------------------------------- the documents, read once
# Each decision and learning is read once into these arrays; every index is then built from them with
# string work only. Decisions and learnings come newest first (`os_docs_sorted`).
d_n=0
leer_docs() {
  # leer_docs KIND DIR — appends the documents of DIR to the arrays, tagged with KIND.
  local kind="$1" dir="$2" rel
  while IFS= read -r rel || [ -n "$rel" ]; do
    [ -n "$rel" ] || continue
    fm_read "$brain/$rel"
    d_kind[$d_n]="$kind"
    d_rel[$d_n]="$rel"
    d_about[$d_n]="$(os_about_set "$fm_about")$nl"
    d_n=$(( d_n + 1 ))
  done <<DOCS
$(os_docs_sorted "$brain" "$dir")
DOCS
}
leer_docs decision "$ws/decisions"
leer_docs learning "$ws/learnings"

# The initiatives of the workspace: the heads a `glob:` line reaches, by kind (spec 056), by path.
i_n=0
while IFS= read -r f || [ -n "$f" ]; do
  [ -n "$f" ] || continue
  case "$f" in "$ws"/initiatives/*) ;; *) continue ;; esac
  case "$(os_head_kind "$wsdir" "$head" "$f")" in
    "initiative $ws_slug") ;;
    *) continue ;;
  esac
  fm_read "$brain/$f"
  i_rel[$i_n]="$f"
  i_about[$i_n]="$(os_about_set "$fm_about")$nl"
  i_status[$i_n]="$fm_status"
  i_horizon[$i_n]="$fm_horizon"
  t=$(os_titulo "$brain/$f")
  [ -n "$t" ] || t=$(os_node_name "$f")
  i_title[$i_n]="$t"
  i_n=$(( i_n + 1 ))
done <<HEADS
$(printf '%s\n' "$heads" | LC_ALL=C sort -u)
HEADS

# ---------------------------------------------------------------- writing one index
# The `.gitignore` of the brain is read once: an unchanged index costs a string match, never a pass
# over the file. A missing entry is appended (with the newline the file may lack) and read back.
ignorados="$nl"
[ -f "$brain/.gitignore" ] && ignorados="$nl$(cat "$brain/.gitignore")$nl"

# ignorar_patron REL -> the exact `.gitignore` line for REL: anchored at the root, and with every
# character git reads as a pattern (`\ * ? [ ]`) escaped — the leading `/` keeps `!` and `#` literal — so a node folder
# named like `item[ab]` is still that one path and nothing else.
ignorar_patron() {
  local r="$1" out="" c
  while [ -n "$r" ]; do
    c="${r%"${r#?}"}"; r="${r#?}"
    case "$c" in
      '\'|'*'|'?'|'['|']') out="$out\\$c" ;;
      *) out="$out$c" ;;
    esac
  done
  printf '/%s' "$out"
}

# declarar_ignorado REL -> 0 when REL is in `.gitignore` (already, or appended now and read back); the
# marker `gitignore-declared:` only for a line written now. 1 when the line could not be written.
declarar_ignorado() {
  local linea
  linea=$(ignorar_patron "$1")
  case "$ignorados" in *"$nl$linea$nl"*) return 0 ;; esac
  if [ -s "$brain/.gitignore" ] && [ -n "$(tail -c 1 "$brain/.gitignore")" ]; then
    printf '\n' >> "$brain/.gitignore" 2>/dev/null || return 1
  fi
  printf '%s\n' "$linea" >> "$brain/.gitignore" 2>/dev/null || return 1
  grep -qxF -- "$linea" "$brain/.gitignore" 2>/dev/null || return 1
  ignorados="$ignorados$linea$nl"
  printf 'gitignore-declared: %s\n' "$1"
  return 0
}

# escribir REL CONTENT — writes the generated file at REL when its bytes differ, unless a person wrote
# that file. The ignore entry goes first: an index is never published untracked-and-visible to git. A
# `.gitignore` that cannot be written is reported (`gitignore-declare-failed: <path>`) and the index is
# not written. The content goes to a temporary file of its own (`mktemp`), so two reads at once never
# publish each other's half-written file.
escribir() {
  local rel="$1" content="$2" full="$brain/$1" tmp
  if [ -e "$full" ]; then
    fm_read "$full"
    [ "$fm_generated" = "true" ] || return 0
  fi
  if ! declarar_ignorado "$rel"; then
    printf 'gitignore-declare-failed: %s\n' "$rel"
    return 0
  fi
  if [ -e "$full" ] && [ "$(cat "$full"; printf x)" = "$content${nl}x" ]; then
    return 0
  fi
  mkdir -p "$(dirname "$full")" 2>/dev/null || return 0
  tmp=$(mktemp "$full.os-tmp.XXXXXX" 2>/dev/null) || return 0
  printf '%s\n' "$content" > "$tmp" 2>/dev/null || { rm -f "$tmp"; return 0; }
  mv -f "$tmp" "$full" 2>/dev/null || { rm -f "$tmp"; return 0; }
  return 0
}

# cabecera SOURCE_LINE — the frontmatter and the three lines of D8.
cabecera() {
  printf -- '---\ngenerated: true\n---\n\n%s\n%s\n%s\n' \
    "$S_INDEX_WARNING_TITLE" "$S_INDEX_WARNING_NOT_SAVED" "$1"
}

# md_cell TEXT -> the text safe inside a table cell or a link label: backslash, `|`, `[` and `]` escaped.
md_cell() {
  local t="$1"
  t="${t//\\/\\\\}"
  t="${t//|/\\|}"
  t="${t//[/\\[}"
  t="${t//]/\\]}"
  printf '%s' "$t"
}

# md_dest PATH -> the path as a link destination: space, parentheses, `|`, `<`, `>` and `%` encoded.
md_dest() {
  local t="$1"
  t="${t//%/%25}"
  t="${t// /%20}"
  t="${t//(/%28}"
  t="${t//)/%29}"
  t="${t//|/%7C}"
  t="${t//</%3C}"
  t="${t//>/%3E}"
  printf '%s' "$t"
}

# linea_ini I FROM — the table row of initiative I, its title linked from the folder FROM. Every cell and
# the link label are escaped and the destination encoded, so a row never splits and a link never breaks.
linea_ini() {
  local i="$1" from="$2"
  printf '| [%s](%s) | %s | %s |' "$(md_cell "${i_title[$i]}")" "$(md_dest "$(os_rel_link "$from" "${i_rel[$i]}")")" \
    "$(md_cell "${i_status[$i]}")" "$(md_cell "${i_horizon[$i]}")"
}

# ---------------------------------------------------------------- decisions/index.md, learnings/index.md
carpeta_index() {
  # carpeta_index KIND FOLDER SOURCE_LINE
  local kind="$1" folder="$2" source="$3" body="" i
  i=0
  while [ "$i" -lt "$d_n" ]; do
    if [ "${d_kind[$i]}" = "$kind" ]; then
      body="$body$(os_doc_index_line "$brain" "${d_rel[$i]}" "$folder")$nl"
    fi
    i=$(( i + 1 ))
  done
  [ -n "$body" ] || body="$S_INDEX_EMPTY$nl"
  escribir "$folder/index.md" "$(cabecera "$source")$nl$nl${body%"$nl"}"
}
carpeta_index decision "$ws/decisions" "$S_INDEX_SOURCE_DECISIONS"
carpeta_index learning "$ws/learnings" "$S_INDEX_SOURCE_LEARNINGS"

# ---------------------------------------------------------------- the index of each area node
seccion() {
  # seccion TITLE BODY — the heading, a blank line and the lines, with no trailing newline.
  if [ -n "$2" ]; then
    printf '## %s\n\n%s' "$1" "${2%"$nl"}"
  else
    printf '## %s\n\n%s' "$1" "$S_INDEX_EMPTY"
  fi
}

while IFS= read -r node || [ -n "$node" ]; do
  [ -n "$node" ] || continue
  case "$node" in "$ws"/*/*/*) ;; *) continue ;; esac
  case "$(os_head_kind "$wsdir" "$head" "$node")" in
    "entity $ws_slug") ;;
    *) continue ;;
  esac
  from="${node%/*}"
  inis=""; decs=""; lrns=""
  i=0
  while [ "$i" -lt "$i_n" ]; do
    case "${i_about[$i]}" in
      *"$nl$node$nl"*) inis="$inis$(linea_ini "$i" "$from")$nl" ;;
    esac
    i=$(( i + 1 ))
  done
  i=0
  while [ "$i" -lt "$d_n" ]; do
    case "${d_about[$i]}" in
      *"$nl$node$nl"*)
        l="$(os_doc_index_line "$brain" "${d_rel[$i]}" "$from")$nl"
        if [ "${d_kind[$i]}" = "decision" ]; then decs="$decs$l"; else lrns="$lrns$l"; fi
        ;;
    esac
    i=$(( i + 1 ))
  done
  idx="$from/index.md"
  if [ -n "$inis" ]; then
    inis="| $S_INDEX_COL_INITIATIVE | $S_INDEX_COL_STATUS | $S_INDEX_COL_HORIZON |$nl|---|---|---|$nl$inis"
  fi
  if [ -z "$decs$lrns" ] && [ -z "$inis" ]; then
    # Nobody names this node: a generated index left from before goes; one a person wrote stays.
    if [ -f "$brain/$idx" ]; then
      fm_read "$brain/$idx"
      [ "$fm_generated" = "true" ] && rm -f "$brain/$idx"
    fi
    continue
  fi
  contenido="$(cabecera "$S_INDEX_SOURCE_NODE")$nl$nl$(seccion "$S_INDEX_INITIATIVES" "$inis")$nl$nl$(seccion "$S_INDEX_DECISIONS" "$decs")$nl$nl$(seccion "$S_INDEX_LEARNINGS" "$lrns")"
  escribir "$idx" "$contenido"
done <<NODES
$(printf '%s\n' "$heads" | LC_ALL=C sort -u)
NODES

exit 0
