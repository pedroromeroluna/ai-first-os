#!/usr/bin/env bash
# migrate-root.sh — moves the operator's own work, written before spec 059 directly at the brain's
# root, into the `personal` folder under this brain's own workspaces folder (`os_ws_dir`, spec 039 —
# `workspaces/` on a brain born today, the older name on one that has not renamed it yet), the
# workspace every brain is born with today. Internal: not invocable, run at the operator's request
# only — never from install.sh, bootstrap.sh or any startup script.
#
# Usage: migrate-root.sh --brain DIR [--mounts-reviewed]
#
# Same discipline as rename-workspaces.sh (spec 039's precedent, cited by spec 059): on request only,
# resumable, moves only structure and rewrites only routing, lists the rest, never commits.
#
# WHAT MOVES — one item at a time, each a single rename, when present at the brain's root:
#   - initiatives/<entry>  → <wsdir>/personal/initiatives/<entry>: a folder (with its own
#     `backlog.md`, spec 057, and its `archive/`) or a loose file of the old head shape (spec 040)
#   - <type>/<entry>, for every memory-node type the root declares in tree.md (spec 041)
#   - backlog.md → <wsdir>/personal/backlog.md, where the startup declares it as a backlog outside an
#     initiative (spec 057); `migrate-backlogs.sh` splits it, and the verdict names that command
#   - decisions.md, decisions/, learnings.md, learnings/ → the same names under personal: a body's
#     link inside its index is relative to the node, so moving index and folder keeps every link
#   - inbox.md never moves: when it holds nothing but whitespace it is deleted; otherwise every
#     non-blank line is listed for the operator to route by hand and the file stays (decision 4)
# What never moves: operator.md, voice.md, voice/, mounts.md, resolver.md, tree.md, roles/.
#
# STOPS before moving anything, exit 1, naming the reason:
#   - `<wsdir>/personal` already exists and this migration did not create it (spec 059's stop
#     condition: merging two workspaces is not this command's job);
#   - the destination of an item already exists;
#   - a mounted repo (each local path in a row of mounts.md's table that exists) references the root
#     path of an initiative or a memory node about to move (spec 059's stop condition: a mounted repo
#     is code, never migrated from the brain). The stop names every hit, file and line; once the
#     operator has read them and decided they can stay — a repo's own history, a fixture that only
#     shares the name — `--mounts-reviewed` runs the migration and lists them again as findings. A
#     repo is never written. Generic names —`backlog.md`, `decisions.md`, `decisions/`…— are not
#     looked for there: a repo has its own, and they cannot be told apart.
# And stops midway, exit 1, when a move does not leave its source gone and its destination present.
#
# RESUMABLE BY INSPECTION. Before its first write the run records its state —that it created
# personal, the root's memory types, and every move it is about to make— in `.os/migrate-root.state`
# (the installation's own folder, never versioned). A later run reads it back: a run cut after any
# move still knows that personal is its own, which paths moved where, and which rewrites are
# pending. The file is deleted when a run reaches its end. With no root item, no pending state and
# no inbox there is nothing to do: it says so and changes nothing.
#
# REWRITES, from the moves actually made (the map in the state file, never a fixed prefix list):
#   - tree.md: every root-height line (glob/content/archive) whose pattern starts with a moved root
#     name becomes the same line under `<wsdir>/*/` (declared with os_tree_ensure, then read back),
#     and the root line goes; `glob: inbox.md` goes once inbox.md is gone.
#   - the `about:` line of every head under personal whose value names a moved path.
#   - routing: the root's resolver.md, mounts.md, and every resolver.md and backlog.md under
#     personal. Never another workspace's files: a bare `initiatives/x` there is relative to that
#     workspace, not to the root. A moved path is rewritten only right after a start-of-line, space,
#     tab, backtick, pipe, paren, quote, `[` or `<`, and only when what follows ends the path — never
#     after a slash, colon, dot, dash, underscore, letter or digit: that is a URL or someone else's.
# Everything else that still names a moved path is listed with its count, for the operator. Outside
# the root's own files only the distinctive paths (an initiative's or a memory node's) are counted.
#
# Exit: 0 nothing to migrate, or migrated (findings notwithstanding) · 1 stopped, with the reason.
#
# `OS_MIGRATE_ROOT_INTERRUPT_AFTER=N` (evals only) exits 3 right after the Nth move, the way a
# killed run would leave the brain — it is how the suite proves the resume.
#
# No `set -e` on purpose: every step checks its own result and says which one failed.

