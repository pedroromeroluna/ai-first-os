#!/usr/bin/env bash
# A file declares what replaced it (spec 046, hardened by spec 047). Internal: not invocable — the
# invocable is `skills/supersede.md`.
#
# Usage: supersede.sh --brain DIR --file PATH --by PATH
#        supersede.sh --brain DIR --check
#        supersede.sh --brain DIR --file PATH --unmark
#
# Git does not answer "is this document still current?": the agent reads the working tree, never the
# history. A research file from March and one from July that contradicts it are two equally valid
# files unless the older one says so itself. The mark is one frontmatter key on the file that was
# replaced:
#
#   superseded_by: <path relative to the brain>
#
# WHY THE MARK POINTS FORWARD, FROM THE OLD FILE. The reader at risk is whoever opened the old one;
# a `supersedes:` key on the new file never reaches them. The reverse direction stays answerable
# with one `grep -rl 'superseded_by: <path>'`, and two keys naming each other desync the first time
# a file is renamed. The rule itself is stated once, in `core/CLAUDE.md`.
#
# WHY THE STARTUP SCAN IS NOT TOUCHED. `session-start.sh` reads the frontmatter of heads and never
# opens a content file — decision 1 of spec 045 (Gate 1, 2026-08-29), because the scan has to
# keep fitting on screen. The documents this mark exists for —`research/*.md`, the body of an
# initiative— are all reached by `content:` lines, so a startup line would count the heads and miss
# them: half a check presented as a check. Everything else is audited on demand, with `--check`,
# over both classes of tree line.
#
# WHY A FILE WITH NO FRONTMATTER GETS ONE. `os_fm_set` refuses whatever `fm_read` could not read,
# and `fm_read` answers `sin frontmatter` both for a file that has none and for one that does not
# exist. The files that most need this mark are precisely the headerless ones (measured on a real
# brain: 99 content files, 18 with frontmatter), so the two cases are separated here by an
# `[ -f ]` and only the first one gets a block created above its untouched body. A frontmatter that
# exists and cannot be read —unclosed, over the bound— is refused: writing over it is corrupting the
# file in silence.
#
# WHAT SPEC 047 ADDED, AND WHY (each of these was reproduced on a test brain before being fixed):
#
# - **No write reports success without having happened.** Every `mv`, every redirection and every
#   `os_fm_set` is checked. Before, a file in a directory with no write permission printed that it
#   had been marked and exited 0 with the file untouched.
# - **What only writes documents of the brain.** `--file` has to end in `.md` and be reached by a
#   line of `tree.md`. Before, `[ -f ]` was the whole check, and pointing the command at a git
#   config file prepended a frontmatter block to it and broke the repository.
# - **The spelling of a path is not a way around the checks.** `./d/a.md`, `d//a.md` and `d/a.md`
#   are the same path here, and the value written is always the normalised one — otherwise a file
#   declares that it replaced itself and the audit says the brain is clean.
# - **Nothing follows a symbolic link.** A link is refused instead of being replaced by a regular
#   file, and a path whose directories resolve outside the brain is refused too.
# - **A chain longer than the bound is undecided, never clean.** It is refused when writing and
#   reported when auditing.
# - **`--check` fails loudly over a brain it could not read**, and reports a mark that hides inside
#   a frontmatter it could not parse instead of walking past it.
# - **Closing a head is never silent, and never automatic beyond `active`.** See below.
#
# WHY ONLY AN `active` HEAD WITH NOTHING DEPENDING ON IT IS CLOSED. The active lists of the scan are
# driven by `status:` and `os_cerrado` is their single reader, so a head that reads `active` while
# carrying the mark gives the operator two answers about the same file — that one is closed here,
# and the output says so. The other three states are not that case:
#   · `ongoing` is permanent work. Replacing a document does not end standing work.
#   · `blocked` carries what it is waiting for. Closing it drops that without anyone reading it.
#   · a head another head declares in `depends_on` reads as satisfied once it is `closed`
#     (`sweep.sh`, `deps_abiertas`), so closing it silently unblocks work that nobody unblocked.
# In those three the mark is written, the head is left as it was, the output names the reason, and
# the exit code is 3 so that a script never reads the pending decision as a plain success.
#
# THE CALLOUT (spec 077). Next to the key, the mark writes one line at the top of the body, right
# after the frontmatter, followed by a blank line: `> [!WARNING] This file was replaced by <path>`
# (`SUPERSEDE_CALLOUT` of the strings catalog, in the language of the brain). A reader who opens the
# file in Obsidian or GitHub sees it without reading the frontmatter. Running the mark again changes
# nothing; marking with another `--by` rewrites that one line; `--unmark` removes the key and the
# callout and leaves the rest of the file byte for byte as it was before the mark. The callout is
# recognised by an ownership marker at the end of its line (`<!-- os:superseded -->`, hidden when
# rendered), never by its text, so a warning someone wrote by hand is never touched and a callout in
# another language is still found after the brain changes language. The variant `os:superseded:fm`
# records that the mark created the frontmatter block of a file that had none: only then does the
# unmark remove a frontmatter it leaves empty. The key is written and removed with the reader's
# whitespace rule, and everything else in the file is copied byte for byte. The audit
# (`--check`) reads only the key and does not look at the callout.
#
# Exit: 0 wrote, or the file already said the same thing · 1 invalid arguments, a refusal, or
# `--check` with findings · 2 a named file does not exist · 3 the mark was written and the head
# needs a decision from the operator.
#
# No `set -e`: a refusal is reported, never a stack trace.

