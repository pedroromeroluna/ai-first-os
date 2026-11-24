#!/usr/bin/env bash
# Merges a branch into `main` only if the whole suite stays green ON THE RESULT of the merge.
# If the suite goes red, or the run is interrupted, it undoes the merge and leaves `main` as it was.
#
# Usage: scripts/merge-if-green.sh <branch> [-m "message"] [--require-render] [-- <arguments for evals/run.sh>]
#
# Before `--` the branch and the flags go in any order. What comes after `--` reaches `evals/run.sh` as it
# is; with no `--` the suite runs with no arguments. `--spec` after `--` exits 2 without touching anything:
# Gate 2 runs the whole suite, never a part of it.
#
# Why it exists: the merge to `main` was the only point with no mechanical check; it depended on whoever
# merged remembering to run the suite afterwards. A hook that blocks every merge does not work, because
# the suite takes a long time and nobody waits for it on every commit. So this script reverses the
# order: it merges, it runs, and it undoes the merge if it has to.
#
# Before merging it requires the branch to declare itself finished in a file, never in a chat: with a
# spec, the `status: implementada` of the archived spec; with no spec, the trailer `Listo-para-merge: si`
# in its last commit. A branch with a clean tree and a recent commit does not say whether it is
# finished, and asking the session that wrote it dies with that session.
#
# Capabilities (capabilities/README.md): after the merge and before the suite, it applies the
# `## Capability changes` section of the declared spec (inside the merge commit, with `--amend`), runs
# the diagram checks (their shape, and the real drawing with mmdc) and, with the suite green, checks
# that every requirement under `capabilities/` has its evals on PASS. Any rejection undoes the merge
# exactly like a red suite.
#
# Exit codes: 0 merged and green · 1 rejected or red (main untouched) · 2 misused ·
# 3 merged and green, but the cleanup of the worktree or the branch failed and has to be done by hand.
set -u

# The tools sit next to this script, wherever the repo keeps them; the repo they act on is the one git
# says we are in, handed to each of them as `--root`.
here=$(cd "$(dirname "$0")" && pwd)
branch=""
render_flag=""
message=""
expect_message=0
suite_args=()
while [ $# -gt 0 ]; do
  arg="$1"; shift
  if [ "$expect_message" = 1 ]; then
    # One of this script's own flags is not a message: it would be swallowed and its meaning lost.
    case "$arg" in
      --require-render|--|-m|--message) printf '%s\n' '-m is missing its message' >&2; exit 2 ;;
    esac
    message="$arg"; expect_message=0; continue
  fi
  case "$arg" in
    --)        while [ $# -gt 0 ]; do
                 case "$1" in
                   --spec|--spec=*) printf '%s\n' 'the merge runs the whole suite: --spec is not accepted after --' >&2; exit 2 ;;
                 esac
                 suite_args+=("$1"); shift
               done ;;
    --require-render) render_flag="--required" ;;
    -m|--message) expect_message=1 ;;
    -*)        printf 'unknown flag: %s\n' "$arg" >&2; exit 2 ;;
    *)         [ -n "$branch" ] && { printf 'one branch at a time\n' >&2; exit 2; }; branch="$arg" ;;
  esac
done
[ "$expect_message" = 0 ] || { printf '%s\n' '-m is missing its message' >&2; exit 2; }
[ -n "$branch" ] || { printf 'Usage: scripts/merge-if-green.sh <branch> [-m "message"] [--require-render] [-- <arguments for evals/run.sh>]\n' >&2; exit 2; }
# `main` as the argument would pass the checks and, when cleaning up, the worktree parsing would match
# the main worktree and try to remove it.
case "$branch" in
  main|HEAD) printf 'the branch to merge cannot be %s\n' "$branch" >&2; exit 2 ;;
esac

repo=$(git rev-parse --show-toplevel 2>/dev/null) || {
  printf 'this is not a git repo\n' >&2; exit 1; }
cd "$repo" || exit 1

