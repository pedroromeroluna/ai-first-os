#!/usr/bin/env bash
# Draws every ```mermaid block of capabilities/*.md and ARCHITECTURE.md with mmdc, for real.
# Usage: scripts/render-mermaid.sh [--required] [--root DIR]
#
# mmdc is pinned: @mermaid-js/mermaid-cli@11.16.0, run through `npx --offline` from the npm cache with
# the Chromium that puppeteer already has. It runs as a step of merge-if-green.sh and not in the suite:
# the suite runs with a restricted PATH and no browser.
#
# Two modes:
#   no flags    never uses the network. If `npx` is not in the PATH, if the pinned package is not in the
#               npm cache (`npx --offline` answers ENOTCACHED) or if Chromium is missing, it prints one
#               line that starts with `render-mermaid: SKIPPED`, saying what is missing, how many diagrams
#               were not drawn and the exact command that brings it, and exits 0. This is how the merge
#               of a born repo runs it: a machine with no browser still merges.
#   --required  the drawing is a condition. With a cold cache it fetches the pinned package once and
#               tries again offline; if it cannot, if Chromium is missing or if `npx` is missing, it
#               exits 1 saying what is missing and the command that brings it.
#
# In both modes, with the drawing tool present, a block that does not draw exits 1 naming the file and
# the block, and a repo with no block and no capability file prints `render-mermaid: nothing to draw`
# and exits 0.
#
# Exit: 0 every block drew, or the drawing was skipped out loud, or there is nothing to draw ·
# 1 a block did not draw, or something required is missing · 2 misused.
set -u

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/.." && pwd)
required=0
while [ $# -gt 0 ]; do
  case "$1" in
    --required) required=1; shift ;;
    --root) [ $# -ge 2 ] || { printf '%s\n' '--root needs a value' >&2; exit 2; }; root=$(cd "$2" 2>/dev/null && pwd) || { printf -- '--root is not an existing directory: %s\n' "$2" >&2; exit 2; }; shift 2 ;;
    *) printf 'unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done

pkg='@mermaid-js/mermaid-cli@11.16.0'
fetch_cmd="npx -y -p $pkg mmdc --version"
chromium_cmd='npx -y puppeteer browsers install chrome-headless-shell'
node_cmd="install Node.js (it brings npx), then run: $fetch_cmd"

work=$(mktemp -d) || exit 2
trap 'rm -rf "$work"' EXIT

python3 "$here/capability_tools.py" blocks "$work" --root "$root" > "$work/index.tsv" || exit 1
total=$(wc -l < "$work/index.tsv" | tr -d ' ')
if [ "$total" = "0" ]; then
  have_caps=0
  for f in "$root"/capabilities/*.md; do
    [ -f "$f" ] && [ "$(basename "$f")" != "README.md" ] && have_caps=1
  done
  if [ "$have_caps" = 0 ]; then
    printf 'render-mermaid: nothing to draw\n'
    exit 0
  fi
  printf 'render-mermaid: no mermaid block found under %s\n' "$root" >&2
  exit 1
fi

drawn=0
# Out loud and with the way out: used by the mode with no flags where the drawing is a courtesy, and by
# --required where the same fact is a stop.
cannot() { # <what is missing> <command that brings it>
  if [ "$required" = 1 ]; then
    printf 'render-mermaid: STOP %s. Bring it once, then repeat the merge:\n  %s\n' "$1" "$2" >&2
    exit 1
  fi
  printf 'render-mermaid: SKIPPED %s; %s diagram(s) not drawn. To draw them: %s\n' "$1" "$((total - drawn))" "$2"
  exit 0
}

command -v npx > /dev/null 2>&1 || cannot 'npx is not in the PATH' "$node_cmd"

fetched=0
attempt() { npx --offline -y -p "$pkg" mmdc -i "$work/$1.mmd" -o "$work/$1.svg" > "$work/$1.out" 2>&1; }
while IFS="$(printf '\t')" read -r id file block line; do
  out="$work/$id.out"
  attempt "$id"; rc=$?
  if [ "$rc" != 0 ] && grep -q 'ENOTCACHED' "$out" && [ "$required" = 1 ] && [ "$fetched" = 0 ]; then
    fetched=1
    printf 'render-mermaid: cold npm cache (ENOTCACHED); fetching %s once\n' "$pkg"
    if ! npx -y -p "$pkg" mmdc --version > "$work/fetch.out" 2>&1; then
      tail -5 "$work/fetch.out" >&2
      cannot 'the npm cache is cold and the fetch failed' "$fetch_cmd"
    fi
    attempt "$id"; rc=$?
  fi
  if [ "$rc" != 0 ] && grep -q 'ENOTCACHED' "$out"; then
    cannot "the npm cache has no $pkg" "$fetch_cmd"
  fi
  if [ "$rc" != 0 ] && grep -qiE 'could not find (chrome|chromium|browser)|browser was not found|no usable sandbox|executable doesn.t exist' "$out"; then
    cannot 'Chromium is missing for mmdc' "$chromium_cmd"
  fi
  if [ "$rc" != 0 ] || [ ! -s "$work/$id.svg" ]; then
    printf 'render-mermaid: STOP %s, mermaid block %s (opens at line %s) did not draw:\n' "$file" "$block" "$line" >&2
    grep -v '^ *at ' "$out" | head -8 >&2
    exit 1
  fi
  drawn=$((drawn + 1))
  printf 'drew %s block %s (%s)\n' "$file" "$block" "$id"
done < "$work/index.tsv"
printf 'render-mermaid: %s block(s) drew with mmdc 11.16.0\n' "$drawn"