set -u

here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"

nl=$(printf '\nx')
nl="${nl%x}"

# How many links of a `superseded_by:` chain are followed before the answer is called undecided. A
# chain is legitimate —a document replaced twice— and a cycle is always an error; the walk already
# terminates on its own because it remembers where it has been, so this bound only guards against a
# pathological brain. Reaching it is reported, never taken for "no cycle here": a ring longer than
# the bound used to be written whole and audited clean.
CAP_CHAIN=100

brain=""
file=""
by=""
check=0
unmark=0
# A flag that takes a value checks that the value is there before consuming it: with the flag as the
# last argument, `shift 2` fails without consuming anything and the loop repeats forever.
while [ $# -gt 0 ]; do
  case "$1" in
    --brain) [ $# -ge 2 ] || os_die "--brain needs a value"; brain="$2"; shift 2 ;;
    --file) [ $# -ge 2 ] || os_die "--file needs a value"; file="$2"; shift 2 ;;
    --by) [ $# -ge 2 ] || os_die "--by needs a value"; by="$2"; shift 2 ;;
    --check) check=1; shift ;;
    --unmark) unmark=1; shift ;;
    *) os_die "unknown argument: $1" ;;
  esac
done

[ -n "$brain" ] || os_die "missing --brain"
[ -d "$brain" ] || os_die "no such brain: $brain"
brain=$(cd "$brain" && pwd)

if [ "$check" = "1" ]; then
  { [ -z "$file" ] && [ -z "$by" ]; } || os_die "--check is exclusive with --file and --by"
elif [ "$unmark" = "1" ]; then
  [ -n "$file" ] || os_die "--unmark needs --file"
  [ -z "$by" ] || os_die "--unmark is exclusive with --by"
else
  [ -n "$file" ] || os_die "missing --file or --check"
  [ -n "$by" ] || os_die "missing --by"
fi

lang=$(os_language "$brain")
os_lang_load "$lang"

