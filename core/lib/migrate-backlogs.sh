#!/usr/bin/env bash
# One-time split of a workspace's or the root's own `backlog.md` — the destination `capture` and
# `close-session` used before spec 057 — into the `backlog.md` of the initiative each task names.
# Internal: not invocable — run on demand, over any brain; never commits, same pattern as
# `migrate-canonicals.sh` (specs 043/053) and `rename-workspaces.sh` (spec 039).
#
# Usage: migrate-backlogs.sh --brain DIR
#
# A task written before this spec names its initiative between parentheses, at the front of its own
# text — `- [ ] tsk-005 (lote-01) Renegotiate the deposit ...` — because that is all the old
# `capture` did with it: the parenthesis never changed where the line landed. This script reads that
# same parenthesis to decide where the line moves to now.
#
# For each task in a stray backlog (the root's `backlog.md`, or `<wsdir>/<org>/backlog.md`):
#   1. Take the text between the first `(` and its matching `)`, if the task's text starts with one.
#   2. Look for an initiative whose **slug** is exactly that text, in the same scope the stray
#      backlog belongs to (the root, or that one workspace).
#   3. With no slug match, look for an initiative whose **head title** (`# Title`) is exactly that
#      text — only when that produces at most one candidate. Two initiatives with the same title is
#      an ambiguity this script does not resolve: the task stays listed, never guessed at.
#   4. No match at all — no parenthesis, an unknown slug, a title that resolves to zero or several
#      initiatives, or an initiative the migration would have to create — the task stays exactly
#      where it was and is named in the report. Nothing here ever writes a new initiative head: an
#      initiative that does not exist is not created by a migration (the spec's own stopping rule).
#
# A matched line moves byte for byte — the parenthesis stays inside its text, since this script
# never rewrites the line, only its file. The `tsk-XXX` id is not renumbered: it already identifies
# the task everywhere it might be cited from.
#
# Idempotent: a second run over what the first run left finds the same unmatched lines, still
# unmatched, and changes nothing (`git status --porcelain` identical, no new commit — this script
# never commits, same as its two precedents).
#
# Stops without moving anything, brain-wide, when a `tsk-XXX` id already used in some initiative's
# `backlog.md` shows up again in a stray one: the spec's own stopping condition — a repeated id
# across a stray backlog and an initiative one is a data problem to fix by hand, never something
# this script renumbers on its own guess.
#
# Exit: 0 ran (whether or not everything got moved) · 1 an id collision stopped it before moving
# anything · 2 no brain at that path.

set -u

here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"

brain=""
while [ $# -gt 0 ]; do
  case "$1" in
    --brain) brain="${2:-}"; shift 2 ;;
    *) os_die "argumento desconocido: $1" ;;
  esac
done
[ -n "$brain" ] || os_die "falta --brain"
[ -d "$brain" ] || { printf 'no existe el brain: %s\n' "$brain" >&2; exit 2; }
brain=$(cd "$brain" && pwd)

nl=$(printf '\nx'); nl="${nl%x}"
os_ws_check "$brain"
wsdir=$(os_ws_dir "$brain")

# ---------------------------------------------------------------- el universo de backlogs sueltos
# Un backlog suelto es el que vive a la altura de la raíz o de una organización, nunca adentro de
# `initiatives/`: exactamente el destino que `capture` y `close-session` usaban antes de esta spec.
sueltos=""
[ -f "$brain/backlog.md" ] && sueltos="$sueltos$brain/backlog.md$nl"
while IFS= read -r o || [ -n "$o" ]; do
  [ -n "$o" ] || continue
  [ -f "$brain/$wsdir/$o/backlog.md" ] && sueltos="$sueltos$brain/$wsdir/$o/backlog.md$nl"
done <<ORGS
$(os_org_slugs "$brain")
ORGS

if [ -z "$sueltos" ]; then
  printf 'ningún backlog.md fuera de una iniciativa: nada para migrar.\n'
  exit 0
fi

# ---------------------------------------------------------------- chequeo de ids repetidos (parar)
# Un id que ya está citado en el backlog de una iniciativa y vuelve a aparecer en uno suelto es un
# dato roto, no algo que este script arregla renumerando. Se para antes de mover una sola línea.
sep="$OS_SEP"
todos=$(find "$brain" -name 'backlog.md' -not -path '*/.git/*' -not -path '*/.os/*' 2>/dev/null)
pares=""
while IFS= read -r f || [ -n "$f" ]; do
  [ -n "$f" ] || continue
  while IFS= read -r line || [ -n "$line" ]; do
    os_backlog_lee "$line" || continue
    [ -n "$bl_id" ] || continue
    pares="$pares$bl_id$sep${f#$brain/}$nl"
  done < "$f"
