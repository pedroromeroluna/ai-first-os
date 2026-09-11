#!/usr/bin/env bash
# My Wiki: the brain projected as a navigable page (spec 060). Invocable — `core/skills/my-wiki.md`
# is its contract.
#
# Usage: my-wiki.sh --brain DIR [--out FILE] [--days N] [--week N]
#
# --days N   the window of Overview's threads, in days. Default 3.
# --week N   the window of Overview's dated tasks, in days. Default 7.
#
# IT WRITES OUTSIDE THE BRAIN, ALWAYS. The default destination is `$TMPDIR` (or `/tmp`), and
# `--out` may name any path outside the brain. A destination inside the brain is refused: the page
# is derived, it is regenerated in seconds, and a generated file sitting in the brain would show up
# as work in every scan and every close from then on.
#
# IT NEVER PUBLISHES. Publishing is the session's, with the Artifact tool, and a person approves
# it: this script prints the path of the file it wrote and stops there.
#
# NO FORMAT IS PARSED TWICE. The tree comes from `common.sh` (`os_tree_globs`, `os_tree_files`,
# `os_tree_content_files`), the mount table from `os_mounts_filas`, the runtime prose from
# `os_lang_load`, and git from git. All of it is handed to `my_wiki_build.py` over stdin, in
# blocks: that file reads markdown and nothing else.
#
# THE PROSE OF THE PAGE IS THE CATALOG'S. `WIKI_STRINGS` below is the one enumeration of which keys
# of `templates/strings.md` the page carries, in the brain's own language.
#
# Exit: 0 the page was written. 1 invalid arguments, or a destination inside the brain.

set -u

here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"

brain=""
out=""
days=""
week=""

while [ $# -gt 0 ]; do
  case "$1" in
    --brain) [ $# -ge 2 ] || os_die "--brain needs a value"; brain="$2"; shift 2 ;;
    --out) [ $# -ge 2 ] || os_die "--out needs a value"; out="$2"; shift 2 ;;
    --days) [ $# -ge 2 ] || os_die "--days needs a value"; days="$2"; shift 2 ;;
    --week) [ $# -ge 2 ] || os_die "--week needs a value"; week="$2"; shift 2 ;;
    *) os_die "unknown argument: $1" ;;
  esac
done

[ -n "$brain" ] || os_die "missing --brain"
[ -d "$brain" ] || os_die "no such brain: $brain"
brain=$(cd "$brain" && pwd)

command -v python3 > /dev/null 2>&1 || os_die "python3 is required and is not on the PATH"

lang=$(os_language "$brain")
os_lang_load "$lang"

# The keys of the catalog the page carries. One enumeration, here.
WIKI_STRINGS="WIKI_TITLE WIKI_PEOPLE WIKI_CHANGES WIKI_SEARCH WIKI_EDIT WIKI_EDIT_COPIED WIKI_EDIT_PATH WIKI_THREAD_RESUME WIKI_THREAD_COPIED WIKI_APPEARANCE
WIKI_ACCENT WIKI_TYPE WIKI_SIZE WIKI_THEME WIKI_LIGHT WIKI_DARK WIKI_INITIATIVES WIKI_DOCUMENTS
WIKI_DEVELOPMENT WIKI_MENTIONS WIKI_NO_ENTITY WIKI_EMPTY WIKI_ENTITIES WIKI_RESULTS
WIKI_NO_RESULTS WIKI_NO_PEOPLE WIKI_NO_MENTIONS
WIKI_REPO_UNMOUNTED WIKI_NO_SPECS WIKI_LAST_MERGE WIKI_DECISION WIKI_PERSON WIKI_NOT_FOUND
WIKI_WROTE WIKI_PUBLISH_HINT WIKI_FILES
WIKI_GRAPH WIKI_GRAPH_WORKSPACE WIKI_GRAPH_ENTITY WIKI_GRAPH_INITIATIVE WIKI_GRAPH_PERSON
WIKI_GRAPH_DOCUMENT WIKI_GRAPH_SHOW_DOCS WIKI_GRAPH_SHOW_PEOPLE WIKI_GRAPH_GREW WIKI_GRAPH_PLAY
WIKI_GRAPH_PAUSE WIKI_GRAPH_PAGES WIKI_GRAPH_LINKS WIKI_GRAPH_HINT WIKI_GRAPH_LABELS
WIKI_BACK WIKI_FORWARD
WIKI_OVERVIEW WIKI_THREADS WIKI_THREADS_WINDOW WIKI_NO_THREADS WIKI_NO_SESSIONS WIKI_NO_FOCUS
WIKI_THREAD_ASKS WIKI_THREAD_GATE1 WIKI_THREAD_UNREAD WIKI_UNREAD_WHY WIKI_GATES WIKI_NO_GATES
WIKI_GATE_1 WIKI_GATE_2 WIKI_WAITING_OTHERS WIKI_NO_WAITING WIKI_THIS_WEEK WIKI_WEEK_WINDOW
WIKI_NO_WEEK WIKI_AGO_MIN WIKI_AGO_HOUR WIKI_AGO_DAY WIKI_COUNT_THREADS WIKI_COUNT_GATES
WIKI_COUNT_WAITING"