# ---------------------------------------------------------------- the paths are the brain's
# Every path of the system is relative to the brain (`core/CLAUDE.md`), and that is what makes the
# mark portable and the audit possible with a plain `[ -f ]`. An absolute path works on one machine;
# a `..` walks out of the brain into a tree nothing here governs. Both are refused before anything
# is read.
# The three of them live in `common.sh` since spec 049, where the second command that validates a
# path written by hand into a frontmatter reads them too. A local copy would be the desync this repo
# already forbids; the wrappers keep this file's calls reading the same as before.
rel_ok() { os_rel_ok "$1"; }
rel_norm() { os_rel_norm "$1"; }
inside_brain() { os_inside_brain "$brain" "$1"; }

# fm_of RELPATH -> reads the frontmatter of a brain-relative path into the fm_* variables.
fm_of() {
  fm_read "$brain/$1"
}

# tiene_marca_textual RELPATH -> 0 if the head of the file names the key even though `fm_read` could
# not parse it. A mark inside a frontmatter that never closes is invisible to every reader of the
# system, which is exactly why the audit has to name it instead of walking past it.
tiene_marca_textual() {
  head -n "$CAP_FRONTMATTER" "$brain/$1" 2>/dev/null | grep -q '^[[:space:]]*superseded_by:'
}

# chain_reaches START TARGET -> 0 reaches it · 1 does not · 2 undecided, the bound was exhausted.
# It stops at the first file that does not exist —a broken chain is a finding of `--check`, not a
# reason to loop— and it remembers where it has been, so a ring is recognised whatever its length.
chain_reaches() {
  local cur="$1" target="$2" n=0 seen="$nl"
  while [ "$n" -lt "$CAP_CHAIN" ]; do
    [ "$cur" = "$target" ] && return 0
    case "$seen" in *"$nl$cur$nl"*) return 1 ;; esac
    seen="$seen$cur$nl"
    [ -f "$brain/$cur" ] || return 1
    fm_of "$cur"
    [ -n "$fm_superseded_by" ] || return 1
    cur=$(rel_norm "$fm_superseded_by")
    rel_ok "$cur" || return 1
    n=$(( n + 1 ))
  done
  return 2
}

# ---------------------------------------------------------------- the two classes of tree line
# Read once, from the one reader of the tree format (`common.sh`). A path that a `glob:` reaches is
# a head and its `status` governs the active lists; a path that only a `content:` reaches is content
# and has no status to govern. A brain whose `tree.md` cannot be read is not a clean brain: both
# readers exit 1 there, and swallowing that turned `--check` into a command that reports "all good"
# about a brain it never read.
# The `archive:` class (spec 048) joins `contents` here and nowhere else in this script: an
# archived document is still a document of the brain, so a mark written on it — or a mark on
# another file that names it — has to be auditable. What archiving changes is what a read loads,
# never what an audit sees.
heads=$(os_tree_files "$brain"); rc_heads=$?
contents=$(os_tree_content_files "$brain"); rc_contents=$?
archived=$(os_tree_archive_files "$brain"); rc_archived=$?
if [ "$rc_archived" = "0" ] && [ -n "$archived" ]; then
  if [ -n "$contents" ]; then contents="$contents$nl$archived"; else contents="$archived"; fi
fi
if [ "$rc_heads" != "0" ] || [ "$rc_contents" != "0" ]; then
  printf "$S_SUPERSEDE_NO_TREE\n" "$brain" >&2
  exit 1
fi

es_cabeza() {
  case "$nl$heads$nl" in *"$nl$1$nl"*) return 0 ;; esac
  return 1
}

alcanzado() {
  case "$nl$heads$nl" in *"$nl$1$nl"*) return 0 ;; esac
  case "$nl$contents$nl" in *"$nl$1$nl"*) return 0 ;; esac
  return 1
}

# ---------------------------------------------------------------- the callout of the mark (spec 077)
# The managed callout carries its ownership in a trailing HTML comment: `<!-- os:superseded -->`, or
# `<!-- os:superseded:fm -->` when the mark created the frontmatter block of a file that had none. The
# marker is what makes a callout the command's own — never its text, so a warning written by hand, even
# one that opens with the same words, is left verbatim, and a callout written in another language is
# still recognised after the brain changes language.
CALLOUT_MARK='<!-- os:superseded -->'
CALLOUT_MARK_FM='<!-- os:superseded:fm -->'

