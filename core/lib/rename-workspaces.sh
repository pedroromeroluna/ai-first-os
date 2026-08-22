#!/usr/bin/env bash
# Parte determinística de `rename-workspaces`: adopta el nombre actual de la carpeta de espacios de
# trabajo en un brain nacido antes de él (spec 039, P6). Interno: no es invocable.
#
# Uso: rename-workspaces.sh --brain DIR
#
# Corre solo a pedido del operador — nunca lo corre el instalador ni el arranque de sesión.
#
# **No usa `os_ws_check`.** Esa función frena con un layout a medias porque cualquier OTRO comando
# no sabe repararlo; este comando es la reparación, así que corre su propio chequeo, pensado para
# poder interrumpirse en cualquier punto y terminar en una corrida posterior:
#   (a) existen `orgs` y `workspaces` a la vez → error, no toca nada.
#   (b) no existe `orgs` y no existe `workspaces` → nada que renombrar, exit 0 (brain sin espacios
#       de trabajo todavía).
#   (c) existe `orgs` (diga lo que diga el árbol) → hay que mover la carpeta.
#   (d) no existe `orgs` pero existe `workspaces` y algún archivo de ruteo todavía dice `orgs` —
#       una corrida anterior se cortó después de mover la carpeta pero antes de terminar de
#       reescribir, o después de reescribir `tree.md` pero antes de mover— → falta completar la
#       reescritura, sin mover nada.
# Los casos (c) y (d) no se distinguen con un `if`: el comando hace los tres pasos (reescribir
# `tree.md`, mover la carpeta si todavía está `orgs`, reescribir el resto) siempre, cada uno solo si
# hace falta, y termina en el mismo lugar sin importar en qué paso se haya cortado la vez anterior.
# El orden — `tree.md` primero, la carpeta después, el resto al final — es a propósito: minimiza la
# ventana en la que el árbol declara un nombre y el disco declara otro, mejor que dejar esa ventana
# abierta hasta el final.
#
#   1. Reescribe el prefijo `orgs` por `workspaces` en `tree.md`, si todavía lo tiene.
#   2. Mueve `orgs` a `workspaces` si `orgs` existe en disco — `git mv` en un brain git, `mv` si no.
#   3. Reescribe el prefijo en el resto de lo que el sistema lee como estructura o ruteo:
#      `resolver.md` de la raíz, `resolver.md` de cada espacio de trabajo, `backlog.md` de la raíz
#      y de cada espacio, y `mounts.md`.
#   4. No reescribe ningún otro archivo: lista los `.md` del brain que todavía contienen el prefijo
#      `orgs`, con su conteo, para que el operador decida.
#   5. No commitea: la sesión commitea después, como todo lo demás del brain.
#
# El reemplazo del prefijo es sensible al contexto — nunca un `${var//orgs\//workspaces\/}` a
# ciegas: una URL (`https://github.com/orgs/acme/app.git`) o una ruta local (`/tmp/orgs/x`) llevan
# `orgs/` sin que sea el prefijo del brain, y reescribirlas rompería el remote o la ruta. Se
# reemplaza solo cuando `orgs/` está precedido por el inicio de línea, un espacio, un tab, un
# acento grave, `|`, `(`, `"` o `'`; nunca cuando lo precede `/`, `:`, `.`, `-`, `_`, una letra o un
# dígito — ni cuando lo precede cualquier otro carácter no nombrado acá, por seguridad. Solo bash,
# carácter a carácter — nada de sed ni awk (E7, PATH restringido).
#
# Exit: 0 renombró, o no había nada que renombrar · 1 layout inválido (las dos carpetas a la vez).
#
# Sin `set -e`: un fallo a mitad de la reescritura de archivos tiene que dejar ver cuáles quedaron
# hechas.

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
[ -d "$brain" ] || os_die "no existe el brain: $brain"
brain=$(cd "$brain" && pwd)

lang=$(os_language "$brain")
os_lang_load "$lang"

old_name="orgs"
new_name="workspaces"
tiene_old=0; tiene_new=0
[ -d "$brain/$old_name" ] && tiene_old=1
[ -d "$brain/$new_name" ] && tiene_new=1

# (a) las dos carpetas a la vez: nadie eligió una. Mismo mensaje que `os_ws_check`, sin usar la
# función — este comando no puede negarse a correr por el estado que existe justamente para
# reparar.
if [ "$tiene_old" = "1" ] && [ "$tiene_new" = "1" ]; then
  os_die "$S_WS_LAYOUT_BOTH"
fi

# (b) ninguna de las dos: no hay nada que este comando pueda hacer.
if [ "$tiene_old" = "0" ] && [ "$tiene_new" = "0" ]; then
  printf '%s\n' "$S_WS_RENAME_NOTHING"
  exit 0
fi

