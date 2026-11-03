#!/usr/bin/env bash
# The AI First OS look in Obsidian (spec 089, part B). Internal: not invocable on its own — it has a
# capability row in `core/resolver.md`, and `core/skills/bootstrap.md` (at the close of the install) and
# the update of `public/README.md` drive it.
#
# Usage: obsidian-look.sh --brain DIR [--apply | --decline]
#
# The state is one word in `.system/obsidian-look`: `applied` or `declined`.
#
#   (no flags), no state   prints the question, the two options and "Reply with the number". Writes nothing.
#   (no flags), `applied`  replaces only the CSS files of the brain that carry the mark with the ones of this
#                          version. Prints `obsidian-look: refreshed` if something changed, nothing if not.
#   (no flags), `declined` prints nothing and writes nothing.
#   --apply                applies the look (rules below) and writes `applied`.
#   --decline              writes `declined`; with `applied` it changes nothing and says so.
#
# Rules of --apply, all of them inside the brain's own folder:
#   - a CSS that does not exist is copied; one that exists with the mark (the first line of the product's
#     files) is replaced; one that exists WITHOUT the mark is the person's: not touched, and named in a line
#     `not touched: <file>`;
#   - `appearance.json` and `app.json` that do not exist are copied; ones that exist are merged: only the
#     snippets that were installed are added to `enabledCssSnippets`, `accentColor` is written only if there
#     was none, and `app.json` gets only the keys it lacks. No other key changes value. Merging needs
#     Python; without it that file is not touched and a `not touched` line says so, and the rest applies;
#   - the three files Obsidian rewrites on its own go to `.gitignore`;
#   - no `.md` is touched, no plugin is installed, `community-plugins.json` is not touched.
# The CSS never needs Python, so the refresh never asks for it.
#
# Exit: 0 done (or nothing to do) · 1 invalid argument or no brain.

set -eu

here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"

brain=""
mode="auto"
while [ $# -gt 0 ]; do
  case "$1" in
    --brain) brain="$2"; shift 2 ;;
    --apply) mode="apply"; shift ;;
    --decline) mode="decline"; shift ;;
    *) os_die "unknown argument: $1" ;;
  esac
done
[ -n "$brain" ] || os_die "--brain is required"
[ -d "$brain" ] || os_die "the brain does not exist: $brain"
brain=$(cd "$brain" && pwd -P)

tpl="$here/../templates/obsidian"
mark='/* ai-first-os-look: generated, do not edit */'
state_rel="$OS_SYSTEM_DIR/obsidian-look"
state_file="$brain/$state_rel"
snippets="tables callouts tasks kanban heading-icons note-covers note-margins"
ignores="/.obsidian/workspace.json /.obsidian/workspace-mobile.json /.obsidian/graph.json"

state=""
[ ! -f "$state_file" ] || state=$(head -n 1 "$state_file" | tr -d '[:space:]')

language=$(os_language "$brain")
os_lang_load "$language"

write_state() {
  mkdir -p "$brain/$OS_SYSTEM_DIR"
  printf '%s\n' "$1" > "$state_file"
}

# is_marked FILE -> 0 when the first line of FILE is the mark.
is_marked() {
  [ -f "$1" ] && [ "$(head -n 1 "$1")" = "$mark" ]
}

# css_source NAME -> the product's file for this snippet in the brain's language: templates/obsidian/<language>/snippets/
# when it exists (the Spanish callouts), else templates/obsidian/snippets/ (English, and every other language).
css_source() {
  if [ -f "$tpl/$language/snippets/$1.css" ]; then
    printf '%s' "$tpl/$language/snippets/$1.css"
  else
    printf '%s' "$tpl/snippets/$1.css"
  fi
}

# install_file SRC DST -> copies SRC over DST through a temporary file next to it. Returns 1 when any step fails
# (and removes the temporary file), so the caller can stop instead of reporting a file that is not there.
install_file() {
  local src="$1" dst="$2" tmpf="$2.tmp.$$"
  mkdir -p "$(dirname "$dst")" 2>/dev/null && cp "$src" "$tmpf" 2>/dev/null && mv "$tmpf" "$dst" 2>/dev/null && return 0
  rm -f "$tmpf" 2>/dev/null
  printf 'error: could not write %s\n' "${dst#"$brain"/}" >&2
  return 1
}

# put_css NAME -> copies or replaces one snippet and sets `css_result` to `installed` (the brain now carries the
# product's file: copied, replaced or already equal) or `not-touched` (the file there is the person's). Not run in
# a command substitution, so a failed copy reaches the caller as a non-zero return.
css_result=""
put_css() {
  local src dst="$brain/.obsidian/snippets/$1.css"
  src=$(css_source "$1")
  if [ ! -e "$dst" ]; then
    install_file "$src" "$dst" || return 1
    css_result="installed"
  elif is_marked "$dst"; then
    if ! diff -q "$src" "$dst" > /dev/null 2>&1; then
      install_file "$src" "$dst" || return 1
    fi
    css_result="installed"
  else
    css_result="not-touched"
  fi
}