# fm_end FILE -> prints the number of the line that closes the frontmatter (the second `---`). Only
# called on a file whose frontmatter `fm_read` could read.
fm_end() {
  local l n=0 hits=0
  while IFS= read -r l || [ -n "$l" ]; do
    n=$(( n + 1 ))
    if [ "$l" = "---" ]; then
      hits=$(( hits + 1 ))
      if [ "$hits" = "2" ]; then printf '%s' "$n"; return 0; fi
    fi
  done < "$1"
  return 1
}

# callout_managed LINE -> 0 if the line is a callout this command wrote (it ends with the marker).
callout_managed() {
  case "$1" in
    "> [!WARNING] "*"$CALLOUT_MARK"|"> [!WARNING] "*"$CALLOUT_MARK_FM") return 0 ;;
  esac
  return 1
}

# callout_created_fm LINE -> 0 if the managed callout says the mark created the frontmatter block.
callout_created_fm() {
  case "$1" in *"$CALLOUT_MARK_FM") return 0 ;; esac
  return 1
}

# callout_set RELFILE BY [new-fm] -> the callout is the first line of the body with the text for BY,
# followed by a blank line. Byte-exact for everything else: the file is spliced with head and tail,
# never re-read line by line. An existing managed callout keeps its `:fm` flag. Returns 1 on failure.
callout_set() {
  local f="$brain/$1" end next line tmp mark="$CALLOUT_MARK"
  end=$(fm_end "$f") || return 1
  next=$(tail -n +"$(( end + 1 ))" "$f" | head -n 1)
  if { [ "${3:-}" = "new-fm" ]; } || { callout_managed "$next" && callout_created_fm "$next"; }; then
    mark="$CALLOUT_MARK_FM"
  fi
  line="> [!WARNING] $(printf "$S_SUPERSEDE_CALLOUT" "$2") $mark"
  tmp="$f.os-tmp"
  rm -f "$tmp"
  if callout_managed "$next"; then
    if ! { head -n "$end" "$f"; printf '%s\n' "$line"; tail -n +"$(( end + 2 ))" "$f"; } 2>/dev/null > "$tmp"; then rm -f "$tmp"; return 1; fi
  else
    if ! { head -n "$end" "$f"; printf '%s\n\n' "$line"; tail -n +"$(( end + 1 ))" "$f"; } 2>/dev/null > "$tmp"; then rm -f "$tmp"; return 1; fi
  fi
  os_replace_file "$tmp" "$f"
}

# callout_unset RELFILE -> removes the managed callout and the blank line that follows it, if there.
callout_unset() {
  local f="$brain/$1" end next after skip tmp
  end=$(fm_end "$f") || return 1
  next=$(tail -n +"$(( end + 1 ))" "$f" | head -n 1)
  callout_managed "$next" || return 0
  after=$(tail -n +"$(( end + 2 ))" "$f" | head -n 1)
  skip=$(( end + 2 ))
  [ -z "$after" ] && [ "$(tail -n +"$(( end + 2 ))" "$f" | wc -c | tr -d ' ')" != "0" ] && skip=$(( end + 3 ))
  tmp="$f.os-tmp"
  rm -f "$tmp"
  if ! { head -n "$end" "$f"; tail -n +"$skip" "$f"; } 2>/dev/null > "$tmp"; then rm -f "$tmp"; return 1; fi
  os_replace_file "$tmp" "$f"
}

# is_key LINE KEY -> 0 if the frontmatter line is that key, with the reader's rule (`fm_read`): the text
# before the first colon, without the spaces around it.
is_key() {
  local k="${1%%:*}"
  case "$1" in *:*) ;; *) return 1 ;; esac
  while [ "${k# }" != "$k" ]; do k="${k# }"; done
  while [ "${k% }" != "$k" ]; do k="${k% }"; done
  [ "$k" = "$2" ]
}

