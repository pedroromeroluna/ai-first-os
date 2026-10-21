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
#   - `<node>/index.md` — at the root of every area node (a product, a course, a channel, an account) of
#     the workspace (spec 078, C1), whether or not anything names it. Spec 079 gives it, in this order: a
#     title and a line that say what it is (C3); the marker `<!-- os:focus-start -->`; Initiatives in
#     progress (a table: initiative linked to its `README.md` · status · horizon · tasks linked to its
#     `backlog.md` with the open count; C1, C6, C9, C11); the marker `<!-- os:focus-end -->`; Closed
#     initiatives (the same table); and then Key decisions and Other decisions (two tables), Learnings and
#     Documents, each a table (C12). A node with nothing to list (no initiative, decision or learning about it,
#     no document of its own) has no index, and a generated one it had is deleted (C13).
#     The focus read prints only what is between the two markers (C4).
# Spec 079 (C10) takes out what spec 078 wrote for an initiative: no `<initiative>/index.md` is written
# any more, and every generated one found in the workspace is deleted, with its own `.gitignore` line.
# The workspace itself has no `index.md` (Gate 1, P4): its folders already show its initiatives,
# decisions and learnings.
#
# Every link is relative to the index. A decision or learning line of `decisions/index.md` and
# `learnings/index.md` is `os_doc_index_line` (common.sh), the one place that knows that shape. Every file
# opens with `generated: true` in its frontmatter, then a `# Title` and a line that say what it is, then the
# three-line warning of D8, in the language of the brain; the third line names where that index comes from.
#
# Rules, each in its one place here:
#   - Content unchanged, file untouched: the comparison is against the bytes on disk, so a second read
#     keeps the `mtime`, and a hand edit of a generated index is gone on the next read.
#   - An `index.md` that exists without `generated: true` was written by a person: it is skipped,
#     never overwritten (the scan names it as a finding).
#   - Before a path is written its entry goes to the brain's `.gitignore`: that exact path anchored at
#     the root (`/<path>`), its pattern characters escaped — never a pattern that could reach an
#     `index.md` a person wrote — and the line `gitignore-declared: <path>` is printed. If the entry
#     cannot be written, `gitignore-declare-failed: <path>` is printed and the index is not written.
#     The session contract (`core/CLAUDE.md`) says what the session does with either.
#   - The reverse, for the initiative indexes of spec 078 (spec 079, C10): a generated
#     `<initiative>/index.md` is deleted, and only the exact `.gitignore` line that spec wrote for it is
#     dropped, with the same `gitignore-declared: <path>` line so the session commits the `.gitignore`.
#     One written by a person stays untouched and keeps its line.
#
# Deterministic and offline: it reads frontmatter and first titles, nothing else. Exit 0 always —
# an index that cannot be written never stops the read that called it.

set -u

here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"

nl=$(printf '\nx')
nl="${nl%x}"
tab=$(printf '\tx'); tab="${tab%x}"

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
  i_status[$i_n]="${fm_status//[[:cntrl:]]/ }"
  i_horizon[$i_n]="${fm_horizon//[[:cntrl:]]/ }"
  t=$(os_titulo "$brain/$f")
  [ -n "$t" ] || t=$(os_node_name "$f")
  i_title[$i_n]="${t//[[:cntrl:]]/ }"
  # The open tasks (spec 079, C6): the unindented `- [ ] ` lines of the `backlog.md` that sits beside the
  # head of an initiative with a folder of its own. Empty when there is no such backlog.
  i_bl[$i_n]=""
  i_blrel[$i_n]=""
  idir="${f%/*}"
  if [ "${f##*/}" = "$head" ] && [ "${idir%/*}" = "$ws/initiatives" ] && [ -f "$brain/$idir/backlog.md" ]; then
    i_blrel[$i_n]="$idir/backlog.md"
    i_bl[$i_n]=$(grep -c '^- \[ \] ' "$brain/$idir/backlog.md" 2>/dev/null) || true
    [ -n "${i_bl[$i_n]}" ] || i_bl[$i_n]=0
  fi
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

