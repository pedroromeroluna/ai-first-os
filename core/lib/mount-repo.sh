#!/usr/bin/env bash
# Parte determinística de `mount-repo`: monta un repo git como cuerpo de un nodo. La entrevista la
# conduce core/skills/mount-repo.md. Interno: no es invocable.
#
# Uso: mount-repo.sh --brain DIR --head RUTA --remote REMOTE [--clone-root RUTA]
#
#   --head        la cabeza, relativa al brain: `orgs/<slug>/initiatives/<nombre>.md`
#   --remote      lo que se escribe en `repo:` — el remote textual, nunca una ruta local
#   --clone-root  la raíz de clonado de esta máquina. Se pregunta una sola vez: si `mounts.md` ya la
#                 declara, esa gana y el argumento se ignora diciéndolo.
#
# Los tres actos son uno solo —decidir construir y montar el repo son el mismo acto—: `repo:` en la
# cabeza, el clon plano fuera del brain, y la fila remote -> ruta local en la tabla del entorno.
#
# Idempotente: montar dos veces el mismo remote no duplica la fila ni vuelve a clonar. Sobre una
# máquina nueva —la tabla no viaja— reconstruye el clon y la fila sin tocar la cabeza.
#
# Exit: 0 montó o ya estaba · 2 argumentos o cabeza inválidos · 3 el remote no responde
#       4 la cabeza ya declara otro `repo:` · 5 la raíz de clonado falta o es inválida
#
# Nada se escribe antes de que las cinco validaciones pasen: una negativa a mitad de camino deja el
# nodo montado a medias, que es peor que no montarlo.

set -u

here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"

brain=""
head_rel=""
remote=""
clone_root_arg=""

while [ $# -gt 0 ]; do
  case "$1" in
    --brain) brain="${2:-}"; shift 2 ;;
    --head) head_rel="${2:-}"; shift 2 ;;
    --remote) remote="${2:-}"; shift 2 ;;
    --clone-root) clone_root_arg="${2:-}"; shift 2 ;;
    *) os_die "argumento desconocido: $1" ;;
  esac
done

[ -n "$brain" ] || os_die "falta --brain"
[ -n "$head_rel" ] || os_die "falta --head"
[ -n "$remote" ] || os_die "falta --remote"
[ -d "$brain" ] || os_die "no existe el brain: $brain"
# `pwd -P`, acá y en la raíz de clonado: el guard anti-anidado compara las dos rutas como texto, y
# con una sola de las dos resuelta a físico un symlink en el medio lo evade — el clon termina adentro
# del brain o de otro repo, que es justo lo que la forma repo evita. Las dos mitades tienen que estar
# en el mismo sistema de coordenadas o la comparación no significa nada.
brain=$(cd "$brain" && pwd -P)

mounts="$brain/$OS_MOUNTS_ARCHIVO"

# ---------------------------------------------------------------- 1. la cabeza
# Relativa al brain, como todas las rutas del sistema. Una absoluta funciona en una sola máquina, y
# una que sube con `..` escribe fuera del árbol.
case "$head_rel" in
  /*) printf 'la cabeza se nombra relativa al brain: %s\n' "$head_rel" >&2; exit 2 ;;
  *..*) printf 'la cabeza no puede salir del brain: %s\n' "$head_rel" >&2; exit 2 ;;
esac
head_abs="$brain/$head_rel"
if [ ! -f "$head_abs" ]; then
  printf 'no existe la cabeza: %s\n' "$head_rel" >&2
  printf 'mount-repo monta un repo sobre una cabeza que ya existe; no la inventa.\n' >&2
  exit 2
fi

fm_read "$head_abs"
if [ -n "$fm_roto" ]; then
  printf '%s: %s — no se escribe sobre un frontmatter que no se entiende\n' "$head_rel" "$fm_roto" >&2
  exit 2
fi

# Un `repo:` distinto ya escrito es del operador: dos cuerpos para una cabeza no lo resuelve un
# script. Se frena antes de tocar nada.
if [ -n "$fm_repo" ] && [ "$fm_repo" != "$remote" ]; then
  printf 'conflicto: %s ya declara repo: %s\n' "$head_rel" "$fm_repo" >&2
  printf 'el remote pedido es %s. Cuál queda es del operador: no se escribió nada.\n' "$remote" >&2
  exit 4
fi

# ---------------------------------------------------------------- 2. el remote responde
# Si no responde, no hay nada que montar: negarse antes de escribir es más barato que dejar una
# cabeza apuntando a un remote que no existe.
if ! git ls-remote "$remote" > /dev/null 2>&1; then
  printf 'el remote no responde: %s\n' "$remote" >&2
  printf 'no se escribió nada.\n' >&2
  exit 3
fi

# ---------------------------------------------------------------- 3. la raíz de clonado
clone_root=$(os_mounts_clone_root "$mounts")
declarada=0
if [ -n "$clone_root" ]; then
  declarada=1
  if [ -n "$clone_root_arg" ] && [ "$clone_root_arg" != "$clone_root" ]; then
    printf 'la raíz de clonado ya estaba declarada: %s — se usa esa y se ignora --clone-root\n' \
      "$clone_root"
  fi
else
  clone_root="$clone_root_arg"
fi

if [ -z "$clone_root" ]; then
  printf 'falta la raíz de clonado: dónde viven los checkouts de esta máquina.\n' >&2
  printf 'Se pregunta una vez y queda escrita en %s. No hay default: no se escribió nada.\n' \
    "$OS_MOUNTS_ARCHIVO" >&2
  exit 5
fi

case "$clone_root" in
  /*) ;;
  *) printf 'la raíz de clonado es del entorno y va absoluta: %s\n' "$clone_root" >&2; exit 5 ;;
esac

# El cuerpo se clona plano y afuera: adentro del brain el brain deja de clonarse liviano, y adentro
# de otro repo aparecen repos anidados —gitlinks o submódulos—, que es el terreno que la forma repo
# evita. Se mira el ancestro existente más cercano: la raíz puede no existir todavía.
ancestro="$clone_root"
while [ ! -d "$ancestro" ]; do
  case "$ancestro" in
    */*) ancestro="${ancestro%/*}"; [ -n "$ancestro" ] || ancestro="/" ;;
    *) ancestro="/"; break ;;
  esac