set -u

here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"

brain=""
mounts_reviewed=0
while [ $# -gt 0 ]; do
  case "$1" in
    --brain) brain="${2:-}"; shift 2 ;;
    --mounts-reviewed) mounts_reviewed=1; shift ;;
    *) os_die "unknown argument: $1" ;;
  esac
done

[ -n "$brain" ] || os_die "missing --brain"
[ -d "$brain" ] || os_die "no such brain: $brain"
brain=$(cd "$brain" && pwd)

os_ws_check "$brain"
wsdir=$(os_ws_dir "$brain")
slug="$OS_PERSONAL_WORKSPACE_SLUG"
dest="$wsdir/$slug"

lang=$(os_language "$brain")
os_lang_load "$lang"

tab=$(printf '\t')
nl=$(printf '\nx'); nl="${nl%x}"
state="$brain/.os/migrate-root.state"
interrupt_after="${OS_MIGRATE_ROOT_INTERRUPT_AFTER:-0}"

stop() {
  printf 'stopped:\n'
  printf '  %s\n' "$@"
  exit 1
}

# ---------------------------------------------------------------- the state of a previous run
state_created=0
state_types=""
if [ -f "$state" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      "created$tab"*) state_created=1 ;;
      "type$tab"*) state_types="$state_types ${line#type$tab}" ;;
    esac
  done < "$state"
fi

# ---------------------------------------------------------------- what there is to move
tipos_root=$(os_memory_types "$brain" root) || tipos_root=""
tipos=""
for t in $tipos_root $state_types; do
  case " $tipos " in *" $t "*) ;; *) tipos="$tipos $t" ;; esac
done

items=""
if [ -d "$brain/initiatives" ]; then
  for e in "$brain/initiatives/"*; do
    [ -e "$e" ] && items="${items}initiatives/$(basename "$e")$nl"
  done
fi
for t in $tipos; do
  [ -d "$brain/$t" ] || continue
  for e in "$brain/$t/"*; do
    [ -e "$e" ] && items="$items$t/$(basename "$e")$nl"
  done
done
for f in backlog.md decisions.md decisions learnings.md learnings; do
  [ -e "$brain/$f" ] && items="$items$f$nl"
done

hay_inbox=0; [ -f "$brain/inbox.md" ] && hay_inbox=1

if [ -z "$items" ] && [ ! -f "$state" ] && [ "$hay_inbox" = "0" ]; then
  printf 'nothing at the root to migrate\n'
  exit 0
fi

# ---------------------------------------------------------------- stops, before moving anything
mount_hits=""
if [ -n "$items" ]; then
  if [ -e "$brain/$dest" ] && [ "$state_created" = "0" ]; then
    stop "$dest already exists and this migration did not create it — merging two workspaces is not this command's job; nothing moved" \
         "rename or move it by hand, with the operator, and run again"
  fi

  conflictos=""
  while IFS= read -r it || [ -n "$it" ]; do
    [ -n "$it" ] || continue
    # An empty folder the workspace was born with (spec 076, C13: `decisions/`, `learnings/`) is free.
    if [ -d "$brain/$dest/$it" ] && [ -z "$(ls -A "$brain/$dest/$it" 2>/dev/null)" ]; then continue; fi
    [ -e "$brain/$dest/$it" ] && conflictos="$conflictos$dest/$it already exists — nothing moved$nl"
  done <<ITEMS