# retirar_indices_de_iniciativa — spec 079, C10: the initiative indexes of spec 078 are gone. Every
# `<ws>/initiatives/<slug>/index.md` with `generated: true` is deleted; one without it was written by a
# person and stays. The `.gitignore` loses the exact line that spec wrote for each index that is deleted or
# already absent (never a line for a hand-written one, and never any other line), written back with every
# other byte as it was, and `gitignore-declared: <path>` is printed for each line dropped.
retirar_indices_de_iniciativa() {
  local d rel quitar="" lineas=""
  for d in "$brain/$ws"/initiatives/*/; do
    # A folder that is a link, or resolves outside the brain, is never entered: nothing is read or deleted there.
    [ -d "$d" ] && [ ! -L "${d%/}" ] || continue
    rel="${d#"$brain"/}"
    rel="${rel%/}/index.md"
    os_inside_brain "$brain" "$rel" || continue
    if [ -e "$brain/$rel" ] || [ -L "$brain/$rel" ]; then
      [ ! -L "$brain/$rel" ] || continue
      fm_read "$brain/$rel"
      [ "$fm_generated" = "true" ] || continue
      rm -f "$brain/$rel" 2>/dev/null || continue
    fi
    quitar="$quitar$(ignorar_patron "$rel")$nl"
    lineas="$lineas$rel$nl"
  done
  soltar_ignorados "$quitar" "$lineas"
}

# retirar_indice_de_nodo REL — spec 079, C13: a node with nothing to list has no index. A generated one left from
# before is deleted, with its `.gitignore` line; one written by a person stays untouched and keeps its line. The
# line is dropped also when the file is already gone (a failed cleanup of an earlier read is retried), and a
# `.gitignore` that cannot be written is reported by `soltar_ignorados`.
retirar_indice_de_nodo() {
  local rel="$1"
  if [ -e "$brain/$rel" ] || [ -L "$brain/$rel" ]; then
    [ ! -L "$brain/$rel" ] || return 0
    fm_read "$brain/$rel"
    [ "$fm_generated" = "true" ] || return 0
    rm -f "$brain/$rel" 2>/dev/null || return 0
  fi
  soltar_ignorados "$(ignorar_patron "$rel")$nl" "$rel$nl"
}

# soltar_ignorados QUITAR LINEAS — drops from the `.gitignore` the exact lines of QUITAR (one per line), writes
# it back with every other byte as it was (each kept line keeps its own terminator, an unterminated last line
# stays unterminated only when it is kept), and prints `gitignore-declared: <path>` for each path of LINEAS whose
# line was there. A file that cannot be written prints `gitignore-declare-failed: <path>` for each of them.
soltar_ignorados() {
  local quitar="$1" lineas="$2" gi="$brain/.gitignore" orig out line tmp hubo rel ultima_ok=1 ok=1
  [ -n "$quitar" ] && [ -f "$gi" ] || return 0
  # Nothing to do when the lines read at the start are not there: the common case costs a string match.
  hubo=0
  while IFS= read -r line || [ -n "$line" ]; do
    [ -n "$line" ] || continue
    case "$ignorados" in *"$nl$line$nl"*) hubo=1; break ;; esac
  done < <(printf '%s' "$quitar")
  [ "$hubo" = "1" ] || return 0
  orig=$(cat "$gi"; printf x); orig="${orig%x}"
  out=""; hubo=0
  while IFS= read -r line || [ -n "$line" ]; do
    case "$nl$quitar" in *"$nl$line$nl"*) hubo=1; ultima_ok=0; continue ;; esac
    out="$out$line$nl"; ultima_ok=1
  done < <(printf '%s' "$orig")
  [ "$hubo" = "1" ] || return 0
  # The loop ends every line with a newline: a last line that had none keeps it that way, if it was kept.
  case "$orig" in *"$nl") ;; *) [ "$ultima_ok" = "1" ] && out="${out%"$nl"}" ;; esac
  tmp=$(mktemp "$gi.os-tmp.XXXXXX" 2>/dev/null) || ok=0
  if [ "$ok" = "1" ]; then
    printf '%s' "$out" > "$tmp" 2>/dev/null || { rm -f "$tmp"; ok=0; }
  fi
  [ "$ok" = "0" ] || os_replace_file "$tmp" "$gi" || ok=0
  while IFS= read -r rel || [ -n "$rel" ]; do
    [ -n "$rel" ] || continue
    case "$nl$orig$nl" in
      *"$nl$(ignorar_patron "$rel")$nl"*)
        if [ "$ok" = "1" ]; then printf 'gitignore-declared: %s\n' "$rel"; else printf 'gitignore-declare-failed: %s\n' "$rel"; fi ;;
    esac
  done < <(printf '%s' "$lineas")
  [ "$ok" = "0" ] || ignorados="$nl$out$nl"
  return 0
}
retirar_indices_de_iniciativa

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

# cabecera TITLE DESCRIPTION SOURCE_LINE — the frontmatter, the title that says what the file is, the line
# that says what is in it (spec 079, C3) and the three lines of D8.
cabecera() {
  printf -- '---\ngenerated: true\n---\n\n# %s\n%s\n\n%s\n%s\n%s\n' \
    "$1" "$2" "$S_INDEX_WARNING_TITLE" "$S_INDEX_WARNING_NOT_SAVED" "$3"
}

# titulo_de_cabeza REL FALLBACK -> the `# Title` of the head at REL, else FALLBACK (the name of its folder).
titulo_de_cabeza() {
  local t=""
  [ -f "$brain/$1" ] && t=$(os_titulo "$brain/$1")
  [ -n "$t" ] || t="$2"
  printf '%s' "$t"
}

# etiqueta_estado CODE / etiqueta_horizonte CODE -> the label of a `status:` / `horizon:` value in the
# language of the brain (spec 079, C11); any other value as written, escaped for a cell.
etiqueta_estado() {
  case "$1" in
    active) printf '%s' "$S_INDEX_STATUS_ACTIVE" ;;
    ongoing) printf '%s' "$S_INDEX_STATUS_ONGOING" ;;
    closed) printf '%s' "$S_INDEX_STATUS_CLOSED" ;;
    blocked) printf '%s' "$S_INDEX_STATUS_BLOCKED" ;;
    *) printf '%s' "$(md_cell "$1")" ;;
  esac
}
etiqueta_horizonte() {
  case "$1" in
    now) printf '%s' "$S_INDEX_HORIZON_NOW" ;;
    next) printf '%s' "$S_INDEX_HORIZON_NEXT" ;;
    later) printf '%s' "$S_INDEX_HORIZON_LATER" ;;
    *) printf '%s' "$(md_cell "$1")" ;;
  esac
}

# celda_tareas I FROM -> the Tasks cell of initiative I (spec 079, C1): the count of open tasks as the text of
# a link to its `backlog.md`; with no backlog, text and no link. The text and the destination are escaped
# apart, then joined.
celda_tareas() {
  local i="$1" from="$2" texto
  if [ -z "${i_blrel[$i]}" ]; then
    printf '%s' "$(md_cell "$S_INDEX_TASKS_NO_BACKLOG")"
    return 0
  fi
  case "${i_bl[$i]}" in
    0) texto="$S_INDEX_TASKS_NONE" ;;
    1) texto="$S_INDEX_TASKS_ONE" ;;
    *) texto=$(printf "$S_INDEX_TASKS_MANY" "${i_bl[$i]}") ;;
  esac
  printf '[%s](%s)' "$(md_cell "$texto")" "$(md_dest "$(os_rel_link "$from" "${i_blrel[$i]}")")"
}

# linea_ini I FROM — the table row of initiative I, its title linked from the folder FROM to its head (spec 079,
# C1). Every cell and the link label are escaped and the destination encoded (`md_cell`, `md_dest`), so a row
# never splits and a link never breaks.
linea_ini() {
  local i="$1" from="$2"
  printf '| [%s](%s) | %s | %s | %s |' "$(md_cell "${i_title[$i]}")" "$(md_dest "$(os_rel_link "$from" "${i_rel[$i]}")")" \
    "$(etiqueta_estado "${i_status[$i]}")" "$(etiqueta_horizonte "${i_horizon[$i]}")" "$(celda_tareas "$i" "$from")"
}

# ---------------------------------------------------------------- decisions/index.md, learnings/index.md
carpeta_index() {
  # carpeta_index KIND FOLDER SOURCE_LINE TITLE DESCRIPTION
  local kind="$1" folder="$2" source="$3" body="" i
  i=0
  while [ "$i" -lt "$d_n" ]; do
    if [ "${d_kind[$i]}" = "$kind" ]; then
      body="$body$(os_doc_index_line "$brain" "${d_rel[$i]}" "$folder")$nl"
    fi
    i=$(( i + 1 ))
  done
  [ -n "$body" ] || body="$S_INDEX_EMPTY$nl"
  escribir "$folder/index.md" "$(cabecera "$4" "$5" "$source")$nl$nl${body%"$nl"}"
}
ws_title=$(titulo_de_cabeza "$ws/$head" "$ws_slug")
carpeta_index decision "$ws/decisions" "$S_INDEX_SOURCE_DECISIONS" "$(printf "$S_INDEX_DECISIONS_TITLE" "$ws_title")" "$S_INDEX_DECISIONS_DESC"
carpeta_index learning "$ws/learnings" "$S_INDEX_SOURCE_LEARNINGS" "$(printf "$S_INDEX_LEARNINGS_TITLE" "$ws_title")" "$S_INDEX_LEARNINGS_DESC"

# ---------------------------------------------------------------- the documents of an index (spec 078)
seccion() {
  # seccion TITLE BODY — the heading and the body right under it, with no trailing newline; an empty body
  # says there is nothing yet (a section with nothing in it has no table).
  if [ -n "$2" ]; then
    printf '## %s\n%s' "$1" "${2%"$nl"}"
  else
    printf '## %s\n%s' "$1" "$S_INDEX_EMPTY"
  fi
}

# tabla HEADER_CELLS ROWS -> the table (header row, separator, rows), or nothing when there are no rows.
# HEADER_CELLS are the already-translated column names separated by a tab.
tabla() {
  local cols="$1" rows="$2" h="" sep="" c
  [ -n "$rows" ] || return 0
  while IFS= read -r c || [ -n "$c" ]; do
    h="$h $c |"
    sep="$sep---|"
  done <<COLS
${cols//$tab/$nl}
COLS
  printf '|%s%s|%s%s%s' "$h" "$nl" "$sep" "$nl" "${rows%"$nl"}"
}

# fecha_valida STR -> 0 when STR is a real day written `YYYY-MM-DD`. Anything else counts as no date.
fecha_valida() {
  local d="$1" y m dd max
  case "$d" in [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;; *) return 1 ;; esac
  y=$(( 10#${d:0:4} )); m=$(( 10#${d:5:2} )); dd=$(( 10#${d:8:2} ))
  [ "$y" -ge 1 ] && [ "$m" -ge 1 ] && [ "$m" -le 12 ] && [ "$dd" -ge 1 ] || return 1
  case "$m" in
    1|3|5|7|8|10|12) max=31 ;;
    4|6|9|11) max=30 ;;
    *)
      if [ $(( y % 400 )) -eq 0 ] || { [ $(( y % 4 )) -eq 0 ] && [ $(( y % 100 )) -ne 0 ]; }; then max=29; else max=28; fi
      ;;
  esac
  [ "$dd" -le "$max" ]
}

# doc_record REL BASE FROM -> one record `sort-date TAB title TAB path TAB link TAB date` for the file at REL
# (relative to the brain). The date is the `date:` key of a `.md`, else the `YYYY-MM-DD` prefix of the file
# name; a value that is not a real day is no date (the fourth field is then empty), and no date sorts last. The
# title is `os_doc_title` for a `.md`, and the path relative to BASE for any other file. The link goes from the
# folder FROM.
doc_record() {
  local rel="$1" base="$2" from="$3" name t d sd fecha
  name="${rel##*/}"
  d=""
  case "$name" in
    *.md)
      t=$(os_doc_title "$brain/$rel")
      fm_read "$brain/$rel"
      d="$fm_date"
      [ -n "$d" ] || d="${name:0:10}"
      ;;
    *)
      t="${rel#"$base"/}"
      d="${name:0:10}"
      ;;
  esac
  t="${t//[[:cntrl:]]/ }"
  sd="0000-00-00"
  fecha=""
  if fecha_valida "$d"; then sd="$d"; fecha="$d"; fi
  printf '%s\t%s\t%s\t[%s](%s)\t%s\n' "$sd" "$t" "${rel//$tab/%09}" "$(md_cell "$t")" "$(md_dest "$(os_rel_link "$from" "$rel")")" "$fecha"
}

