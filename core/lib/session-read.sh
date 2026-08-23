#!/usr/bin/env bash
# Startup read of a scope: an organization, or the root (the operator's own work, spec 018).
# Internal: not invocable — the session contract (core/CLAUDE.md) fires it, right after the startup
# scan and before the model answers the first message.
#
# Usage: session-read.sh --brain DIR --org SLUG
#        session-read.sh --brain DIR --workspace SLUG
#        session-read.sh --brain DIR --root
#
# `--workspace` is an exact synonym of `--org` (spec 039). `--org`/`--workspace` and `--root` are
# exclusive, the same way `session-start.sh` reads its scope.
#
# READING ORDER — this comment is the only place the reading order is written down, and the body
# below is what executes it. The contract names this script instead of listing files:
#
#   1. operator.md
#   2. voice.md
#   3. <workspaces-dir>/<slug>/<head>       (only with --org/--workspace)
#   4. <workspaces-dir>/<slug>/resolver.md  (only with --org/--workspace)
#   5. .os/core/resolver.md
#   6. .claude/skills/*-resolver/SKILL.md — zero or more, `LC_ALL=C sort` by path
#   7. resolver.md
#   8. the standing role's craft file, when the node declares `role:` and the craft is installed
#      (only with --org)
#
# Output format, fixed:
#   - Header per file: `── <path relative to the brain>`.
#   - Body: the bytes of the file; a file that does not end in a newline gets one, so the next
#     header always starts its own line. A 0-byte file exists: header and nothing else.
#   - A file that is not there prints `── missing: <path>` and no body, and never stops the read.
#   - Exactly one blank line between entries, nothing before the first.
#   - The standing role closes the output: the blank line that separates entries, the line
#     `active-role: <slug> · <path>` (the same fixed marker `session-start.sh` prints, spec 009),
#     and on the next line the craft file's header and body, with no blank line in between.
#
# Nothing is printed between `.os/core/resolver.md` and `resolver.md` when no pack is installed,
# and nothing is printed for a `role:` whose craft is not installed: the scan already reports that
# under Checks.
#
# Exit: 0 whenever the scope exists, with or without missing files — a missing file is declared,
# never fatal. 2 if the organization does not exist (same keys and shape as the scan). 1 on invalid
# arguments, by `os_die`, one line on stderr. If `templates/strings.md` is missing, `os_lang_load`
# dies with exit 1: inherited from common.sh, same as in `session-start.sh`.
#
# No `set -e` on purpose: an unreadable file cannot abort the startup of a session.

set -u

here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"

nl=$(printf '\nx')
nl="${nl%x}"

brain=""
org=""
workspace=""
root=0
# A flag that takes a value checks that the value is there before consuming it: with the flag as the
# last argument (`--brain . --org`), `shift 2` fails without consuming anything, `$#` stays at 1 and
# the loop repeats the same argument forever — the script has no `set -e` to stop it.
while [ $# -gt 0 ]; do
  case "$1" in
    --brain) [ $# -ge 2 ] || os_die "--brain needs a value"; brain="$2"; shift 2 ;;
    --org) [ $# -ge 2 ] || os_die "--org needs a value"; org="$2"; shift 2 ;;
    --workspace) [ $# -ge 2 ] || os_die "--workspace needs a value"; workspace="$2"; shift 2 ;;
    --root) root=1; shift ;;
    *) os_die "unknown argument: $1" ;;
  esac
done

# `--workspace` is an exact synonym of `--org` (spec 039): the two with different values is an
# error; the two with the same value, or only one of them, keep working as before.
if [ -n "$org" ] && [ -n "$workspace" ] && [ "$org" != "$workspace" ]; then
  os_die "--org and --workspace with different values: $org / $workspace"
fi
[ -n "$org" ] || org="$workspace"

[ -n "$brain" ] || os_die "missing --brain"
if [ "$root" = "1" ]; then
  [ -z "$org" ] || os_die "--root and --org/--workspace are exclusive"
else
  [ -n "$org" ] || os_die "missing --org, --workspace or --root"
fi
[ -d "$brain" ] || os_die "no such brain: $brain"
brain=$(cd "$brain" && pwd)