# fm_key_set RELFILE KEY VALUE -> sets the key inside the frontmatter (replacing a line that holds it,
# otherwise before the closing `---`) and copies the body byte for byte, so a body with no final
# newline keeps having none.
fm_key_set() {
  local f="$brain/$1" key="$2" value="$3" end l n=0 put=0 tmp
  end=$(fm_end "$f") || return 1
  tmp="$f.os-tmp"
  rm -f "$tmp"
  if ! {
    while IFS= read -r l || [ -n "$l" ]; do
      n=$(( n + 1 ))
      [ "$n" -le "$end" ] || break
      if [ "$n" -gt 1 ] && [ "$n" -lt "$end" ] && is_key "$l" "$key"; then
        if [ "$put" = "0" ]; then printf '%s: %s\n' "$key" "$value"; put=1; fi
        continue
      fi
      if [ "$n" = "$end" ] && [ "$put" = "0" ]; then printf '%s: %s\n' "$key" "$value"; put=1; fi
      printf '%s\n' "$l"
    done < "$f"
    tail -n +"$(( end + 1 ))" "$f"
  } 2>/dev/null > "$tmp"; then rm -f "$tmp"; return 1; fi
  os_replace_file "$tmp" "$f"
}

# key_unset RELFILE DROP_EMPTY -> removes every `superseded_by` line of the frontmatter (the reader's
# whitespace rule); with DROP_EMPTY=1 a frontmatter left with nothing in it goes too. The key must be
# gone afterwards, or it fails.
key_unset() {
  local f="$brain/$1" drop="$2" end l n=0 kept="" tmp
  end=$(fm_end "$f") || return 1
  tmp="$f.os-tmp"
  rm -f "$tmp"
  while IFS= read -r l || [ -n "$l" ]; do
    n=$(( n + 1 ))
    [ "$n" -le "$end" ] || break
    if [ "$n" -gt 1 ] && [ "$n" -lt "$end" ] && is_key "$l" superseded_by; then continue; fi
    kept="$kept$l$nl"
  done < "$f"
  if ! {
    if [ "$drop" = "1" ] && [ "$kept" = "---$nl---$nl" ]; then :; else printf '%s' "$kept"; fi
    tail -n +"$(( end + 1 ))" "$f"
  } 2>/dev/null > "$tmp"; then rm -f "$tmp"; return 1; fi
  os_replace_file "$tmp" "$f" || return 1
  fm_read "$f"
  [ -z "$fm_superseded_by" ] || return 1
  return 0
}

