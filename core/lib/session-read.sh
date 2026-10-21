#!/usr/bin/env bash
# Startup read of a scope: a workspace.
# Internal: not invocable — the session contract (core/CLAUDE.md) fires it, right after the startup
# scan and before the model answers the first message.
#
# Usage: session-read.sh --brain DIR --org SLUG
#        session-read.sh --brain DIR --workspace SLUG
#
# `--workspace` is an exact synonym of `--org` (spec 039), the same way `session-start.sh` reads its
# scope.
#
# `--root` no longer exists (spec 059): the root of the brain holds only machinery, and the
# operator's own work is the `personal` workspace. The flag is accepted only to stop with the same
# answer as `session-start.sh --root` (`os_root_gone`): the workspaces there are, the migration, exit
# 2, nothing printed on stdout.
#
# READING ORDER — this comment is the only place the reading order is written down, and the body
# below is what executes it. The contract names this script instead of listing files:
#
#   1. account/operator.md
#   2. <workspaces-dir>/<slug>/<head>
#   3. <workspaces-dir>/<slug>/.resolver.md
#   4. <workspaces-dir>/<slug>/context/glossary.md     (only when it exists, spec 072 and 076)
#   5. <workspaces-dir>/<slug>/context/context-map.md  (only when it exists, spec 072 and 076)
#   6. the key decisions of the scope (spec 069, revised by spec 076 C19): every decision in
#      `<workspaces-dir>/<slug>/decisions/` whose frontmatter carries `key:`, that is not replaced
#      and that names no node in `about:` — one index line each, newest first, read from each file's
#      frontmatter and never from an index. A key decision about a node loads with the focus on that
#      node (`focus-read.sh`), not here. Lines only, never the bodies they link to.
#   7. .os/core/resolver.md
#   8. <skills-dir>/*-resolver/SKILL.md — zero or more, `LC_ALL=C sort` by path, for the skills
#      folders `.agents/skills` and `.claude/skills` (spec 076, C10); a pack present in both counts
#      once
#   9. .system/resolver.md
#  10. the standing role's craft file, when the node declares `role:` and the craft is installed
#
# The operator's voice (`account/voice/voice.md`) is not part of this read (spec 076, C9): the session
# contract tells the session to read the voice of whoever signs, right before writing a text to
# publish. Loading it at startup cost every session the voice and served only the ones that write.
#
# Output format, fixed:
#   - Header per file: `── <path relative to the brain>`.
#   - Body: the bytes of the file; a file that does not end in a newline gets one, so the next
#     header always starts its own line. A 0-byte file exists: header and nothing else.
#   - The key decisions open with the fixed marker `key-decisions: <workspaces-dir>/<slug>/decisions/`
#     —English in both languages, like `about-jump:` and `active-role:`; it never starts with `── `,
#     because what follows is a cut and not a file— and one index line per decision, its link
#     relative to that folder (`os_doc_index_line`, the shape every generated index uses). A scope with
#     no key decision prints no marker and no lines.
#   - Right after them, the indexes of the scope are generated (`build-indexes.sh`, spec 076 C18):
#     `decisions/index.md`, `learnings/index.md` and the `index.md` of each area node that has
#     something to list (spec 079, C13). Nothing of them is printed — the focus of a node prints its index — except, as one
#     entry, a `gitignore-declared: <path>` line per path written for the first time or dropped because its index was retired, which the
#     session contract tells the session to commit (`.gitignore`) in the same turn, and a
#     `gitignore-declare-failed: <path>` line per index that could not be ignored and so was not written.
#   - A file that is not there prints `── missing: <path>` and no body, and never stops the read.
#   - Exactly one blank line between entries, nothing before the first.
#   - The standing role closes the output: the blank line that separates entries, the line
#     `active-role: <slug> · <path>` (the same fixed marker `session-start.sh` prints, spec 009),
#     and on the next line the craft file's header and body, with no blank line in between.
#
# Steps 4 and 5 are optional files of the workspace: when one is not there nothing is printed for
# it, not even a `── missing:` line, so a workspace without them reads byte for byte as before
# spec 072.
#
# Steps 4 and 5 are also one of the two writes of this read (spec 072, C4; the other is the indexes): when the file exists and no
# line of `tree.md` reaches it —a brain born before the spec—, the read appends
# `content: <workspaces-dir>/*/context/*.md` with `os_tree_ensure` and prints, as its own entry right
# after the file's, the fixed marker `tree-declared: content: <glob>` (English in both languages,
# like `key-decisions:`). The session that sees the marker commits `tree.md` in the same turn, as it
# does with anything else written in the brain. The scan never writes: it diagnoses, and in the
# session where the line is added it still reports the file as not reached. A workspace without
# the files, or a tree that already reaches them, is never written and reads as before. A write
# that does not land —a `tree.md` that cannot be written— never stops the read: the entry is then
# `tree-declare-failed: content: <glob> — ` followed by `SESSION_READ_TREE_DECLARE_FAILED` from
# `strings.md`, so the session tells the operator instead of the failure passing as a clean read.
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
root_pedido=0
# A flag that takes a value checks that the value is there before consuming it: with the flag as the
# last argument (`--brain . --org`), `shift 2` fails without consuming anything, `$#` stays at 1 and
# the loop repeats the same argument forever — the script has no `set -e` to stop it.
while [ $# -gt 0 ]; do
  case "$1" in
    --brain) [ $# -ge 2 ] || os_die "--brain needs a value"; brain="$2"; shift 2 ;;
    --org) [ $# -ge 2 ] || os_die "--org needs a value"; org="$2"; shift 2 ;;
    --workspace) [ $# -ge 2 ] || os_die "--workspace needs a value"; workspace="$2"; shift 2 ;;
    --root) root_pedido=1; shift ;;
    *) os_die "unknown argument: $1" ;;
  esac