# --- Checks before anything is touched: nothing moves if one of them fails -------------------
[ "$(git rev-parse --abbrev-ref HEAD)" = "main" ] || {
  printf 'stand on main before merging (you are on %s)\n' "$(git rev-parse --abbrev-ref HEAD)" >&2
  exit 1; }

[ -z "$(git status --porcelain)" ] || {
  printf 'the tree has uncommitted changes: the rollback would lose them. Commit or stash them, then run again\n' >&2; exit 1; }

git rev-parse --verify --quiet "$branch" > /dev/null || {
  printf 'the branch %s does not exist\n' "$branch" >&2; exit 1; }

# The capability tools are a Python program: with no `python3` the merge would get half way and fail
# after the merge is made. It stops here instead, before anything moves.
command -v python3 > /dev/null 2>&1 || {
  printf 'python3 is not in the PATH and the capability tools need it. main was not touched. Install Python 3 and run again\n' >&2
  exit 1; }

# --- The branch has to declare itself finished, in a file --------------------------------------
# `main...$branch` (three dots) isolates what the branch brought: with two dots, a file that came in
# through `main` while the branch lived shows up as a change of the branch and the check lies.
# Only the spec THIS branch left implemented counts: if the file already had `status: implementada`
# from `main`, touching it declares nothing.
declared=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  git show "$branch:$f" 2>/dev/null | grep -q '^status: implementada' || continue
  git show "main:$f" 2>/dev/null | grep -q '^status: implementada' && continue
  declared="$f"
done <<EOF
$(git diff --name-only "main...$branch" -- 'specs/done/*.md')
EOF
if [ -z "$declared" ]; then
  # The end-of-line anchor is what keeps `Listo-para-merge: sin terminar` from passing for it.
  if git log -1 --format='%B' "$branch" | grep -qiE '^Listo-para-merge: *si *$'; then
    declared="the trailer of its last commit"
  fi
fi
[ -n "$declared" ] || {
  printf 'the branch %s does not declare itself finished. main was not touched.\n' "$branch" >&2
  printf 'with a spec: `status: implementada` in the spec archived under specs/done/.\n' >&2
  printf 'with no spec: the trailer `Listo-para-merge: si` in the last commit.\n' >&2
  printf 'asking the session that wrote it does not count: it dies with that session.\n' >&2
  exit 1; }
printf 'the branch declares itself finished in: %s\n' "$declared"

# --- Merge, run, and rollback if it goes red or if it is interrupted ---------------------------
base=$(git rev-parse HEAD)

# The run takes long: a Ctrl-C or a kill halfway used to leave `main` advanced with unverified code.
# The trap puts it back on the commit before the merge. No variable is trusted for that: a signal can
# arrive WITH the merge half done, leaving MERGE_HEAD and a touched index. The handler looks at the repo.
# `reset --hard` does not delete untracked files: the capabilities applier can leave a new one under
# capabilities/ if it is cut before the `git add` or fails halfway. Only those are removed, with the
# path in front; never a bare `git clean` (see the comment at the end). No `-x`: ignored files are never touched.
go_back_to_base() {
  git merge --abort > /dev/null 2>&1
  git reset --hard "$base" > /dev/null 2>&1
  git clean -fdq -- capabilities > /dev/null 2>&1
  if [ -n "$(git status --porcelain)" ]; then
    printf 'WARNING: the tree is not clean after undoing the merge:\n' >&2
    git status --porcelain >&2
  fi
}
on_interrupt() {
  trap - INT TERM
  git merge --abort > /dev/null 2>&1
  if [ "$(git rev-parse HEAD)" != "$base" ]; then
    go_back_to_base
    printf '\ninterrupted: merge undone, main is back on %s\n' "$(git rev-parse --short HEAD)" >&2
  else
    git clean -fdq -- capabilities > /dev/null 2>&1
    printf '\ninterrupted: main stayed on %s, untouched\n' "$(git rev-parse --short HEAD)" >&2
  fi
  exit 130
}
trap on_interrupt INT TERM