done <<TODOS
$todos
TODOS

colision=""
checados=""
while IFS= read -r par || [ -n "$par" ]; do
  [ -n "$par" ] || continue
  id="${par%%$sep*}"
  case "$nl$checados$nl" in *"$nl$id$nl"*) continue ;; esac
  checados="$checados$nl$id"
  archivos=""
  while IFS= read -r par2 || [ -n "$par2" ]; do
    [ -n "$par2" ] || continue
    [ "${par2%%$sep*}" = "$id" ] || continue
    a="${par2#*$sep}"
    case "$nl$archivos$nl" in *"$nl$a$nl"*) ;; *) archivos="$archivos$nl$a" ;; esac
  done <<PARES2
$pares
PARES2
  n=$(printf '%s\n' "$archivos" | grep -c .)
  if [ "$n" -gt 1 ]; then
    colision="$colision$id: $(printf '%s' "$archivos" | tr "$nl" ' ')$nl"
  fi
done <<PARES
$pares
PARES

if [ -n "$colision" ]; then
  printf 'ids repetidos entre backlogs — no se movió nada:\n' >&2
  printf '%s' "$colision" | while IFS= read -r c || [ -n "$c" ]; do
    [ -n "$c" ] && printf '  %s\n' "$c" >&2
  done
  exit 1
fi

# ---------------------------------------------------------------- reparto
movidas=0
listadas=""
n_listadas=0

migrar_archivo() {
  # migrar_archivo RUTA PREFIX — PREFIX es "$wsdir/$org/" o "" para la raíz.
  local ruta="$1" prefix="$2" tmp="$1.os-tmp" line texto ini destino
  : > "$tmp"
  while IFS= read -r line || [ -n "$line" ]; do
    if ! os_backlog_lee "$line"; then
      printf '%s\n' "$line" >> "$tmp"
      continue
    fi
    texto="$bl_texto"
    ini=""
    case "$texto" in
      '('*')'*)
        candidato="${texto#\(}"
        candidato="${candidato%%\)*}"
        if os_ini_existe "$brain" "$prefix" "$candidato"; then
          ini="$candidato"
        else
          # Sin slug exacto, por título — solo si produce un único candidato (delegado al agente,
          # spec 057).
          n_match=0
          match_slug=""
          while IFS= read -r s || [ -n "$s" ]; do
            [ -n "$s" ] || continue
            if [ "$(os_titulo "$brain/$(os_ini_head_rel "$brain" "$prefix" "$s")")" = "$candidato" ]; then
              n_match=$(( n_match + 1 ))
              match_slug="$s"
            fi
          done <<SLUGS
$(os_ini_slugs "$brain" "$prefix")
SLUGS
          [ "$n_match" = "1" ] && ini="$match_slug"
        fi
        ;;
    esac
    if [ -n "$ini" ]; then
      os_ini_backlog_asegurar "$brain" "$prefix" "$ini" > /dev/null || true
      printf '%s\n' "$line" >> "$brain/$(os_ini_backlog_rel "$prefix" "$ini")"
      movidas=$(( movidas + 1 ))
    else
      printf '%s\n' "$line" >> "$tmp"
      n_listadas=$(( n_listadas + 1 ))
      listadas="$listadas${ruta#$brain/}: $line$nl"
    fi
  done < "$ruta"
  if diff -q "$tmp" "$ruta" > /dev/null 2>&1; then
    rm -f "$tmp"
  else
    mv "$tmp" "$ruta"
  fi
}

while IFS= read -r ruta || [ -n "$ruta" ]; do
  [ -n "$ruta" ] || continue
  if [ "$ruta" = "$brain/backlog.md" ]; then
    migrar_archivo "$ruta" ""
  else
    resto="${ruta#$brain/$wsdir/}"
    org="${resto%%/backlog.md}"
    migrar_archivo "$ruta" "$wsdir/$org/"
  fi
done <<SUELTOS
$sueltos
SUELTOS

printf 'movidas: %s\n' "$movidas"
if [ "$n_listadas" = "0" ]; then
  printf 'listadas: 0\n'
else
  printf 'listadas: %s — sin iniciativa reconocible, siguen donde estaban:\n' "$n_listadas"
  printf '%s' "$listadas" | while IFS= read -r l || [ -n "$l" ]; do
    [ -n "$l" ] && printf '  %s\n' "$l"
  done
fi
exit 0