done
ancestro=$(cd "$ancestro" && pwd -P)

case "$ancestro/" in
  "$brain"/*) printf 'la raíz de clonado cae adentro del brain: %s\n' "$clone_root" >&2
              printf 'el cuerpo se clona plano y afuera. No se escribió nada.\n' >&2
              exit 5 ;;
esac

dentro_de_repo=""
d="$ancestro"
while :; do
  [ -e "$d/.git" ] && dentro_de_repo="$d"
  [ "$d" = "/" ] && break
  d="${d%/*}"
  [ -n "$d" ] || d="/"
done
if [ -n "$dentro_de_repo" ]; then
  printf 'la raíz de clonado cae adentro de otro repo: %s\n' "$dentro_de_repo" >&2
  printf 'el cuerpo se clona plano, nunca anidado. No se escribió nada.\n' >&2
  exit 5
fi

# ---------------------------------------------------------------- 4. el destino
# El nombre del checkout sale del remote: es el mismo que usa `git clone` sin argumento de destino.
nombre="${remote%/}"
nombre="${nombre##*/}"
nombre="${nombre##*:}"
nombre="${nombre%.git}"
if [ -z "$nombre" ]; then
  printf 'no se pudo derivar el nombre del checkout desde el remote: %s\n' "$remote" >&2
  exit 2
fi
destino="$clone_root/$nombre"

# ---------------------------------------------------------------- 5. qué había ya montado
# Las filas del remote se juntan todas, no solo la última: una tabla con el mismo remote dos veces es
# ambigua, y elegir en silencio es la clase de barrido incompleto que el sistema prohíbe. Se usa la
# última —la más reciente— y se declara cuáles había.
fila_previa=""
filas_remote=""
n_filas=0
escanear_filas() {
  fila_previa=""
  filas_remote=""
  n_filas=0
  while IFS="$OS_SEP" read -r n r_remote r_ruta || [ -n "$n" ]; do
    [ -n "$n" ] || continue
    [ "$r_remote" = "$remote" ] || continue
    n_filas=$(( n_filas + 1 ))
    fila_previa="$n"
    [ -n "$filas_remote" ] && filas_remote="$filas_remote $n" || filas_remote="$n"
    [ -n "$r_ruta" ] && destino="$r_ruta"
  done <<FILAS
$(os_mounts_filas "$mounts")
FILAS
}

# lista_lineas "4 6 8" -> "línea 4, 6 y 8"
lista_lineas() {
  local acc="" x total=0 i=0
  for x in $1; do total=$(( total + 1 )); done
  for x in $1; do
    i=$(( i + 1 ))
    if [ "$i" = "1" ]; then acc="$x"
    elif [ "$i" = "$total" ]; then acc="$acc y $x"
    else acc="$acc, $x"; fi
  done
  printf 'línea %s' "$acc"
}

escanear_filas

clonado=0
if [ -d "$destino/.git" ]; then
  clonado=1
fi

# ---------------------------------------------------------------- los tres actos
printf 'Montaje\n'

# --- el clon
if [ "$clonado" = "1" ]; then
  printf '  checkout: ya estaba en %s — no se vuelve a clonar\n' "$destino"