# ================================================================ --check
if [ "$check" = "1" ]; then
  hallazgos=""
  n=0
  todos="$heads$nl$contents"
  vistos="$nl"
  while IFS= read -r f || [ -n "$f" ]; do
    [ -n "$f" ] || continue
    case "$vistos" in *"$nl$f$nl"*) continue ;; esac
    vistos="$vistos$f$nl"
    fm_of "$f"
    if [ -n "$fm_roto" ]; then
      case "$fm_roto" in
        'sin frontmatter') continue ;;
      esac
      if tiene_marca_textual "$f"; then
        hallazgos="$hallazgos$f: $(printf "$S_SUPERSEDE_UNREADABLE_MARK" "$fm_roto")$nl"
        n=$(( n + 1 ))
      fi
      continue
    fi
    [ -n "$fm_superseded_by" ] || continue
    # Copied out before anything else reads frontmatter: `chain_reaches` walks the chain with the
    # same `fm_read`, and it would otherwise leave this file's `status` overwritten by the last
    # link's.
    target=$(rel_norm "$fm_superseded_by")
    estado="$fm_status"
    if [ "$target" = "$f" ]; then
      hallazgos="$hallazgos$f: $S_SUPERSEDE_SELF$nl"
      n=$(( n + 1 ))
      continue
    fi
    if ! rel_ok "$target" || ! inside_brain "$target" || [ ! -f "$brain/$target" ]; then
      hallazgos="$hallazgos$f: $(printf "$S_SUPERSEDE_DANGLING" "$target")$nl"
      n=$(( n + 1 ))
      continue
    fi
    chain_reaches "$target" "$f"; rc_chain=$?
    if [ "$rc_chain" = "0" ]; then
      hallazgos="$hallazgos$f: $(printf "$S_SUPERSEDE_CYCLE" "$target")$nl"
      n=$(( n + 1 ))
      continue
    fi
    if [ "$rc_chain" = "2" ]; then
      hallazgos="$hallazgos$f: $(printf "$S_SUPERSEDE_CHAIN_UNDECIDED" "$target" "$CAP_CHAIN")$nl"
      n=$(( n + 1 ))
      continue
    fi
    # An open head is reported when its status is `active`: that is the one state this command
    # closes on its own, so finding it means the file was edited by hand afterwards. `ongoing`,
    # `blocked` and a head something depends on are left open on purpose (see the header), and an
    # audit that reported them would never go green on a brain that uses them.
    if es_cabeza "$f" && [ "$estado" = "active" ]; then
      hallazgos="$hallazgos$f: $(printf "$S_SUPERSEDE_OPEN_HEAD" "$estado")$nl"
      n=$(( n + 1 ))
    fi
  done <<TODOS
$todos
TODOS
  if [ "$n" = "0" ]; then
    printf '%s\n' "$S_SUPERSEDE_CHECK_CLEAN"
    exit 0
  fi
  printf '%s' "$hallazgos"
  exit 1
fi

# ================================================================ --unmark
if [ "$unmark" = "1" ]; then
  file=$(rel_norm "$file")
  rel_ok "$file" || os_die "--file is not a path relative to the brain: $file"
  case "$file" in
    *.md) ;;
    *) printf "$S_SUPERSEDE_NOT_MD\n" "$file" >&2; exit 1 ;;
  esac
  inside_brain "$file" || { printf "$S_SUPERSEDE_OUT_OF_BRAIN\n" "$file" >&2; exit 1; }
  if [ -L "$brain/$file" ]; then printf "$S_SUPERSEDE_IS_LINK\n" "$file" >&2; exit 1; fi
  [ -f "$brain/$file" ] || { printf "$S_SUPERSEDE_NO_FILE\n" "$file" >&2; exit 2; }
  alcanzado "$file" || { printf "$S_SUPERSEDE_NOT_IN_TREE\n" "$file" >&2; exit 1; }
  fm_of "$file"
  if [ -n "$fm_roto" ]; then
    case "$fm_roto" in
      'sin frontmatter') printf "$S_SUPERSEDE_NOT_MARKED\n" "$file"; exit 0 ;;
      *) printf "$S_SUPERSEDE_UNREADABLE\n" "$file" "$fm_roto" >&2; exit 1 ;;
    esac
  fi
  if [ -z "$fm_superseded_by" ]; then
    printf "$S_SUPERSEDE_NOT_MARKED\n" "$file"
    exit 0
  fi
  drop=0
  first=$(tail -n +"$(( $(fm_end "$brain/$file") + 1 ))" "$brain/$file" | head -n 1)
  if callout_managed "$first" && callout_created_fm "$first"; then drop=1; fi
  callout_unset "$file" && key_unset "$file" "$drop" || {
    printf "$S_SUPERSEDE_WRITE_FAILED\n" "$file" >&2
    exit 1
  }
  printf "$S_SUPERSEDE_UNMARKED\n" "$file"
  exit 0
fi

# ================================================================ writing the mark
file=$(rel_norm "$file")
by=$(rel_norm "$by")

rel_ok "$file" || os_die "--file is not a path relative to the brain: $file"
rel_ok "$by" || os_die "--by is not a path relative to the brain: $by"

