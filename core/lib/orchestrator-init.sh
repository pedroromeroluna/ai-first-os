#!/usr/bin/env bash
# Deterministic half of the `orchestrator` skill (spec 077): turns the orchestrator on by creating its
# state file, `.system/orchestrator.md`, with the two empty sections. Internal: not invocable.
#
# Usage: orchestrator-init.sh --brain DIR [--confirm]
#
#   | `.system/orchestrator.md` | without --confirm                              | with --confirm |
#   | does not exist            | prints what it will create and the plain       | creates it,    |
#   |                           | question to ask; exit 0; writes nothing        | exit 0         |
#   | exists                    | prints that it is already on; exit 0; writes nothing — same with --confirm |
#
# It writes that one file and nothing else: no visible file, no line in `.system/tree.md`, no
# `.gitignore`. The file is written to a temporary name and moved into place, so a failed write
# never leaves a half-written file, and the file is published only if absent (create-if-absent, atomic).
#
# Exit: 0 done (or nothing to do) · 1 invalid argument · 2 the brain has no `.system/` · 9 the write
# failed and nothing was left behind.

set -u

here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"

brain=""
confirm=0
while [ $# -gt 0 ]; do
  case "$1" in
    --brain) brain="${2:-}"; shift 2 || os_die "$1 needs a value" ;;
    --confirm) confirm=1; shift ;;
    *) os_die "unknown argument: $1" ;;
  esac
done

[ -n "$brain" ] || os_die "--brain is required"
[ -d "$brain" ] || os_die "the brain does not exist: $brain"
brain=$(cd "$brain" && pwd)
[ -d "$brain/$OS_SYSTEM_DIR" ] || { printf 'error: %s has no %s/\n' "$brain" "$OS_SYSTEM_DIR" >&2; exit 2; }

OS_ORCHESTRATOR_FILE="$OS_SYSTEM_DIR/orchestrator.md"
target="$brain/$OS_ORCHESTRATOR_FILE"

language=$(os_language "$brain")
os_lang_load "$language"

if [ -e "$target" ] || [ -L "$target" ]; then
  printf 'already-active: %s\n' "$OS_ORCHESTRATOR_FILE"
  printf '%s\n' "$S_ORCHESTRATOR_ACTIVE_ALREADY"
  exit 0
fi

if [ "$confirm" = "0" ]; then
  printf 'would-create: %s\n' "$OS_ORCHESTRATOR_FILE"
  printf '%s\n' "$S_ORCHESTRATOR_ACTIVATE_QUESTION"
  exit 0
fi

# Written to a private temporary file made by mktemp (never a predictable name, never through a link),
# then published only if the target is still absent: `ln` fails when it exists, so two activations at
# once cannot overwrite each other and the winner's state stays. Only this temporary file is cleaned up.
tmpf=$(mktemp "$brain/$OS_SYSTEM_DIR/.orchestrator.XXXXXX" 2>/dev/null) || {
  printf 'error: could not write %s\n' "$OS_ORCHESTRATOR_FILE" >&2
  exit 9
}
trap 'rm -f "$tmpf"' EXIT
if ! { printf '## Sessions by topic\n\n## In progress\n' > "$tmpf"; } 2>/dev/null; then
  printf 'error: could not write %s\n' "$OS_ORCHESTRATOR_FILE" >&2
  exit 9
fi
if ln "$tmpf" "$target" 2>/dev/null; then
  printf 'created: %s\n' "$OS_ORCHESTRATOR_FILE"
  printf '%s\n' "$S_ORCHESTRATOR_CREATED"
  exit 0
fi
if [ -e "$target" ] || [ -L "$target" ]; then
  printf 'already-active: %s\n' "$OS_ORCHESTRATOR_FILE"
  printf '%s\n' "$S_ORCHESTRATOR_ACTIVE_ALREADY"
  exit 0
fi
printf 'error: could not write %s\n' "$OS_ORCHESTRATOR_FILE" >&2
exit 9
