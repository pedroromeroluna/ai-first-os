#!/usr/bin/env bash
# The gates of the mounted repos, for My Wiki's Overview (spec 062, C4). Internal: it is called by
# `my-wiki.sh` and has no `command:` header of its own.
#
# Usage: my-wiki-gates.sh   — the mount rows arrive on stdin, one per line:
#          remote<TAB>local path<TAB>last merge date
#
# Prints one row per gate, tab separated:
#          gate<TAB>repo<TAB>spec file<TAB>title<TAB>date<TAB>branch
#
#   gate     `1` a spec of `specs/` that declares it is waiting for its Gate 1
#            `2` a branch that declares `status: implementada` in `specs/done/` and is not merged
#   date     the day the row can be aged from: the spec file's own last change for a Gate 1, the
#            branch's last commit for a Gate 2.
#
# GIT IS READ HERE AND NOWHERE ELSE. `my_wiki_overview.py` never shells out: the branch state of a
# repo is git's answer, and it arrives already resolved, the same way the tree and the mount table
# do. A repo this machine did not mount produces no rows and no error.

set -u

here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"

# A spec's `status:` that means "a person has to approve it before anything is implemented". The
# list is here, once: `pendiente`/`pending` is what the product writes today, and `esperando gate 1`
# is what a spec writes when it says so in full.
GATE1_STATES="pendiente pending esperando-gate-1 waiting-gate-1"
# What a branch declares when it says its work is finished and is asking to be merged.
GATE2_STATE="implementada"

norm() { printf '%s' "$1" | tr 'A-Z' 'a-z' | tr ' _' '--'; }

is_gate1() {
  local want; want=$(norm "$1")
  local s
  for s in $GATE1_STATES; do [ "$want" = "$s" ] && return 0; done
  return 1
}

# The last two segments of a remote — `owner/repo` — which is how a person names it.
short_repo() {
  local r="${1%/}" last rest
  case "$r" in *.git) r="${r%.git}" ;; esac
  last="${r##*/}"
  rest="${r%/*}"
  if [ "$rest" = "$r" ]; then printf '%s' "$last"; else printf '%s/%s' "${rest##*/}" "$last"; fi
}

# The `status:` of a file's frontmatter, read off a stream. `fm_read` takes a path and this reads
# what `git show` prints, which never touches the working tree.
fm_status_of_stream() {
  local line n=0
  while IFS= read -r line; do
    n=$(( n + 1 ))
    if [ "$n" = "1" ]; then [ "$line" = "---" ] || return 0; continue; fi
    [ "$line" = "---" ] && return 0
    [ "$n" -ge 60 ] && return 0
    case "$line" in
      status:*) printf '%s' "$(os_trim "${line#status:}")"; return 0 ;;
      estado:*) printf '%s' "$(os_trim "${line#estado:}")"; return 0 ;;
    esac
  done
  return 0
}

# The `# ` heading of a file, read off the same stream.
title_of_stream() {
  local line
  while IFS= read -r line; do
    case "$line" in '# '*) printf '%s' "${line#\# }"; return 0 ;; esac
  done
  return 0
}

while IFS= read -r row || [ -n "$row" ]; do
  [ -n "$row" ] || continue
  remote=""; path=""; i=0
  while IFS= read -r cell; do
    i=$(( i + 1 ))
    [ "$i" = "1" ] && remote="$cell"
    [ "$i" = "2" ] && path="$cell"
  done <<CELLS
$(printf '%s' "$row" | tr '\t' '\n')
CELLS
  [ -n "$path" ] || continue
  [ -d "$path/.git" ] || continue
  short=$(short_repo "$remote")

  # --- Gate 1: a spec of the working tree that is waiting for a person to approve it.
  if [ -d "$path/specs" ]; then
    for file in "$path"/specs/*.md; do
      [ -f "$file" ] || continue
      fm_read "$file"
      is_gate1 "${fm_status:-}" || continue
      title=$(os_titulo "$file")
      [ -n "$title" ] || title=$(basename "$file" .md)
      when=$(git -C "$path" log -1 --format=%cs -- "specs/$(basename "$file")" 2>/dev/null || true)
      [ -n "$when" ] || when=""
      printf '1\t%s\t%s\t%s\t%s\t\n' "$short" "specs/$(basename "$file")" "$title" "$when"
    done
  fi

  # --- Gate 2: a branch that declares itself finished and is not in the default branch yet.
  #
  # THE BRANCH IS READ FROM GIT, NEVER FROM THE WORKING TREE. What the checkout has on disk is one
  # branch; a branch that finished and is waiting to be merged is usually not that one, and its
  # `specs/done/` only exists inside the branch.
  base=$(git -C "$path" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)
  base="${base#origin/}"
  if [ -z "$base" ]; then
    for cand in main master; do
      git -C "$path" rev-parse --verify --quiet "refs/heads/$cand" > /dev/null 2>&1 && { base="$cand"; break; }
    done
  fi
  [ -n "$base" ] || continue
  branches=$(git -C "$path" for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null || true)
  for branch in $branches; do
    [ "$branch" = "$base" ] && continue
    git -C "$path" merge-base --is-ancestor "$branch" "$base" > /dev/null 2>&1 && continue
    # WHAT THE BRANCH ADDED, not what the branch holds: `specs/done/` drags along everything
    # already merged, and every branch would claim the finished work of all the ones before it.
    done_files=$(git -C "$path" diff --name-only --diff-filter=AM "$base...$branch" -- specs/done/ 2>/dev/null || true)
    [ -n "$done_files" ] || continue
    when=$(git -C "$path" log -1 --format=%cs "$branch" 2>/dev/null || true)
    for done_file in $done_files; do
      case "$done_file" in *.md) ;; *) continue ;; esac
      state=$(git -C "$path" show "$branch:$done_file" 2>/dev/null | fm_status_of_stream)
      [ "$(norm "${state:-}")" = "$GATE2_STATE" ] || continue
      title=$(git -C "$path" show "$branch:$done_file" 2>/dev/null | title_of_stream)
      [ -n "$title" ] || title=$(basename "$done_file" .md)
      printf '2\t%s\t%s\t%s\t%s\t%s\n' "$short" "$done_file" "$title" "$when" "$branch"
    done
  done
done

exit 0