# docs_sorted LABEL BASE FROM -> the table rows `| LABEL | date | link |` of the files whose paths come on
# stdin: the dated first, newest date first; the same date, by title and then by path; the undated last, by
# title and then by path.
docs_sorted() {
  local label="$1" base="$2" from="$3" rel
  while IFS= read -r rel || [ -n "$rel" ]; do
    [ -n "$rel" ] || continue
    doc_record "$rel" "$base" "$from"
  done | LC_ALL=C sort -t "$tab" -k1,1r -k2,2 -k3,3 | while IFS="$tab" read -r _d _t _r l f; do
    printf '| %s | %s | %s |\n' "$(md_cell "$label")" "$(md_cell "$f")" "$l"
  done
}

# limpiar TEXT -> TEXT with every control character (tab, newline...) turned into a space: a field that goes into a
# tab-separated record can never split it.
limpiar() {
  printf '%s' "${1//[[:cntrl:]]/ }"
}

# tipo_de_titulo TITLE -> the tag at the start of a title, `[producto] Algo` -> `Producto` (first ASCII letter
# raised); empty when the title has no tag or nothing after it.
tipo_de_titulo() {
  local re='^\[([^]]+)\][[:space:]]*(.+)$' tag f idx lower=abcdefghijklmnopqrstuvwxyz upper=ABCDEFGHIJKLMNOPQRSTUVWXYZ
  [[ "$1" =~ $re ]] || return 0
  tag="${BASH_REMATCH[1]}"
  f="${tag:0:1}"
  idx="${lower%%"$f"*}"
  if [ "${#idx}" -lt 26 ]; then tag="${upper:${#idx}:1}${tag:1}"; fi
  printf '%s' "$tag"
}

