#!/usr/bin/env bash
# Deja el manual de usuario enganchado en la raíz del brain, en el idioma del operador (spec 022).
# Interno: no es invocable. Lo corre `bootstrap.sh` al crear el brain, y lo puede volver a correr
# cualquier sesión posterior — es lo que le da el manual a un brain creado antes de esta spec.
#
# Uso: manual-link.sh --brain DIR [--language en|es]
#
# **El enganche es un symlink al manual del producto, no una copia.** El manual se actualiza con el
# producto: una copia quedaría congelada en la versión del día de la instalación, que es el defecto
# que este producto ya declaró en sus learnings —una entrega que hay que reinstalar es una capacidad
# oscura—. Es el mismo criterio con el que viajan `CLAUDE.md`, `.os/core` y los agentes.
#
# El nombre del archivo depende del idioma (`os_manual_file`) y queda declarado en `tree.md` como
# `content:`: se ve en la raíz del brain, y ningún barrido lo lee como trabajo ni lo reporta como no
# alcanzado.
#
# Exit: 0 lo enganchó o ya estaba · 2 el brain no existe o el manual no está en el producto ·
#       3 hay un archivo propio del operador con ese nombre y no se pisa.

set -eu

here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"

brain=""
language=""

while [ $# -gt 0 ]; do
  case "$1" in
    --brain) brain="$2"; shift 2 ;;
    --language) language=$(os_lower "$2"); shift 2 ;;
    *) os_die "argumento desconocido: $1" ;;
  esac
done

[ -n "$brain" ] || os_die "falta --brain"
[ -d "$brain" ] || { printf 'error: no existe el brain: %s\n' "$brain" >&2; exit 2; }
# Ruta física: ver el comentario de bootstrap.sh.
brain=$(cd "$brain" && pwd -P)

if [ -z "$language" ]; then
  language=$(os_language "$brain")
elif ! os_language_valido "$language"; then
  os_die "idioma no soportado: $language — hoy: $OS_LANGUAGES"
fi

archivo=$(os_manual_file "$language")
origen="$here/../manual/$archivo"
if [ ! -f "$origen" ]; then
  printf 'error: el producto no trae el manual %s\n' "$archivo" >&2
  exit 2
fi
origen=$(cd "$(dirname "$origen")" && pwd -P)/$archivo
destino="$brain/$archivo"

# Destino real de un symlink, para comparar destinos y no cadenas de ruta — el mismo criterio que
# usa `install.sh` con `CLAUDE.md`.
resolver_link() {
  local link="$1" t d
  t=$(readlink "$link") || return 0
  case "$t" in
    /*) ;;
    *) t="$(dirname "$link")/$t" ;;
  esac
  d=$(cd "$(dirname "$t")" 2>/dev/null && pwd -P) || return 0
  [ -n "$d" ] || return 0
  printf '%s/%s' "$d" "$(basename "$t")"
}

estado=""
if [ -L "$destino" ]; then
  if [ "$(resolver_link "$destino")" = "$origen" ]; then
    estado="ya estaba"
  else
    # Un symlink colgado, o hacia otro checkout del producto, es re-instalación: se relinkea callado,
    # igual que `install.sh` con el contrato de sesión.
    ln -sfn "$origen" "$destino"
    estado="reenganchado"
  fi
elif [ -e "$destino" ]; then
  # Un archivo propio con ese nombre no se pisa: lo que el operador escribió no lo borra una
  # actualización del producto.
  printf 'error: %s ya existe y no es el manual de este producto — no se tocó nada\n' "$destino" >&2
  exit 3
else
  if ln -sfn "$origen" "$destino" 2>/dev/null; then
    estado="enganchado"
  else
    # Un filesystem sin symlinks (algunos montajes de red, algunas carpetas sincronizadas) deja el
    # manual igual, copiado, y lo dice: un manual copiado se queda en esta versión hasta la próxima
    # corrida de este script.
    cp "$origen" "$destino"
    estado="copiado (este filesystem no acepta symlinks): se queda en esta versión hasta volver a correr este script"
  fi
fi

# La declaración en el árbol va siempre, también cuando el manual ya estaba: un brain bootstrapeado
# antes de esta spec no tiene la línea, y sin ella el barrido reporta el manual como no alcanzado.
os_tree_ensure "$brain" "$archivo" content || true

printf 'manual: %s — %s\n' "$archivo" "$estado"

# El manual del otro idioma quedó de una configuración anterior: se declara, no se borra.
for otro in $OS_LANGUAGES; do
  [ "$otro" = "$language" ] && continue
  viejo=$(os_manual_file "$otro")
  [ "$viejo" = "$archivo" ] && continue
  if [ -e "$brain/$viejo" ] || [ -L "$brain/$viejo" ]; then
    printf 'aviso: %s quedó de un idioma anterior — sacarlo lo elige el operador\n' "$viejo" >&2
  fi
done