else
  if [ -e "$destino" ]; then
    printf 'la ruta del checkout existe y no es un repo: %s\n' "$destino" >&2
    printf 'no se escribió nada.\n' >&2
    exit 5
  fi
  mkdir -p "$clone_root" || { printf 'no se pudo crear la raíz de clonado: %s\n' "$clone_root" >&2; exit 5; }
  if ! git clone --quiet "$remote" "$destino" > /dev/null 2>&1; then
    printf 'falló el clonado de %s en %s\n' "$remote" "$destino" >&2
    printf 'no se escribió nada.\n' >&2
    exit 3
  fi
  printf '  checkout: %s\n' "$destino"
fi

# --- `repo:` en la cabeza
# En una máquina nueva la cabeza ya lo tiene —viaja con el brain— y la tabla no: reconstruir el
# montaje no la toca.
if [ "$fm_repo" = "$remote" ]; then
  printf '  %s: repo: ya estaba\n' "$head_rel"
else
  if os_fm_set "$head_abs" repo "$remote"; then
    printf '  %s: repo: %s\n' "$head_rel" "$remote"
  else
    printf 'no se pudo escribir repo: en %s\n' "$head_rel" >&2
    exit 2
  fi
fi

# --- la fila de la tabla del entorno
nacio=0
if [ ! -f "$mounts" ]; then
  nacio=1
  {
    printf '# Montajes — el entorno de esta máquina\n\n'
    printf 'Remote -> ruta local. Es dato de esta máquina y **no viaja**: en una máquina nueva no\n'
    printf 'está, los barridos reportan el montaje como no alcanzado y `mount-repo` sobre el mismo\n'
    printf 'remote lo reconstruye. Lo escribe `mount-repo`.\n\n'
    printf 'clone-root: `%s`\n\n' "$clone_root"
    printf '| Remote | Ruta local |\n'
    printf '|---|---|\n'
  } > "$mounts"
fi

# La raíz de clonado se pregunta una vez y queda escrita — también cuando la tabla la escribió alguien
# a mano y le falta la línea. Sin esto, una tabla nacida a mano vuelve a pedirla en cada corrida, que
# es la pregunta repetida que la decisión evita. Se inserta antes de la primera fila, y las filas
# corren dos líneas: por eso se vuelve a escanear.
if [ "$nacio" = "0" ] && [ "$declarada" = "0" ]; then
  tmp_mounts="$mounts.os-tmp"
  : > "$tmp_mounts"
  puesto=0
  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$puesto" = "0" ]; then
      case "$line" in
        '|'*) printf 'clone-root: `%s`\n\n' "$clone_root" >> "$tmp_mounts"; puesto=1 ;;
      esac
    fi
    printf '%s\n' "$line" >> "$tmp_mounts"
  done < "$mounts"
  [ "$puesto" = "1" ] || printf 'clone-root: `%s`\n' "$clone_root" >> "$tmp_mounts"
  mv "$tmp_mounts" "$mounts"
  printf '  %s: clone-root: %s — la tabla no lo declaraba\n' "$OS_MOUNTS_ARCHIVO" "$clone_root"
  escanear_filas
fi

# Dos filas para el mismo remote no se resuelven en silencio: se usa la última y se dice cuáles había.
if [ "$n_filas" -gt 1 ]; then
  printf '  %s: %s filas: %s — se usa la última\n' \
    "$OS_MOUNTS_ARCHIVO" "$n_filas" "$(lista_lineas "$filas_remote")"
fi

if [ -n "$fila_previa" ]; then
  printf '  %s: la fila ya estaba (línea %s)\n' "$OS_MOUNTS_ARCHIVO" "$fila_previa"
else
  printf '| `%s` | `%s` |\n' "$remote" "$destino" >> "$mounts"
  printf '  %s: | `%s` | `%s` |\n' "$OS_MOUNTS_ARCHIVO" "$remote" "$destino"
fi
[ "$nacio" = "1" ] && printf '  %s nació con este dato\n' "$OS_MOUNTS_ARCHIVO"

# La tabla no viaja: la frontera es el gitignore del brain, y la escribe el comando que crea el
# archivo. Y como todo archivo de solo contenido, declara su altura: el `tree.md` del brain es una
# copia del template, así que agregar el glob al template no lo agrega a los brains ya bootstrapeados.
if os_gitignore_ensure "$brain" "$OS_MOUNTS_ARCHIVO"; then
  printf '  .gitignore — entrada declarada: %s\n' "$OS_MOUNTS_ARCHIVO"
fi
os_tree_ensure "$brain" "$OS_MOUNTS_ARCHIVO"
case "$?" in
  0) printf '  tree.md — glob declarado: %s\n' "$OS_MOUNTS_ARCHIVO" ;;
  2) printf '  falta tree.md — el glob "%s" quedó sin declarar\n' "$OS_MOUNTS_ARCHIVO" ;;
esac

exit 0
