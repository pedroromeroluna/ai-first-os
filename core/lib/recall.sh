#!/usr/bin/env bash
# Living Memory: search over everything the tree reaches, not only what the startup and the focus
# load (spec 050). Invocable — `core/skills/recall.md` is its contract.
#
# Usage: recall.sh --brain DIR (--workspace SLUG | --org SLUG | --root | --all) QUERY [--limit N]
#        recall.sh --brain DIR --expand PATH
#
# `--org` is an exact synonym of `--workspace` (spec 039), same rule as `session-start.sh`: the two
# with the same value, or only one, work the same; the two with different values stop with an error.
#
# WHAT THIS COMMAND INDEXES. The index is `.os/living-memory.sqlite`, inside the brain: never
# committed (`.os/` is already in every brain's `.gitignore`, `os_gitignore_ensure`), and it is
# derived and discardable — deleting it just costs the next call a full reindex. It is written with
# `python3` and the `sqlite3` module of the standard library, using an FTS5 table: no dependency the
# product does not already carry (`python3` is a hard requirement since spec 030, and the sqlite3
# that ships with the official installers of macOS, Windows and Linux carries FTS5).
#
# THE FILE LIST HAS ONE READER. `tree.md` has two classes of line since spec 007, and the only
# reader of that format is `common.sh`: `os_tree_files` (the `glob:` class — what a scan reads as a
# head) and `os_tree_content_files` (the `content:` class — reached, never read as a head). Both are
# read here, in bash, and handed to the Python side over stdin: no second parser of `tree.md`.
#
# RECONCILIATION RUNS ON EVERY CALL, BEFORE SEARCHING. There is no hook — a hook is infrastructure
# every brain would have to install, and a stale index is worse than a slower call. Size and mtime
# are the first filter: a file whose size and mtime match what is stored is skipped without reading
# it. A file whose size or mtime changed is hashed, and only a changed hash makes it reindex — so a
# `git pull` or a branch switch that touches files without changing their text (mtime moves, content
# does not) reindexes nothing, only refreshes the stored size and mtime. A stored path the tree no
# longer reaches is dropped, entries and relations included.
#
# THE UNIT OF THE INDEX IS THE ENTRY, NOT THE FILE (spec 050 C2). A file is split by heading (`#`,
# `##`, `###`): each entry is the heading plus its body, up to the next one. A file with no heading
# at all, whose body is top-level list items (`backlog.md`, `inbox.md`, any canonical list of the
# system), splits one entry per `- ` item instead. A file that is neither is a single entry. The
# frontmatter block never becomes part of an entry. The reader of that block is a second reading of
# the same format `common.sh` reads (`fm_read`, lines 289-345 there): the bound is the same
# (`CAP_FRONTMATTER`, 30 lines) and the keys are the same six this feature needs
# (`updated`, `fecha`, `date`, `status`, `about`, `superseded_by`) — whenever the two disagree on the
# shape, `common.sh` is the authority, never this script.
#
# LO REEMPLAZADO NUNCA QUEDA ARRIBA DE LO VIGENTE (C4). `status` is a column of the FTS5 table
# itself, and the query's `ORDER BY` puts it ahead of the relevance score, before the `LIMIT` is
# applied — bringing everything into Python and sorting there would not satisfy this criterion, so
# it is never done.
#
# THE SCOPE IS THE SESSION'S, AND CROSSING IT IS EXPLICIT (C5). Exactly one of `--workspace`
# (`--org`), `--root` or `--all` is required outside `--expand` mode; none of the three is an error.
#
# `--expand PATH` prints the neighbours of a file one jump away — the head its `about:` names, the
# files whose `about:` names it, the file its `superseded_by:` names, and the files whose
# `superseded_by:` names it — read from the relations table the index already keeps, never from
# disk beyond the reconciliation every call already does. One jump is one jump, same rule
# `focus-read.sh` already follows: what a neighbour itself declares is never chased.
#
# Exit: 0 the search or the expansion ran, with or without results/neighbours. 1 invalid arguments
# (missing/contradictory flags, no scope named). 2 the named workspace does not exist (same keys as
# `session-start.sh`).
#
# No `set -e`: a query with no results is not a failure.

set -u

here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"

brain=""
org=""
workspace=""
root=0
all=0
expand=""
limit=5
query_parts=""

# A flag that takes a value checks that the value is there before consuming it: with the flag as the
# last argument, `shift 2` fails without consuming anything and the loop repeats forever.
while [ $# -gt 0 ]; do
  case "$1" in
    --brain) [ $# -ge 2 ] || os_die "--brain needs a value"; brain="$2"; shift 2 ;;
    --org) [ $# -ge 2 ] || os_die "--org needs a value"; org="$2"; shift 2 ;;
    --workspace) [ $# -ge 2 ] || os_die "--workspace needs a value"; workspace="$2"; shift 2 ;;
    --root) root=1; shift ;;
    --all) all=1; shift ;;
    --expand) [ $# -ge 2 ] || os_die "--expand needs a value"; expand="$2"; shift 2 ;;
    --limit) [ $# -ge 2 ] || os_die "--limit needs a value"; limit="$2"; shift 2 ;;
    --) shift; while [ $# -gt 0 ]; do query_parts="$query_parts $1"; shift; done ;;
    -*) os_die "unknown argument: $1" ;;
    *) query_parts="$query_parts $1"; shift ;;
  esac
done

[ -n "$brain" ] || os_die "missing --brain"
[ -d "$brain" ] || os_die "no such brain: $brain"
brain=$(cd "$brain" && pwd)