printf 'main before the merge: %s\n' "$(git rev-parse --short HEAD)"
# With no `-m`, the message comes from the subject of the branch's last commit: a bare `Merge <branch>`
# does not say what came in, and the merge history is the first thing the next person reads.
[ -n "$message" ] || message="Merge $branch: $(git log -1 --format='%s' "$branch")"
if ! git merge --no-ff "$branch" -m "$message"; then
  git merge --abort 2> /dev/null
  printf 'the merge hit a conflict: nothing was left half done, main is on %s. Resolve it by hand\n' "$(git rev-parse --short HEAD)" >&2
  exit 1
fi

# --- Capabilities ------------------------------------------------------------------------------
# Every rejection in this block undoes the merge like a red suite: `main` goes back to `base`.
undo() {
  go_back_to_base
  trap - INT TERM
  printf 'merge undone: main is back on %s. The branch %s is untouched.\n' "$(git rev-parse --short HEAD)" "$branch" >&2
  exit 1
}
# 1. If the declared spec carries `## Capability changes`, it is applied onto `main` right now and the
#    changes enter the same merge commit (`--amend`): a single commit is left. The applier is the one
#    of the merge result; if the branch does not carry it yet, there is nothing to apply.
if [ -f "$declared" ] && grep -q '^## Capability changes' "$declared" && [ -f "$here/apply-capability-changes.sh" ]; then
  if ! applied=$(bash "$here/apply-capability-changes.sh" "$declared" --root "$repo" 2>&1); then
    printf 'RED. The capabilities applier stopped:\n%s\n' "$applied" >&2
    undo
  fi
  [ -z "$applied" ] || printf '%s\n' "$applied"
  if [ -n "$(git status --porcelain -- capabilities)" ]; then
    before_amend=$(git rev-parse HEAD)
    git add capabilities || { printf 'git add capabilities failed\n' >&2; undo; }
    git commit -q --amend --no-edit || { printf 'could not add capabilities/ to the merge commit\n' >&2; undo; }
    # With the amend done: the tree is clean and the commit really carries the capabilities/ changes.
    if [ -n "$(git status --porcelain)" ] || git diff --quiet "$before_amend" HEAD -- capabilities; then
      printf 'the merge commit did not keep the capabilities/ changes, or the tree is dirty\n' >&2
      undo
    fi
    printf 'capabilities/ updated inside the merge commit\n'
  fi
fi
# 2. The two diagram checks run on every merge, whether the spec carries the section or not: a by-hand
#    change to capabilities/ or to ARCHITECTURE.md also has to pass. The drawing runs with no flags, which
#    skips out loud when `npx` or Chromium is missing; with `--require-render` it is a condition.
for check in check-capability-diagrams.sh render-mermaid.sh; do
  [ -f "$here/$check" ] || continue
  flag=""
  [ "$check" = "render-mermaid.sh" ] && flag="$render_flag"
  if ! cap_out=$(bash "$here/$check" $flag --root "$repo" 2>&1); then
    printf 'RED. %s stopped:\n%s\n' "$check" "$cap_out" >&2
    undo
  fi
  printf '%s\n' "$cap_out" | grep '^render-mermaid: SKIPPED'
done

printf 'merged. running the suite over the result (this takes a while)\n'
# `mktemp` with no template: `mktemp -t <prefix>` works on BSD and fails on GNU, which requires the
# XXXXXX suffix. The minimal PATH the product guarantees is bash, coreutils, git and python3: the BSD
# tools are not part of it.
output=$(mktemp) || { printf 'could not create the output file\n' >&2; go_back_to_base; exit 1; }