# Invalid layout stops here, before any $(...) that builds a path with the folder name (P2, spec
# 039).
os_ws_check "$brain"
wsdir=$(os_ws_dir "$brain")
# La forma de la cabeza, leída del árbol (spec 040).
head=$(os_head_file "$brain") || true

lang=$(os_language "$brain")
os_lang_load "$lang"

# ---------------------------------------------------------------- the scope is validated by listing
# Byte for byte against the real names under the workspaces folder, never with `-d`, and with the
# same keys the scan uses: a scope that does not exist has to read the same in both places. The
# root needs no check — it always exists.
if [ "$root" = "0" ]; then
  if ! os_org_existe "$brain" "$org"; then
    printf "$S_SESSION_ORG_NOT_FOUND\n" "$org" >&2
    slugs=""
    while IFS= read -r slug || [ -n "$slug" ]; do
      [ -n "$slug" ] || continue
      slugs="$slugs  $slug$nl"
    done <<SLUGS
$(os_org_slugs "$brain")
SLUGS
    if [ -n "$slugs" ]; then
      printf '%s' "$slugs" >&2
    else
      printf '  %s\n' "$S_SESSION_NO_ORGS" >&2
    fi
    exit 2
  fi
fi

# ---------------------------------------------------------------- the standing role
# Resolved here, with the same two functions the scan uses (`fm_read` + `os_buscar_oficio`): two
# readers of the same function cannot answer differently. The scan's output is never parsed.
role=""
rol_ruta=""
if [ "$root" = "0" ]; then
  fm_read "$brain/$wsdir/$org/$head"
  role="$fm_role"
  if [ -n "$role" ]; then
    if ! rol_ruta=$(os_buscar_oficio "$brain" "$role"); then rol_ruta=""; fi
  fi
fi

# ---------------------------------------------------------------- output
primera=1

separar() {
  if [ "$primera" = "1" ]; then primera=0; else printf '\n'; fi
}

# cuerpo ARCHIVO — the bytes of the file, plus the closing newline it may not have.
cuerpo() {
  local last
  [ -s "$1" ] || return 0
  cat "$1"
  last=$(tail -c 1 "$1")
  if [ -n "$last" ]; then printf '\n'; fi
  return 0
}

# emitir RUTA — one entry: its header and its body, or its `missing:` line.
emitir() {
  separar
  if [ -f "$brain/$1" ]; then
    printf '── %s\n' "$1"
    cuerpo "$brain/$1"
  else
    printf '── '
    printf "$S_SESSION_READ_MISSING\n" "$1"
  fi
  return 0
}

emitir "operator.md"
emitir "voice.md"
if [ "$root" = "0" ]; then
  emitir "$wsdir/$org/$head"
  emitir "$wsdir/$org/resolver.md"
fi
emitir ".os/core/resolver.md"

# The pack indexes are discovered, never declared: zero of them is a legitimate installation, so
# there is nothing to report as missing.
#
# The glob of the shell, and never `find`: `npx skills add` leaves
# `.claude/skills/<pack>-resolver` as a SYMLINK to the folder where the CLI keeps the pack, and
# `find` does not walk into a linked directory without `-L`, so on a real brain the index simply
# did not print. Pathname expansion follows the link, and `[ -f ]` follows it too — the same way
# `os_pack_hint` already reads that folder in common.sh.
if [ -d "$brain/.claude/skills" ]; then
  indices=""
  for f in "$brain"/.claude/skills/*-resolver/SKILL.md; do
    [ -f "$f" ] || continue
    indices="$indices${f#$brain/}$nl"
  done
  while IFS= read -r f || [ -n "$f" ]; do
    [ -n "$f" ] || continue
    emitir "$f"
  done <<INDICES
$(printf '%s' "$indices" | LC_ALL=C sort)
INDICES
fi

emitir "resolver.md"

if [ -n "$rol_ruta" ]; then
  printf '\n'
  printf 'active-role: %s · %s\n' "$role" "$rol_ruta"
  printf '── %s\n' "$rol_ruta"
  cuerpo "$brain/$rol_ruta"
fi

exit 0