# `--workspace` is an exact synonym of `--org` (spec 039): nobody outside sees the word "org" — see
# `common.sh`, the comment above `os_ws_dir`.
if [ -n "$org" ] && [ -n "$workspace" ] && [ "$org" != "$workspace" ]; then
  os_die "--org and --workspace with different values: $org / $workspace"
fi
[ -n "$workspace" ] || workspace="$org"

case "$limit" in
  ''|*[!0-9]*) os_die "--limit is not a number: $limit" ;;
esac
[ "$limit" -gt 0 ] || os_die "--limit has to be greater than 0"

lang=$(os_language "$brain")
os_lang_load "$lang"

os_ws_check "$brain"

if [ -n "$expand" ]; then
  { [ -z "$workspace" ] && [ "$root" = "0" ] && [ "$all" = "0" ]; } \
    || os_die "--expand is exclusive with --workspace/--org, --root and --all"
  [ -z "$query_parts" ] || os_die "--expand is exclusive with a search query"
  expand=$(os_rel_norm "$expand")
  os_rel_ok "$expand" || os_die "--expand is not a path relative to the brain: $expand"
  scope_kind="expand"
  scope_slug=""
else
  n_scope=0
  [ -n "$workspace" ] && n_scope=$(( n_scope + 1 ))
  [ "$root" = "1" ] && n_scope=$(( n_scope + 1 ))
  [ "$all" = "1" ] && n_scope=$(( n_scope + 1 ))
  [ "$n_scope" -gt "0" ] || os_die "name a scope — --workspace SLUG, --root or --all"
  [ "$n_scope" = "1" ] || os_die "--workspace/--org, --root and --all are exclusive"

  if [ -n "$workspace" ]; then
    org_existe=0
    org_slugs=""
    while IFS= read -r slug || [ -n "$slug" ]; do
      [ -n "$slug" ] || continue
      org_slugs="$org_slugs  $slug
"
      [ "$slug" = "$workspace" ] && org_existe=1
    done <<SLUGS
$(os_org_slugs "$brain")
SLUGS
    if [ "$org_existe" = "0" ]; then
      printf "$S_SESSION_ORG_NOT_FOUND\n" "$workspace" >&2
      if [ -n "$org_slugs" ]; then
        printf '%s' "$org_slugs" >&2
      else
        printf '  %s\n' "$S_SESSION_NO_ORGS" >&2
      fi
      exit 2
    fi
    scope_kind="workspace"
    scope_slug="$workspace"
  elif [ "$root" = "1" ]; then
    scope_kind="root"
    scope_slug=""
  else
    scope_kind="all"
    scope_slug=""
  fi

  # Leading/trailing spaces only — `os_trim` does not fold repeats in the middle, and neither does
  # this: a query is passed through, not rewritten.
  query=$(os_trim "$query_parts")
  [ -n "$query" ] || os_die "missing query — nothing to search for"
fi

wsdir=$(os_ws_dir "$brain")
head_file=$(os_head_file "$brain") || true

mkdir -p "$brain/.os" 2>/dev/null
# The index never gets committed. `.os/` is meant to be gitignored everywhere it is used
# (`.os/core` is the product's own symlink), but nothing before this spec had ever written the
# entry — this is the first thing under `.os/` a brain accumulates on disk instead of just holding a
# symlink, so the first call that would leave one is the one that makes sure the entry is there.
os_gitignore_ensure "$brain" ".os" > /dev/null 2>&1 || true
db="$brain/.os/living-memory.sqlite"

heads=$(os_tree_files "$brain") || os_die "no tree.md to read in: $brain"
contents=$(os_tree_content_files "$brain") || os_die "no tree.md to read in: $brain"
# The `archive:` class (spec 048) is indexed like content: archiving stops a document from being
# loaded, never from being found. `recall` is precisely the tool for what the focus does not load,
# so the class it was built for is the one it must not skip.
archived=$(os_tree_archive_files "$brain") || archived=""

# The subset of the `glob:` class that is a node's own identity file — the same test
# `os_org_propios`/`os_head_file` already apply elsewhere in the system: no new rule about what a
# head is, just the existing one read again.
true_heads=""
while IFS= read -r f || [ -n "$f" ]; do
  [ -n "$f" ] || continue
  case "$f" in
    */"$head_file") true_heads="$true_heads$f
" ;;
    "$head_file") true_heads="$true_heads$f
" ;;
  esac
done <<HEADS
$heads
HEADS

all_files=$(printf '%s\n%s\n' "$heads" "$contents")
if [ -n "$archived" ]; then
  all_files="$all_files
$archived"
fi
all_files=$(printf '%s\n' "$all_files" | LC_ALL=C sort -u)

if [ -n "$expand" ]; then
  mode="expand"
  arg="$expand"
else
  mode="search"
  arg="$query"
fi

stdin_data="$true_heads
%%FILES%%
$all_files"

result=$(printf '%s\n' "$stdin_data" | python3 "$here/recall_index.py" \
  "$db" "$brain" "$mode" "$scope_kind" "$wsdir" "$scope_slug" "$arg" "$limit")
rc=$?
if [ "$rc" != "0" ]; then
  printf 'error: recall.sh could not run its index (python3/sqlite3)\n' >&2
  exit 1
fi

if [ -z "$expand" ]; then
  if printf '%s\n' "$result" | grep -qx '__NO_RESULTS__'; then
    printf '%s\n' "$result" | grep -v '^__NO_RESULTS__$'
    printf '%s\n' "$S_RECALL_NO_RESULTS"
    exit 0
  fi
fi

printf '%s\n' "$result"
exit 0