done

# `--workspace` is an exact synonym of `--org` (spec 039): the two with different values is an
# error; the two with the same value, or only one of them, keep working as before.
if [ -n "$org" ] && [ -n "$workspace" ] && [ "$org" != "$workspace" ]; then
  os_die "--org and --workspace with different values: $org / $workspace"
fi
[ -n "$org" ] || org="$workspace"

[ "$root_pedido" = "0" ] || os_root_gone "$brain"

[ -n "$brain" ] || os_die "missing --brain"
[ -n "$org" ] || os_die "missing --org or --workspace"
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
# same keys the scan uses: a scope that does not exist has to read the same in both places.
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

# ---------------------------------------------------------------- the standing role
# Resolved here, with the same two functions the scan uses (`fm_read` + `os_buscar_oficio`): two
# readers of the same function cannot answer differently. The scan's output is never parsed.
role=""
rol_ruta=""
fm_read "$brain/$wsdir/$org/$head"
role="$fm_role"
if [ -n "$role" ]; then
  if ! rol_ruta=$(os_buscar_oficio "$brain" "$role"); then rol_ruta=""; fi
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

emitir "$OS_OPERATOR_FILE"
emitir "$wsdir/$org/$head"
emitir "$wsdir/$org/.resolver.md"

# emitir_si_existe RUTA — an optional entry (spec 072): printed when the file is there, silent when not.
emitir_si_existe() {
  [ -f "$brain/$1" ] || return 0
  emitir "$1"
}

# declarar RUTA GLOB — the one write of this read (spec 072, C4): a brain whose `tree.md` predates
# the spec has the file and no line that reaches it. Only when the file exists and no line of any
# class reaches it, the `content:` line is appended with `os_tree_ensure`, and the marker is printed
# only after the line is read back: a write that did not happen never reports success. It never
# creates the file.
declarar() {
  local ruta="$1" glob="$2" clase
  [ -f "$brain/$ruta" ] || return 0
  for clase in glob content archive; do
    os_tree_class_matches "$brain" "$clase" "$ruta" && return 0
  done
  os_tree_ensure "$brain" "$glob" content > /dev/null 2>&1
  if ! os_tree_class_matches "$brain" content "$ruta"; then
    separar
    printf 'tree-declare-failed: content: %s — ' "$glob"
    printf "$S_SESSION_READ_TREE_DECLARE_FAILED\n" "$ruta"
    return 0
  fi
  separar
  printf 'tree-declared: content: %s\n' "$glob"
  return 0
}
emitir_si_existe "$wsdir/$org/context/glossary.md"
declarar "$wsdir/$org/context/glossary.md" "$wsdir/*/context/*.md"
emitir_si_existe "$wsdir/$org/context/context-map.md"
declarar "$wsdir/$org/context/context-map.md" "$wsdir/*/context/*.md"

# claves — step 6: the key decisions of the scope that name no node, under a fixed marker.
claves() {
  local lineas
  lineas=$(os_key_decisions "$brain" "$wsdir/$org")
  [ -n "$lineas" ] || return 0
  separar
  printf 'key-decisions: %s/decisions/\n' "$wsdir/$org"
  printf '%s\n' "$lineas"
  return 0
}
claves

# The indexes of the scope (spec 076, C18): generated on every read, never by the scan. Only the
# `gitignore-declared:` lines reach the output, together, as one entry.
indexado=$("$here/build-indexes.sh" --brain "$brain" --workspace "$org" 2>/dev/null | grep -E '^gitignore-declare(d|-failed): ')
if [ -n "$indexado" ]; then
  separar
  printf '%s\n' "$indexado"
fi

emitir ".os/core/resolver.md"

# The pack indexes are discovered, never declared: zero of them is a legitimate installation, so
# there is nothing to report as missing.
#
# `os_skill_resolver_indexes` (common.sh) walks both skills folders with the glob of the shell, and
# never `find`: `npx skills add` leaves `.claude/skills/<pack>-resolver` as a SYMLINK to the folder
# where the CLI keeps the pack, and `find` does not walk into a linked directory without `-L`, so on
# a real brain the index simply did not print. A pack present in both folders prints once.
indices=$(os_skill_resolver_indexes "$brain")
if [ -n "$indices" ]; then
  while IFS= read -r f || [ -n "$f" ]; do
    [ -n "$f" ] || continue
    emitir "$f"
  done <<INDICES
$(printf '%s\n' "$indices" | LC_ALL=C sort)
INDICES
fi

emitir "$OS_ROOT_RESOLVER_FILE"

if [ -n "$rol_ruta" ]; then
  printf '\n'
  printf 'active-role: %s · %s\n' "$role" "$rol_ruta"
  printf '── %s\n' "$rol_ruta"
  cuerpo "$brain/$rol_ruta"
fi

exit 0