# Three conditions, not one. `grep -v FAIL` alone would say "green" if the suite dies before running
# its first check: with no FAIL lines, the absence looks like success. The summary and the exit code
# are what tell "ran and passed everything" from "did not get to run".
bash evals/run.sh ${suite_args[@]+"${suite_args[@]}"} > "$output" 2>&1
code=$?
summary=$(tail -1 "$output")
# The summary line of a born repo ends in `· 0 fail`, or in `· 0 fallan` when its brain is in Spanish.
summary_green=0
printf '%s' "$summary" | grep -qE '· 0 (fail|fallan)$' && summary_green=1
# Green is three conditions together: exit 0, no FAIL line, a summary with no failures.
suite_green=0
[ "$code" = 0 ] && ! grep -qaE '^FAIL' "$output" && [ "$summary_green" = 1 ] && suite_green=1
# 4. With the suite green, every requirement under capabilities/ has to have its evals on PASS in that output.
# The decision goes by the exit code of the check, not by the text it printed.
cap_fail=""
cap_code=0
if [ "$suite_green" = 1 ] && [ -f "$here/check-capability-evals.sh" ]; then
  cap_fail=$(bash "$here/check-capability-evals.sh" "$output" --root "$repo" 2>&1)
  cap_code=$?
  [ "$cap_code" = 0 ] || cap_fail="${cap_fail:-check-capability-evals.sh exited with code $cap_code and said nothing}"
fi
if [ "$suite_green" = 1 ] && [ "$cap_code" = 0 ]; then
  trap - INT TERM
  printf '%s\n' "$(tail -1 "$output")"
  printf 'green: the merge stays.\n'

  # Gate 2 cleanup: whoever merges removes the worktree and the branch. If any of it fails it is said
  # and the exit code is 3: the merge is done and verified, the cleanup is not.
  wt=""
  current=""
  while IFS= read -r line; do
    case "$line" in
      "worktree "*) current="${line#worktree }" ;;
      "branch refs/heads/"*)
        [ "${line#branch refs/heads/}" = "$branch" ] && wt="$current" ;;
    esac
  done <<EOF
$(git worktree list --porcelain)
EOF
  pending=0
  if [ -n "$wt" ]; then
    if git worktree remove --force "$wt"; then
      printf 'worktree removed: %s\n' "$wt"
    else
      printf 'could NOT remove the worktree %s — remove it by hand\n' "$wt" >&2; pending=1
    fi
  fi
  if [ "$pending" = 0 ]; then
    if git branch -d "$branch" > /dev/null 2>&1; then
      printf 'branch deleted\n'
    else
      printf 'could NOT delete the branch %s — delete it by hand\n' "$branch" >&2; pending=1
    fi
  fi
  rm -f "$output"
  [ "$pending" = 0 ] || exit 3
  exit 0
fi

# The rollback first, and only then the trap is disarmed and the report is printed: a Ctrl-C while the
# failures are listed cannot leave the merge in place.
go_back_to_base
trap - INT TERM
printf 'RED. What failed:\n'
grep -aE '^FAIL' "$output" | while IFS= read -r l; do printf '  %s\n' "$l"; done
# The suite exited 0 and printed no FAIL line, but did not end with a summary of no failures: say why it is red.
if [ "$code" = 0 ] && [ "$summary_green" = 0 ] && ! grep -qaE '^FAIL' "$output"; then
  printf '  the suite exited 0 with no FAIL line, but its last line does not end in `· 0 fail` or `· 0 fallan`, so the merge cannot tell the suite ran to its end. Last line: %s\n' "$summary"
fi
[ "$cap_code" = 0 ] || printf 'RED. Requirements under capabilities/ with no green eval:\n%s\n' "$cap_fail"
printf '%s\n' "$summary"
[ "$code" = 0 ] || printf 'the suite exited with code %s\n' "$code"
printf 'merge undone: main is back on %s. The branch %s is untouched.\n' "$(git rev-parse --short HEAD)" "$branch"
# `git clean` is not run on purpose: it would delete the operator's files that were never the suite's.
# If something untracked is left, it is said and a person removes it.
[ -z "$(git status --porcelain)" ] || {
  printf 'WARNING: untracked changes are left in the tree — look at them before running again:\n'
  git status --porcelain; }
printf 'the full output was left in %s\n' "$output"
exit 1