# titulo_sin_etiqueta TITLE -> the title without the tag `tipo_de_titulo` read.
titulo_sin_etiqueta() {
  local re='^\[([^]]+)\][[:space:]]*(.+)$'
  [[ "$1" =~ $re ]] || { printf '%s' "$1"; return 0; }
  printf '%s' "${BASH_REMATCH[2]}"
}

# fila_decision REL FROM -> a record `class TAB date TAB title TAB path TAB row` (spec 079, C12): class 0 for a
# key decision that was not replaced, 1 for the others (the node index prints them in two tables). The row is `| date | [title](link) | type | when |`.
fila_decision() {
  local rel="$1" from="$2" title date key note sup clase=1 shown tipo="" cuando="" sup_title sd
  title=$(os_doc_title "$brain/$rel")
  fm_read "$brain/$rel"
  date="$fm_date"; key="$fm_key"; note="$fm_index_note"; sup=$(os_doc_superseded_path)
  # The tag of the title becomes the Type and leaves the title, for every decision; a replaced one then says
  # «Reemplazada» instead (its tag is not shown twice).
  tipo=$(tipo_de_titulo "$title")
  shown="$title"
  [ -z "$tipo" ] || shown=$(titulo_sin_etiqueta "$title")
  if os_doc_superseded; then
    tipo="$S_INDEX_TYPE_SUPERSEDED"
    if [ -n "$sup" ]; then
      if [ -f "$brain/$sup" ]; then sup_title=$(os_doc_title "$brain/$sup"); else sup_title="${sup##*/}"; fi
      cuando="$S_INDEX_SUPERSEDED_BY_CELL [$(md_cell "$(limpiar "$sup_title")")]($(md_dest "$(os_rel_link "$from" "$sup")"))"
    fi
  else
    os_doc_is_key "$key" && clase=0
  fi
  if [ -z "$cuando" ]; then
    case "$note" in
      '❓'*|'📌'*|'🔍'*) note="" ;;
    esac
    cuando="$(md_cell "$(limpiar "$note")")"
  fi
  date=$(limpiar "$date"); shown=$(limpiar "$shown"); tipo=$(limpiar "$tipo")
  sd="${date:-0000-00-00}"
  printf '%s\t%s\t%s\t%s\t| %s | [%s](%s) | %s | %s |\n' "$clase" "$sd" "$shown" "${rel//$tab/%09}" \
    "$(md_cell "$date")" "$(md_cell "$shown")" "$(md_dest "$(os_rel_link "$from" "$rel")")" "$(md_cell "$tipo")" "$cuando"
}