# A document of the brain, and nothing else. `[ -f ]` alone accepts `.git/config` and the block this
# script writes over it is not a frontmatter there: it is a broken repository with no way back.
for p in "$file" "$by"; do
  case "$p" in
    *.md) ;;
    *) printf "$S_SUPERSEDE_NOT_MD\n" "$p" >&2; exit 1 ;;
  esac
  inside_brain "$p" || { printf "$S_SUPERSEDE_OUT_OF_BRAIN\n" "$p" >&2; exit 1; }
done

if [ -L "$brain/$file" ] || [ -L "$brain/$by" ]; then
  [ -L "$brain/$file" ] && p="$file" || p="$by"
  printf "$S_SUPERSEDE_IS_LINK\n" "$p" >&2
  exit 1
fi

if [ ! -f "$brain/$file" ]; then
  printf "$S_SUPERSEDE_NO_FILE\n" "$file" >&2
  exit 2
fi
if [ ! -f "$brain/$by" ]; then
  printf "$S_SUPERSEDE_NO_FILE\n" "$by" >&2
  exit 2
fi

# The mark goes on a file the tree governs. A file no line of `tree.md` reaches is invisible to
# `--check`, so the mark on it is a promise nothing keeps — and it is how a file that is not a
# document of the brain gets here in the first place.
alcanzado "$file" || { printf "$S_SUPERSEDE_NOT_IN_TREE\n" "$file" >&2; exit 1; }

if [ "$file" = "$by" ]; then
  printf '%s\n' "$S_SUPERSEDE_SELF" >&2
  exit 1
fi

# A chain is written without complaint —a document replaced twice reaches the last one by following
# it— and a cycle is refused: it is always an error, and it hangs whoever follows it. A chain the
# walk could not finish is refused too: undecided is not the same as clean.
chain_reaches "$by" "$file"; rc_chain=$?
if [ "$rc_chain" = "0" ]; then
  printf "$S_SUPERSEDE_WOULD_CYCLE\n" "$by" "$file" >&2
  exit 1
fi
if [ "$rc_chain" = "2" ]; then
  printf "$S_SUPERSEDE_CHAIN_TOO_LONG\n" "$by" "$CAP_CHAIN" >&2
  exit 1
fi

fm_of "$file"
case "$fm_roto" in
  "")
    if [ "$fm_superseded_by" = "$by" ]; then
      callout_set "$file" "$by" || {
        printf "$S_SUPERSEDE_WRITE_FAILED\n" "$file" >&2
        exit 1
      }
      printf "$S_SUPERSEDE_ALREADY\n" "$file" "$by"
      exit 0
    fi
    # A body that opens with a `---` rule looks like a frontmatter to a reader that only sees the
    # delimiters, and the key would land in the middle of the prose.
    os_fm_shape_ok "$brain/$file" || {
      printf "$S_SUPERSEDE_NOT_FRONTMATTER\n" "$file" >&2
      exit 1
    }
    fm_key_set "$file" superseded_by "$by" || {
      printf "$S_SUPERSEDE_WRITE_FAILED\n" "$file" >&2
      exit 1
    }
    callout_set "$file" "$by" || {
      printf "$S_SUPERSEDE_WRITE_FAILED\n" "$file" >&2
      exit 1
    }
    ;;
  'sin frontmatter')
    # The file exists (checked above) and has no frontmatter at all: the block is created above the
    # body, which is copied byte for byte. This is the only case where this script writes a
    # frontmatter instead of asking `os_fm_set` for it.
    tmp="$brain/$file.os-tmp"
    rm -f "$tmp"
    if ! {
      printf -- '---\n'
      printf 'superseded_by: %s\n' "$by"
      printf -- '---\n'
      cat "$brain/$file"
    } 2>/dev/null > "$tmp"; then
      rm -f "$tmp"
      printf "$S_SUPERSEDE_WRITE_FAILED\n" "$file" >&2
      exit 1
    fi
    os_replace_file "$tmp" "$brain/$file" || {
      printf "$S_SUPERSEDE_WRITE_FAILED\n" "$file" >&2
      exit 1
    }
    callout_set "$file" "$by" new-fm || {
      printf "$S_SUPERSEDE_WRITE_FAILED\n" "$file" >&2
      exit 1
    }
    ;;
  *)
    # Unclosed, or over `CAP_FRONTMATTER`. Writing over a frontmatter that cannot be read is
    # corrupting the file in silence.
    printf "$S_SUPERSEDE_UNREADABLE\n" "$file" "$fm_roto" >&2
    exit 1
    ;;