$items
ITEMS
  if [ -n "$conflictos" ]; then
    printf 'stopped:\n'
    printf '%s' "$conflictos" | while IFS= read -r c; do printf '  %s\n' "$c"; done
    exit 1
  fi

  if [ -f "$brain/$OS_MOUNTS_ARCHIVO" ]; then
    pat=""
    while IFS= read -r it || [ -n "$it" ]; do
      case "$it" in */*) ;; *) continue ;; esac
      esc="${it//./\\.}"
      if [ -z "$pat" ]; then pat="$esc"; else pat="$pat|$esc"; fi
    done <<ITEMS
$items
ITEMS
    if [ -n "$pat" ]; then
      re="(^|[[:space:]\`|(\"'[<])($pat)([/[:space:]\`|)\"'>,;:]|\$)"
      hits=""
      while IFS= read -r ruta || [ -n "$ruta" ]; do
        [ -n "$ruta" ] && [ -d "$ruta" ] || continue
        case "$ruta/" in "$brain/"*) continue ;; esac
        if git -C "$ruta" rev-parse --is-inside-work-tree > /dev/null 2>&1; then
          h=$(git -C "$ruta" grep -n -I -E "$re" 2>/dev/null | head -5)
        else
          h=$(grep -r -n -I -E "$re" "$ruta" 2>/dev/null | head -5)
        fi
        [ -n "$h" ] && hits="$hits$ruta$nl$h$nl"
      done <<MOUNTS
$(grep -E '^[[:space:]]*\|' "$brain/$OS_MOUNTS_ARCHIVO" 2>/dev/null | grep -oE '`/[^`]+`' | tr -d '`')
MOUNTS
      if [ -n "$hits" ] && [ "$mounts_reviewed" = "1" ]; then
        mount_hits="$hits"
      elif [ -n "$hits" ]; then
        printf 'stopped:\n'
        printf '  %s\n' "$S_MIGRATE_ROOT_MOUNTS_STOP"
        printf '%s' "$hits" | while IFS= read -r c; do [ -n "$c" ] && printf '    %s\n' "$c"; done
        exit 1
      fi
    fi
  fi
fi

# ---------------------------------------------------------------- the state file, before any write
mkdir -p "$brain/.os" 2> /dev/null || stop "could not create .os/ for the state file; nothing moved"
[ -f "$state" ] || : > "$state" 2> /dev/null || stop "could not write $state; nothing moved"
for t in $tipos_root; do
  grep -qxF "type$tab$t" "$state" || printf 'type\t%s\n' "$t" >> "$state"
done

# ---------------------------------------------------------------- the destination workspace
if [ -n "$items" ] && [ ! -e "$brain/$dest" ]; then
  printf 'created\t%s\n' "$dest" >> "$state"
  owner=$(os_strip_emoji "$(os_titulo "$brain/$OS_OPERATOR_FILE")")
  [ -n "$owner" ] || owner="$S_PERSONAL_WORKSPACE_NAME"
  "$here/new-workspace.sh" --brain "$brain" --name "$S_PERSONAL_WORKSPACE_NAME" --role "" \
    --title "" --owner "$owner" --slug "$slug" > /dev/null \
    || stop "could not create $dest with new-workspace.sh; nothing moved"
  printf '%s created\n' "$dest"
fi

# ---------------------------------------------------------------- the moves
movidos=""
n_mov=0
while IFS= read -r it || [ -n "$it" ]; do
  [ -n "$it" ] || continue
  grep -qxF "move$tab$it$tab$dest/$it" "$state" || printf 'move\t%s\t%s\n' "$it" "$dest/$it" >> "$state"
  mkdir -p "$(dirname "$brain/$dest/$it")"
  # A workspace born since spec 076 (C13) already has empty `decisions/` and `learnings/`: an empty
  # folder in the way is not a conflict, and `mv` would otherwise nest the moved one inside it.
  [ -d "$brain/$dest/$it" ] && rmdir "$brain/$dest/$it" 2> /dev/null
  # A plain rename, never `git mv`: it moves tracked and untracked files alike, and git sees the
  # rename at the next commit. The result is checked, never assumed.
  if ! mv "$brain/$it" "$brain/$dest/$it" 2> /dev/null || [ -e "$brain/$it" ] || [ ! -e "$brain/$dest/$it" ]; then
    [ -n "$movidos" ] && printf 'moved before stopping:\n%s' "$movidos"
    stop "could not move $it to $dest/$it — the rest is left as it was; run again once fixed"
  fi
  movidos="$movidos  $it → $dest/$it$nl"
  n_mov=$(( n_mov + 1 ))
  if [ "$interrupt_after" != "0" ] && [ "$n_mov" -ge "$interrupt_after" ]; then
    exit 3
  fi
done <<ITEMS
$items
ITEMS
for t in $tipos; do rmdir "$brain/$t" 2> /dev/null || true; done
rmdir "$brain/initiatives" 2> /dev/null || true

# The map of everything moved, by this run or by a previous one: FROM<tab>TO per line.
mapa=""
while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in
    "move$tab"*) mapa="$mapa${line#move$tab}$nl" ;;
  esac
done < "$state"

# ---------------------------------------------------------------- inbox.md — never lost
inbox_listado=""
if [ "$hay_inbox" = "1" ]; then
  if [ -z "$(tr -d ' \t\r\n' < "$brain/inbox.md")" ]; then
    rm -f "$brain/inbox.md"
    movidos="$movidos  inbox.md — empty, removed$nl"
  else
    while IFS= read -r line || [ -n "$line" ]; do
      [ -n "$(printf '%s' "$line" | tr -d ' \t\r')" ] || continue
      inbox_listado="$inbox_listado  $line$nl"
    done < "$brain/inbox.md"
  fi
fi

# ---------------------------------------------------------------- the matcher
# With `solo_distintivos=1` only the paths with a slash in them (an initiative's, a memory node's)
# count: outside the root's own files, a bare `backlog.md` or `decisions/` is relative to its node.
solo_distintivos=0

# moved_at LINE I -> prints "FROM<tab>TO" for the moved path that starts at position I of LINE, with
# a safe character before it and a path end after it; returns 1 otherwise.
moved_at() {
  local line="$1" i="$2" from to prevc nextc rest
  if [ "$i" -gt 0 ]; then
    prevc="${line:$((i - 1)):1}"
    case "$prevc" in
      ' '|"$tab"|'`'|'|'|'('|'"'|"'"|'['|'<') ;;
      *) return 1 ;;
    esac
  fi
  rest="${line:$i}"
  while IFS="$tab" read -r from to || [ -n "$from" ]; do
    [ -n "$from" ] || continue
    if [ "$solo_distintivos" = "1" ]; then
      case "$from" in */*) ;; *) continue ;; esac
    fi
    case "$rest" in
      "$from"*) ;;
      *) continue ;;
    esac
    nextc="${rest:${#from}:1}"
    case "$nextc" in
      ''|'/'|' '|"$tab"|'`'|'|'|')'|'"'|"'"|']'|'>'|','|';'|':'|'#')
        printf '%s\t%s' "$from" "$to"; return 0 ;;
      '.')
        # a sentence-ending dot, never the dot of an extension
        case "${rest:$(( ${#from} + 1 )):1}" in
          ''|' '|"$tab") printf '%s\t%s' "$from" "$to"; return 0 ;;
        esac
        ;;
    esac
  done <<MAPA