# fila_aprendizaje REL FROM -> a record `date TAB title TAB path TAB row`, the row `| date | [title](link) |`.
fila_aprendizaje() {
  local rel="$1" from="$2" title date sd
  title=$(os_doc_title "$brain/$rel")
  fm_read "$brain/$rel"
  date=$(limpiar "$fm_date")
  sd="${date:-0000-00-00}"
  title=$(limpiar "$title")
  printf '%s\t%s\t%s\t| %s | [%s](%s) |\n' "$sd" "$title" "${rel//$tab/%09}" \
    "$(md_cell "$date")" "$(md_cell "$title")" "$(md_dest "$(os_rel_link "$from" "$rel")")"
}

# ultimo_campo -> the last tab-separated field of each record that comes on stdin, in the order they come.
ultimo_campo() {
  local r
  while IFS= read -r r || [ -n "$r" ]; do
    [ -n "$r" ] || continue
    printf '%s\n' "${r##*$tab}"
  done
}

# ---------------------------------------------------------------- the index of each area node
contents=$(os_tree_content_files "$brain" 2>/dev/null | LC_ALL=C sort -u) || contents=""

# filas_iniciativas -> the sorted rows of the initiatives that come on stdin as `rank TAB title TAB path TAB row`.
filas_iniciativas() {
  LC_ALL=C sort -t "$tab" -k1,1 -k2,2 -k3,3 | ultimo_campo
}