wsdir=$(os_ws_dir "$brain")
head_file=$(os_head_file "$brain") || head_file="README.md"
vault=$(basename "$brain")
generated=$(date +%Y-%m-%d)
version=$(os_version)
[ -n "$days" ] || days=3
[ -n "$week" ] || week=7
case "$days$week" in *[!0-9]*) os_die "--days and --week take a whole number of days" ;; esac

if [ -z "$out" ]; then
  outdir="${TMPDIR:-/tmp}"
  out="${outdir%/}/my-wiki-$vault.html"
fi
case "$out" in
  "$brain"|"$brain"/*) os_die "the page is written outside the brain, never inside it: $out" ;;
esac
outdir=$(dirname "$out")
mkdir -p "$outdir" 2>/dev/null || true
[ -d "$outdir" ] || os_die "no such destination folder: $outdir"

globs=$(os_tree_globs "$brain") || os_die "no tree.md to read in: $brain"
heads=$(os_tree_files "$brain") || os_die "no tree.md to read in: $brain"
contents=$(os_tree_content_files "$brain") || os_die "no tree.md to read in: $brain"

# The mount table, one row per remote: what the `repo:` of a node resolves to on THIS machine, plus
# the date of that checkout's last merge. A remote with no row here reaches the page as a repo that
# is not mounted, and nothing fails.
mounts=""
if [ -f "$brain/$OS_MOUNTS_ARCHIVO" ]; then
  while IFS= read -r fila || [ -n "$fila" ]; do
    [ -n "$fila" ] || continue
    remote=""; ruta=""; i=0
    while IFS= read -r celda; do
      i=$(( i + 1 ))
      [ "$i" = "2" ] && remote="$celda"
      [ "$i" = "3" ] && ruta="$celda"
    done <<CELDAS
$(printf '%s' "$fila" | tr "$OS_SEP" '\n')
CELDAS
    [ -n "$remote" ] || continue
    merge=""
    if [ -n "$ruta" ] && [ -d "$ruta/.git" ]; then
      merge=$(git -C "$ruta" log -1 --merges --format=%cs 2>/dev/null || true)
    fi
    mounts="$mounts$remote	$ruta	$merge
"
  done <<FILAS
$(os_mounts_filas "$brain/$OS_MOUNTS_ARCHIVO")
FILAS
fi

# Overview's own inputs (spec 062). The sessions of Claude Code live under
# `~/.claude/projects/<the brain's path with its punctuation turned into dashes>/`; the folder is
# resolved here and read —only read— by `my_wiki_overview.py`. A machine with no such folder
# reaches the page as "no local sessions", and nothing fails.
sessions="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/$(printf '%s' "$brain" | tr -C 'A-Za-z0-9' '-' | tr -d '\n')"
[ -d "$sessions" ] || sessions=""
operator=""
[ -f "$brain/operator.md" ] && operator=$(os_titulo "$brain/operator.md")

# The gates of the mounted repos. Git is read there and only there.
gates=""
if [ -n "$mounts" ]; then
  gates=$(printf '%s' "$mounts" | "$here/my-wiki-gates.sh" 2>/dev/null || true)
fi

# Every page's first-commit date, for the Graph screen's "how it grew" (spec 061). ONE git log for
# the whole brain, full history, never one call per file: `my_wiki_graph.py` walks this once and
# keeps the earliest date it sees per path, so the order below never has to be chronological.
history=""
if [ -d "$brain/.git" ]; then
  history=$(git -C "$brain" log --name-only --no-renames --format="%x01%cs" 2>/dev/null || true)
fi
overview_block="sessions	$sessions
today	$generated
now	$(date +%Y-%m-%dT%H:%M:%S%z)
days	$days
week	$week
operator	$operator"

strings_block=""
for k in $WIKI_STRINGS; do
  eval "v=\${S_$k:-}"
  # One line per key: the page's labels are labels, never paragraphs.
  v=$(printf '%s' "$v" | tr '\n\t' '  ')
  strings_block="$strings_block$k	$v
"
done

payload="%%STRINGS%%
$strings_block
%%GLOBS%%
$globs
%%HEADS%%
$heads
%%FILES%%
$contents
%%MOUNTS%%
$mounts
%%HISTORY%%
$history
%%OVERVIEW%%
$overview_block
%%GATES%%
$gates"

result=$(printf '%s\n' "$payload" | python3 "$here/my_wiki_build.py" \
  "$brain" "$wsdir" "$head_file" "$vault" "$here/../templates/my-wiki.html" \
  "$out" "$generated" "$version")
rc=$?
if [ "$rc" != "0" ]; then
  printf 'error: my-wiki.sh could not build the page\n' >&2
  exit 1
fi

wrote=""; bytes=""; pages=""; spaces=""; i=0
while IFS= read -r celda; do
  i=$(( i + 1 ))
  [ "$i" = "1" ] && wrote="$celda"
  [ "$i" = "2" ] && bytes="$celda"
  [ "$i" = "3" ] && pages="$celda"
  [ "$i" = "4" ] && spaces="$celda"
done <<COLS
$(printf '%s' "$result" | tr '\t' '\n')
COLS

printf "$S_WIKI_WROTE\n" "$wrote" "$(( bytes / 1024 ))" "$pages" "$spaces"
printf '%s\n' "$S_WIKI_PUBLISH_HINT"
exit 0