$mapa
MAPA
  return 1
}

# prefiltro LINE -> 0 if LINE contains any moved path at all: the rest are never walked char by char.
prefiltro() {
  local line="$1" from to
  while IFS="$tab" read -r from to || [ -n "$from" ]; do
    [ -n "$from" ] || continue
    case "$line" in *"$from"*) return 0 ;; esac
  done <<MAPA
$mapa
MAPA
  return 1
}

rewrite_line() {
  local line="$1" out="" i=0 len=${#1} m from to
  while [ "$i" -lt "$len" ]; do
    if m=$(moved_at "$line" "$i"); then
      from="${m%%$tab*}"; to="${m#*$tab}"
      out="$out$to"
      i=$(( i + ${#from} ))
      continue
    fi
    out="$out${line:$i:1}"
    i=$(( i + 1 ))
  done
  printf '%s' "$out"
}

count_line() {
  local line="$1" i=0 len=${#1} n=0 m from
  while [ "$i" -lt "$len" ]; do
    if m=$(moved_at "$line" "$i"); then
      from="${m%%$tab*}"
      n=$(( n + 1 ))
      i=$(( i + ${#from} ))
      continue
    fi
    i=$(( i + 1 ))
  done
  printf '%s' "$n"
}

# rewrite_file RELPATH [about] -> 0 rewrote, 1 not present or nothing matched. With `about`, only
# the frontmatter's `about:` line is touched.
rewrite_file() {
  local rel="$1" solo_about="${2:-}" file="$brain/$1" tmp line nueva cambio=0
  [ -f "$file" ] || return 1
  tmp="$file.os-tmp"
  : > "$tmp"
  while IFS= read -r line || [ -n "$line" ]; do
    nueva="$line"
    if [ -z "$solo_about" ] || [ "${line#about: }" != "$line" ]; then
      prefiltro "$line" && nueva=$(rewrite_line "$line")
    fi
    [ "$nueva" = "$line" ] || cambio=1
    printf '%s\n' "$nueva"
  done < "$file" >> "$tmp"
  if [ "$cambio" = "1" ]; then
    mv "$tmp" "$file"
    return 0
  fi
  rm -f "$tmp"
  return 1
}

# ---------------------------------------------------------------- about: of every head under personal
abouts=""
if [ -n "$mapa" ] && [ -d "$brain/$dest" ]; then
  while IFS= read -r f || [ -n "$f" ]; do
    [ -n "$f" ] || continue
    if rewrite_file "${f#$brain/}" about; then abouts="$abouts  ${f#$brain/}$nl"; fi
  done <<LISTADO_ABOUT
$(find "$brain/$dest" -type f -name '*.md' -print 2>/dev/null)
LISTADO_ABOUT
fi

# ---------------------------------------------------------------- tree.md — root lines move height
tree_cambios=""
if [ -f "$brain/$OS_TREE_FILE" ]; then
  prefijos=""
  while IFS="$tab" read -r from to || [ -n "$from" ]; do
    [ -n "$from" ] || continue
    p="${from%%/*}"
    case " $prefijos " in *" $p "*) ;; *) prefijos="$prefijos $p" ;; esac
  done <<MAPA
$mapa
MAPA
  tmp="$brain/$OS_TREE_FILE.os-tmp"; : > "$tmp"; cambio=0; nuevas=""
  while IFS= read -r line || [ -n "$line" ]; do
    clase=""; pat=""
    if decl=$(os_tree_line "$line"); then clase="${decl%%$tab*}"; pat="${decl#*$tab}"; fi
    mover_linea=0
    if [ -n "$clase" ]; then
      for p in $prefijos; do
        case "$pat" in
          "$p"|"$p"/*) mover_linea=1 ;;
        esac
      done
    fi
    if [ "$mover_linea" = "1" ]; then
      nuevas="$nuevas$clase$tab$wsdir/*/$pat$nl"
      cambio=1
      tree_cambios="$tree_cambios  $clase: $pat → $clase: $wsdir/*/$pat$nl"
      continue
    fi
    if [ "$line" = "glob: inbox.md" ] && [ ! -f "$brain/inbox.md" ]; then
      cambio=1
      tree_cambios="$tree_cambios  glob: inbox.md — removed$nl"
      continue
    fi
    printf '%s\n' "$line" >> "$tmp"
  done < "$brain/$OS_TREE_FILE"
  if [ "$cambio" = "1" ]; then
    mv "$tmp" "$brain/$OS_TREE_FILE"
    while IFS="$tab" read -r clase pat || [ -n "$clase" ]; do
      [ -n "$clase" ] || continue
      os_tree_ensure "$brain" "$pat" "$clase" > /dev/null
      grep -qxF "$clase: $pat" "$brain/$OS_TREE_FILE" || stop "tree.md: could not declare $clase: $pat"
    done <<NUEVAS
$nuevas
NUEVAS
  else
    rm -f "$tmp"
  fi
fi

# ---------------------------------------------------------------- routing rewrite
rewritten=""
if [ -n "$mapa" ]; then
  objetivos="$OS_ROOT_RESOLVER_FILE$nl$OS_MOUNTS_ARCHIVO$nl"
  if [ -d "$brain/$dest" ]; then
    objetivos="$objetivos$(cd "$brain" && find "$dest" -type f \( -name resolver.md -o -name backlog.md \) -print 2>/dev/null)$nl"
  fi
  while IFS= read -r rel || [ -n "$rel" ]; do
    [ -n "$rel" ] || continue
    if rewrite_file "$rel"; then rewritten="$rewritten  $rel$nl"; fi
  done <<OBJ
$objetivos
OBJ
fi

# ---------------------------------------------------------------- what still names a moved path
faltan=""
if [ -n "$mapa" ]; then
  while IFS= read -r f || [ -n "$f" ]; do
    [ -n "$f" ] || continue
    rel="${f#$brain/}"
    case "$rel" in
      */decisions.md|*/learnings.md) continue ;;   # index links are relative to their node (043)
      */*) solo_distintivos=1 ;;
      *) solo_distintivos=0 ;;
    esac
    n=0
    while IFS= read -r line || [ -n "$line" ]; do
      prefiltro "$line" || continue
      c=$(count_line "$line"); n=$(( n + c ))
    done < "$f"
    [ "$n" = "0" ] || faltan="$faltan  $rel ($n)$nl"
  done <<LISTADO
$(find "$brain" -type d \( -name .git -o -name .os -o -name .claude \) -prune -o -type f -name '*.md' -print)
LISTADO
  solo_distintivos=0
fi

# ---------------------------------------------------------------- the verdict
[ -n "$movidos" ] && printf 'moved:\n%s' "$movidos"
[ -n "$tree_cambios" ] && printf 'tree.md:\n%s' "$tree_cambios"
[ -n "$abouts" ] && printf 'rewrote about:\n%s' "$abouts"
[ -n "$rewritten" ] && printf 'rewrote:\n%s' "$rewritten"
[ -n "$inbox_listado" ] && printf 'inbox.md — kept, for the operator to route by hand:\n%s' "$inbox_listado"
[ -n "$faltan" ] && printf 'still names a moved path — fix by hand:\n%s' "$faltan"
if [ -n "$mount_hits" ]; then
  printf '%s\n' "$S_MIGRATE_ROOT_MOUNTS_REVIEWED"
  printf '%s' "$mount_hits" | while IFS= read -r c; do [ -n "$c" ] && printf '  %s\n' "$c"; done
fi
if [ -f "$brain/$dest/backlog.md" ]; then
  printf 'next: %s/backlog.md is outside any initiative — split it with migrate-backlogs.sh\n' "$dest"
fi
if [ -z "$movidos$tree_cambios$abouts$rewritten" ] && [ -n "$inbox_listado" ]; then
  printf 'nothing at the root to move; only inbox.md is left\n'
fi

# Reached the end: every move and every rewrite is done — the state has nothing left to resume.
rm -f "$state"
exit 0