# ---------------------------------------------------------------- reemplazo sensible al contexto
pat="$old_name/"
pat_len=${#pat}

# rewrite_line LINEA -> la línea con el prefijo reemplazado donde corresponde, por stdout.
rewrite_line() {
  local line="$1" out="" i=0 len=${#line} segmento prevc prev_ok
  while [ "$i" -lt "$len" ]; do
    segmento="${line:$i:$pat_len}"
    if [ "$segmento" = "$pat" ]; then
      if [ "$i" -eq 0 ]; then
        prev_ok=1
      else
        prevc="${line:$((i - 1)):1}"
        case "$prevc" in
          ' '|$'\t'|'`'|'|'|'('|'"'|"'"|'['|'<'|'*') prev_ok=1 ;;
          *) prev_ok=0 ;;
        esac
      fi
      if [ "$prev_ok" = "1" ]; then
        out="${out}${new_name}/"
        i=$(( i + pat_len ))
        continue
      fi
    fi
    out="${out}${line:$i:1}"
    i=$(( i + 1 ))
  done
  printf '%s' "$out"
}

# rewrite_prefix ARCHIVO -> reescribe el archivo si alguna línea cambió; exit 0 si reescribió,
# 1 si no existe o si ninguna línea tenía nada para cambiar (no lo toca, no lo reporta).
rewrite_prefix() {
  local file="$1" tmp line nueva cambio=0
  [ -f "$file" ] || return 1
  tmp="$file.os-tmp"
  : > "$tmp"
  while IFS= read -r line || [ -n "$line" ]; do
    nueva=$(rewrite_line "$line")
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

# ---------------------------------------------------------------- (1) tree.md primero
reescritos=""
hubo_cambio=0
if rewrite_prefix "$brain/tree.md"; then
  reescritos="$reescritos  tree.md
"
  hubo_cambio=1
fi

# ---------------------------------------------------------------- (2) mover la carpeta si hace falta
if [ -d "$brain/$old_name" ]; then
  es_git=0
  if git -C "$brain" rev-parse --is-inside-work-tree > /dev/null 2>&1; then es_git=1; fi
  if [ "$es_git" = "1" ]; then
    git -C "$brain" mv "$old_name" "$new_name" || os_die "no se pudo mover $old_name a $new_name con git mv"
  else
    mv "$brain/$old_name" "$brain/$new_name" || os_die "no se pudo mover $old_name a $new_name"
  fi
  printf '%s\n' "$S_WS_RENAME_MOVED"
  hubo_cambio=1
fi

# ---------------------------------------------------------------- (3) el resto del ruteo
objetivos="resolver.md${OS_SEP}"
for res in "$brain/$new_name"/*/resolver.md; do
  [ -f "$res" ] || continue
  objetivos="$objetivos${res#$brain/}$OS_SEP"
done
objetivos="${objetivos}backlog.md${OS_SEP}"
for bl in "$brain/$new_name"/*/backlog.md; do
  [ -f "$bl" ] || continue
  objetivos="$objetivos${bl#$brain/}$OS_SEP"
done
objetivos="$objetivos${OS_MOUNTS_ARCHIVO:-mounts.md}$OS_SEP"

old_ifs="$IFS"
IFS="$OS_SEP"
for rel in $objetivos; do
  [ -n "$rel" ] || continue
  if rewrite_prefix "$brain/$rel"; then
    reescritos="$reescritos  $rel
"
    hubo_cambio=1
  fi
done
IFS="$old_ifs"

# Nada cambió: ni tree.md, ni la carpeta, ni ningún archivo de ruteo — es exactamente el estado
# final de una corrida anterior completa. Se dice y se termina, sin repetir el listado de (4): si
# nada se movió, nada nuevo hay para reportar ahí tampoco.
if [ "$hubo_cambio" = "0" ]; then
  printf '%s\n' "$S_WS_RENAME_NOTHING"
  exit 0
fi

if [ -n "$reescritos" ]; then
  printf '%s\n' "$S_WS_RENAME_REWROTE"
  printf '%s' "$reescritos"
fi

# ---------------------------------------------------------------- (4) lo que queda con el prefijo viejo
# Todo `.md` del brain, sin `.git`, sin `.os`, sin `.claude` (producto instalado, nunca dato del
# operador) — lo que este paso lista es siempre trabajo del operador que la reescritura de (3) no
# tocó a propósito: decisiones, contextos, iniciativas, cualquier prosa libre. El conteo es de
# `orgs/` como substring, sin el chequeo de contexto de arriba: acá no se reescribe nada, así que
# contar de más solo hace que el operador revise un archivo también a mano.
faltan=""
while IFS= read -r f || [ -n "$f" ]; do
  [ -n "$f" ] || continue
  n=$(grep -c "$pat" "$f" 2>/dev/null)
  n="${n:-0}"
  n=$(printf '%s' "$n" | tr -d ' \n')
  [ "$n" = "0" ] && continue
  faltan="$faltan  ${f#$brain/} ($n)
"
done <<LISTADO
$(find "$brain" -type d \( -name .git -o -name .os -o -name .claude \) -prune -o -type f -name '*.md' -print)
LISTADO

if [ -n "$faltan" ]; then
  printf '%s\n' "$S_WS_RENAME_LEFTOVER"
  printf '%s' "$faltan"
else
  printf '%s\n' "$S_WS_RENAME_NONE_LEFT"
fi

exit 0