esac

# ---------------------------------------------------------------- the head, out loud
# ref_of RELPATH -> the `<scope>#<name>` reference by which another head names this one in its
# `depends_on:`. Same convention `sweep.sh` resolves, read from the same two helpers.
ref_of() {
  local f="$1" wsdir resto org
  wsdir=$(os_ws_dir "$brain")
  case "$f" in
    "$wsdir"/*)
      resto="${f#$wsdir/}"
      org="${resto%%/*}"
      ;;
    *) org="$OS_ROOT_LABEL" ;;
  esac
  printf '%s#%s' "$org" "$(os_node_name "$f")"
}

# depende_de_mi REF -> the heads that declare REF in `depends_on:`, one per line.
depende_de_mi() {
  local ref="$1" h
  while IFS= read -r h || [ -n "$h" ]; do
    [ -n "$h" ] || continue
    [ "$h" = "$file" ] && continue
    fm_of "$h"
    [ -n "$fm_depends_on" ] || continue
    case ",${fm_depends_on//[[:space:]\[\]]/}," in
      *",$ref,"*) printf '%s\n' "$h" ;;
    esac
  done <<HEADS
$heads
HEADS
}

pendiente=0
motivo=""
if es_cabeza "$file"; then
  fm_of "$file"
  estado="$fm_status"
  esperando="$fm_waiting_on"
  [ -n "$esperando" ] || esperando="$fm_blocked"
  [ -n "$esperando" ] || esperando="$S_SUPERSEDE_NO_REASON"
  dependientes=$(depende_de_mi "$(ref_of "$file")" | tr '\n' ' ')
  dependientes="${dependientes% }"
  if os_cerrado "$estado"; then
    :
  elif [ -z "$estado" ]; then
    pendiente=1
    motivo=$(printf "$S_SUPERSEDE_HEAD_NO_STATUS" "$file")
  elif [ "$estado" = "ongoing" ]; then
    pendiente=1
    motivo=$(printf "$S_SUPERSEDE_HEAD_ONGOING" "$file")
  elif [ "$estado" = "blocked" ]; then
    pendiente=1
    motivo=$(printf "$S_SUPERSEDE_HEAD_BLOCKED" "$file" "$esperando")
  elif [ -n "$dependientes" ]; then
    pendiente=1
    motivo=$(printf "$S_SUPERSEDE_HEAD_DEPENDED_ON" "$file" "$dependientes" "$by")
  elif [ "$estado" = "active" ]; then
    fm_key_set "$file" status closed || {
      printf "$S_SUPERSEDE_WRITE_FAILED\n" "$file" >&2
      exit 1
    }
    motivo=$(printf "$S_SUPERSEDE_HEAD_CLOSED" "$file")
  else
    # A status outside the vocabulary is declared, never interpreted (`os_estado_valido`).
    pendiente=1
    motivo=$(printf "$S_SUPERSEDE_HEAD_UNKNOWN_STATUS" "$file" "$estado")
  fi
fi

printf "$S_SUPERSEDE_WROTE\n" "$file" "$by"
[ -n "$motivo" ] && printf '%s\n' "$motivo"
if [ "$pendiente" = "1" ]; then
  printf '%s\n' "$S_SUPERSEDE_HEAD_PENDING"
  exit 3
fi
exit 0
