#!/usr/bin/env bash
# migrate-layout.sh — brings an existing brain to the layout of spec 076: the account, the machinery in
# `.system/`, roles as skills, decisions and learnings with their data in the frontmatter, tasks only in
# initiatives, hidden resolvers, `resources/` and `context/`, every link rewritten once from a fixed map,
# and `tree.md` last. Internal: not invocable — the invocable is `skills/migrate-layout.md`; run at the
# operator's request only, never from install.sh, bootstrap.sh or any startup script.
#
# Usage: migrate-layout.sh --brain DIR [--apply]
#
# WITHOUT --apply it prints the whole plan and writes nothing: every move with origin and destination,
# every file whose text is rewritten, every file deleted, and every file the product does not know and
# therefore leaves where it is ("not moved"). WITH --apply it runs exactly that plan.
#
# STOPS BEFORE THE FIRST WRITE, exit 1, naming the reason: uncommitted changes in git; a destination that
# already exists with other content; two origins going to one destination; an index line that cannot be
# read (its data would be lost); an initiative the migration would create that clashes with another one.
# Scopes, each on its own: the walk covers the whole brain except `.git/`, `.os/` and `.claude/`; the
# clean-tree check covers everything git follows; inside `.claude/` it only writes `.claude/CLAUDE.md`
# (the two contract links, as operations of their own) and the `.claude/skills/<role>` links of step 4.
# It never runs install.sh: the installer also relinks agents, which the plan could not show.
#
# RESUMABLE. Before the first write the plan is saved in `.os/migrate-layout.plan`, with the content
# fingerprint of every origin and of every file it will write (the texts it writes are kept in
# `.os/migrate-layout.blobs/`). An existing plan file means the run is a resume: it accepts as its own the
# uncommitted changes and the occupied destinations that match the plan and its fingerprints, and stops at
# any other. The files are deleted when the run reaches its end. On a brain already migrated, with no plan
# file, it says there is nothing to do and exits 0.
#
# `OS_MIGRATE_LAYOUT_INTERRUPT_AFTER=KIND:N` (evals only) exits 3 right after the Nth operation of that
# kind (`move`, `put`, `delete`, `link`, `stepK` for the Kth step), the way a killed run
# would leave the brain — it is how the suite proves the resume.
#
# The engine is `migrate_layout.py` (python3 is a hard requirement of the product). Never commits.
#
# Exit: 0 ran, or nothing to do · 1 stopped · 3 interrupted by the hook.

set -u

here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"

brain=""
apply=0
while [ $# -gt 0 ]; do
  case "$1" in
    --brain) brain="${2:-}"; shift 2 ;;
    --apply) apply=1; shift ;;
    *) os_die "unknown argument: $1" ;;
  esac
done
[ -n "$brain" ] || os_die "missing --brain"
[ -d "$brain" ] || os_die "no such brain: $brain"
brain=$(cd "$brain" && pwd)
command -v python3 > /dev/null 2>&1 || os_die "python3 is required and is not on the PATH"

tree_src="$brain/$OS_TREE_FILE"
[ -f "$tree_src" ] || tree_src="$brain/tree.md"
[ -f "$tree_src" ] || os_die "no tree.md in $brain: this is not a brain"

# The brain's language and the operator's name (the owner of the initiatives it creates, as
# `os_ini_create` does): from the account file, or from the root one in a brain not migrated yet.
lang="en"
owner=""
for f in "$brain/$OS_OPERATOR_FILE" "$brain/operator.md"; do
  [ -f "$f" ] || continue
  fm_read "$f"
  if [ -n "$fm_language" ] && os_language_valido "$fm_language"; then lang="$fm_language"; fi
  owner=$(os_strip_emoji "$(os_titulo "$f")")
  break
done

# The facts of the tree, read with the product's own functions over a scratch copy of the tree that
# sits where those functions look for it (`.system/tree.md`): an old brain keeps it at the root.
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/.system"
cp "$tree_src" "$scratch/$OS_TREE_FILE"
wsdir=$(os_ws_dir "$scratch")
head_file=$(os_head_file "$scratch" || true)
ini_form=$(os_head_path "$scratch" initiative "@SLUG@" || true)
types=$(os_memory_types "$scratch" org 2> /dev/null | tr '\n' ' ' || true)

export OS_ML_BRAIN="$brain" OS_ML_APPLY="$apply" OS_ML_LANG="$lang" OS_ML_WSDIR="$wsdir"
export OS_ML_HEAD="$head_file" OS_ML_INI_FORM="$ini_form" OS_ML_TYPES="$types"
export OS_ML_CORE="$(cd "$here/.." && pwd)" OS_ML_STRINGS="$OS_STRINGS_FILE"
export OS_ML_COMMON="$here/common.sh" OS_ML_OWNER="$owner"
# The manual link, as manual-link.sh makes it: `OS_MANUAL_LINK` to the physical path of the manual of the
# brain's language.
export OS_ML_MANUAL_LINK="$OS_MANUAL_LINK"
export OS_ML_MANUAL_TARGET="$(cd "$here/../manual" && pwd -P)/$(os_manual_file "$lang")"
python3 -B "$here/migrate_layout.py"
exit $?