css_changed=0
if [ "$mode" = "decline" ]; then
  if [ "$state" = "applied" ]; then
    printf '%s\n' "$S_OBSIDIAN_LOOK_ALREADY_APPLIED"
    exit 0
  fi
  write_state declined
  printf 'obsidian-look: declined\n'
  exit 0
fi

if [ "$mode" = "auto" ]; then
  case "$state" in
    declined) exit 0 ;;
    applied)
      for n in $snippets; do
        src=$(css_source "$n")
        if is_marked "$brain/.obsidian/snippets/$n.css" && ! diff -q "$src" "$brain/.obsidian/snippets/$n.css" > /dev/null 2>&1; then
          install_file "$src" "$brain/.obsidian/snippets/$n.css" || exit 1
          css_changed=1
        fi
      done
      [ "$css_changed" = "0" ] || printf 'obsidian-look: refreshed\n'
      exit 0
      ;;
    *)
      printf '%s\n' "$S_OBSIDIAN_LOOK_QUESTION"
      printf '  1. %s\n' "$S_OBSIDIAN_LOOK_OPTION_APPLY"
      printf '  2. %s\n' "$S_OBSIDIAN_LOOK_OPTION_NO"
      printf '%s\n' "$S_CHOICE_REPLY_WITH_NUMBER"
      exit 0
      ;;
  esac
fi

# ---------------------------------------------------------------------------------------------- --apply
installed=""
untouched_css=0
for n in $snippets; do
  put_css "$n" || { printf 'error: the look was not applied; nothing was enabled\n' >&2; exit 1; }
  case "$css_result" in
    installed) installed="$installed $n" ;;
    *) untouched_css=1; printf 'not touched: .obsidian/snippets/%s.css\n' "$n" ;;
  esac
done

obs="$brain/.obsidian"
mkdir -p "$obs"
have_py=1
os_python_find || have_py=0

# merge_json KIND -> merges the product's file into the brain's with Python. KIND is appearance or app.
merge_json() {
  local kind="$1" list="$2"
  os_py -I - "$tpl/$kind.json" "$obs/$kind.json" "$kind" "$list" <<'PY'
import json, os, sys, tempfile
src, dst, kind, installed = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4].split()
with open(src, encoding="utf-8") as fh:
    tpl = json.load(fh)
try:
    with open(dst, encoding="utf-8") as fh:
        cur = json.load(fh)
except FileNotFoundError:
    cur = {}
if not isinstance(cur, dict):
    sys.exit(3)
new = dict(cur)
if kind == "appearance":
    if "accentColor" not in new:
        new["accentColor"] = tpl["accentColor"]
    if "translucency" not in new and not cur:
        new["translucency"] = tpl["translucency"]
    snips = new.get("enabledCssSnippets")
    if not isinstance(snips, list):
        snips = []
    for s in installed:
        if s not in snips:
            snips = snips + [s]
    new["enabledCssSnippets"] = snips
else:
    for k, v in tpl.items():
        if k not in new:
            new[k] = v
if new != cur:
    fd, tmp = tempfile.mkstemp(prefix=os.path.basename(dst) + ".", suffix=".tmp", dir=os.path.dirname(dst))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            json.dump(new, fh, indent=2, ensure_ascii=False)
            fh.write("\n")
        os.replace(tmp, dst)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise
PY
}

for kind in appearance app; do
  f="$obs/$kind.json"
  if [ ! -e "$f" ] && { [ "$kind" = "app" ] || [ "$untouched_css" = "0" ]; }; then
    cp "$tpl/$kind.json" "$f"
  elif [ "$have_py" = "1" ]; then
    merge_json "$kind" "$installed" || printf 'not touched: .obsidian/%s.json\n' "$kind"
  else
    printf 'not touched: .obsidian/%s.json\n' "$kind"
  fi
done

# The files Obsidian rewrites on its own would show up as unconfirmed changes at every start.
gi="$brain/.gitignore"
touch "$gi"
# A last line with no newline would swallow the first line we add.
if [ -s "$gi" ] && [ -n "$(tail -c 1 "$gi")" ]; then printf '\n' >> "$gi"; fi
for line in $ignores; do
  grep -qxF -- "$line" "$gi" || printf '%s\n' "$line" >> "$gi"
done

write_state applied
printf 'obsidian-look: applied\n'
exit 0