while IFS= read -r node || [ -n "$node" ]; do
  [ -n "$node" ] || continue
  case "$node" in "$ws"/*/*/*) ;; *) continue ;; esac
  case "$(os_head_kind "$wsdir" "$head" "$node")" in
    "entity $ws_slug") ;;
    *) continue ;;
  esac
  from="${node%/*}"
  inis_open=""; inis_closed=""; decs=""; lrns=""
  i=0
  while [ "$i" -lt "$i_n" ]; do
    case "${i_about[$i]}" in
      *"$nl$node$nl"*)
        t="${i_title[$i]//$tab/ }"
        pth="${i_rel[$i]//$tab/%09}"
        if [ "${i_status[$i]}" = "closed" ]; then
          inis_closed="${inis_closed}0$tab$t$tab$pth$tab$(linea_ini "$i" "$from")$nl"
        else
          case "${i_horizon[$i]}" in now) rk=0 ;; next) rk=1 ;; later) rk=2 ;; *) rk=3 ;; esac
          inis_open="$inis_open$rk$tab$t$tab$pth$tab$(linea_ini "$i" "$from")$nl"
        fi
        ;;
    esac
    i=$(( i + 1 ))
  done
  # Initiatives: the open ones by horizon (the codes, not the labels), title and path; the closed ones by title.
  cols_ini="$S_INDEX_COL_INITIATIVE$tab$S_INDEX_COL_STATUS$tab$S_INDEX_COL_HORIZON$tab$S_INDEX_COL_TASKS"
  rows="$(printf '%s' "$inis_open" | filas_iniciativas)"
  sec_open="$(seccion "$S_INDEX_INITIATIVES_OPEN" "$(tabla "$cols_ini" "$rows")")"
  rows="$(printf '%s' "$inis_closed" | filas_iniciativas)"
  sec_closed=""
  [ -z "$rows" ] || sec_closed="$nl$nl$(seccion "$S_INDEX_INITIATIVES_CLOSED" "$(tabla "$cols_ini" "$rows")")"
  # Decisions and learnings about the node.
  recs_d=""; recs_l=""
  i=0
  while [ "$i" -lt "$d_n" ]; do
    case "${d_about[$i]}" in
      *"$nl$node$nl"*)
        if [ "${d_kind[$i]}" = "decision" ]; then
          recs_d="$recs_d$(fila_decision "${d_rel[$i]}" "$from")$nl"
        else
          recs_l="$recs_l$(fila_aprendizaje "${d_rel[$i]}" "$from")$nl"
        fi
        ;;
    esac
    i=$(( i + 1 ))
  done
  # Decisions: two tables like the initiatives, the key ones that were not replaced and all the others (C12).
  cols_dec="$S_INDEX_COL_DATE$tab$S_INDEX_COL_DECISION$tab$S_INDEX_COL_TYPE$tab$S_INDEX_COL_WHEN_TO_READ"
  rows_k="$(printf '%s' "$recs_d" | LC_ALL=C sort -t "$tab" -k1,1 -k2,2r -k3,3 -k4,4 | while IFS= read -r r || [ -n "$r" ]; do
    [ "${r%%$tab*}" = "0" ] && printf '%s\n' "$r"; done | ultimo_campo)"
  rows_o="$(printf '%s' "$recs_d" | LC_ALL=C sort -t "$tab" -k1,1 -k2,2r -k3,3 -k4,4 | while IFS= read -r r || [ -n "$r" ]; do
    [ "${r%%$tab*}" = "1" ] && printf '%s\n' "$r"; done | ultimo_campo)"
  decs=""
  if [ -z "$rows_k$rows_o" ]; then
    decs="$(seccion "$S_INDEX_DECISIONS" "")"
  else
    [ -z "$rows_k" ] || decs="$(seccion "$S_INDEX_DECISIONS_KEY" "$(tabla "$cols_dec" "$rows_k")")"
    [ -z "$rows_o" ] || decs="$decs${decs:+$nl$nl}$(seccion "$S_INDEX_DECISIONS_OTHER" "$(tabla "$cols_dec" "$rows_o")")"
  fi
  lrns="$(tabla "$S_INDEX_COL_DATE$tab$S_INDEX_COL_LEARNING" \
    "$(printf '%s' "$recs_l" | LC_ALL=C sort -t "$tab" -k1,1r -k2,2 -k3,3 | ultimo_campo)")"
  # The node's own documents: what the tree reaches directly in its `context/`, `research/` and
  # `resources/`, one folder after the other, never deeper than the tree goes.
  g_context=""; g_research=""; g_resources=""
  while IFS= read -r f || [ -n "$f" ]; do
    [ -n "$f" ] || continue
    [ -f "$brain/$f" ] || continue
    case "${f##*/}" in *.os-tmp.*) continue ;; esac
    if [ "${f##*/}" = "index.md" ]; then
      fm_read "$brain/$f"
      [ "$fm_generated" = "true" ] && continue
    fi
    case "$f" in
      "$from/context/"*) g_context="$g_context$f$nl" ;;
      "$from/research/"*) g_research="$g_research$f$nl" ;;
      "$from/resources/"*) g_resources="$g_resources$f$nl" ;;
    esac
  done <<CONTENTS
$contents
CONTENTS
  docs=""
  for g in context research resources; do
    case "$g" in
      context) list="$g_context"; label="$S_INDEX_FOLDER_CONTEXT" ;;
      research) list="$g_research"; label="$S_INDEX_FOLDER_RESEARCH" ;;
      *) list="$g_resources"; label="$S_INDEX_FOLDER_RESOURCES" ;;
    esac
    [ -n "$list" ] || continue
    docs="$docs$(docs_sorted "$label" "$from" "$from" <<LIST
$list
LIST
)$nl"
  done
  docs="$(tabla "$S_INDEX_COL_FOLDER$tab$S_INDEX_COL_DATE$tab$S_INDEX_COL_DOCUMENT" "$docs")"
  # A node with nothing to list (no initiative, decision or learning about it, no document of its own) has no index.
  if [ -z "$inis_open$inis_closed$recs_d$recs_l$docs" ]; then
    retirar_indice_de_nodo "$from/index.md"
    continue
  fi
  # The title and the line that say what this index is: the type of the node comes from the folder it lives in.
  case "${node#"$ws"/}" in
    products/*) desc="$S_INDEX_NODE_DESC_PRODUCT" ;;
    courses/*) desc="$S_INDEX_NODE_DESC_COURSE" ;;
    channels/*) desc="$S_INDEX_NODE_DESC_CHANNEL" ;;
    accounts/*) desc="$S_INDEX_NODE_DESC_ACCOUNT" ;;
    *) desc="$S_INDEX_NODE_DESC_NODE" ;;
  esac
  node_title=$(titulo_de_cabeza "$node" "$(os_entity_name "$node")")
  contenido="$(cabecera "$(printf "$S_INDEX_NODE_TITLE" "$node_title")" "$desc" "$S_INDEX_SOURCE_NODE")$nl$nl$OS_FOCUS_START$nl$sec_open$nl$nl$OS_FOCUS_END$sec_closed$nl$nl$decs$nl$nl$(seccion "$S_INDEX_LEARNINGS" "$lrns")$nl$nl$(seccion "$S_INDEX_DOCUMENTS" "$docs")"
  escribir "$from/index.md" "$contenido"
done <<NODES
$(printf '%s\n' "$heads" | LC_ALL=C sort -u)
NODES

exit 0
