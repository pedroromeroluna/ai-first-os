#!/usr/bin/env bash
# El check-resolvable de la raíz: audita que ninguna herramienta quede oscura. Interno: no es
# invocable — el invocable es `skills/check-resolvable.md`.
#
# Uso: check-resolvable.sh --brain DIR
#
# Tres direcciones, porque son tres errores distintos:
#
#   capacidad oscura      la herramienta está instalada y ninguna fila la alcanza
#   eslabón roto          un handoff nombra una capacidad que ninguna fila provee
#   ilusión de capacidad  una fila apunta a una herramienta que no existe
#
# Cada hallazgo se reporta con archivo y fila.
#
# Exit: 1 si encontró algo, 0 si no. Es lo que un cron necesita para avisar.
#
# El de la raíz mira `tarea → herramienta`; el del nodo —`contenido → dónde`— corre en el arranque
# de sesión y es otro chequeo.

set -u

here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"

nl=$(printf '\nx')
nl="${nl%x}"

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

# Los orígenes del resolver de la raíz, en orden de lectura. Soportar un origen más es agregar
# una entrada acá, no cambiar código. El del operador va último: sus filas ganan.
#
# Dos globs de pack, porque hay dos formas de tener un pack instalado:
#   `.os/packs/*/resolver.md`                 el pack enganchado por symlink desde el producto (017)
#   `.claude/skills/*-resolver/SKILL.md`      el pack bajado por el CLI de skills.sh (026)
# Un glob que no matchea no aporta filas: un brain sin ningún pack audita exactamente igual que
# antes. El orden de lectura completo se enuncia en `core/CLAUDE.md`, no acá.
RESOLVERS=".os/core/resolver.md .os/packs/*/resolver.md .claude/skills/*-resolver/SKILL.md resolver.md"

hallazgos=""
n_hallazgos=0
push() {
  n_hallazgos=$(( n_hallazgos + 1 ))
  hallazgos="$hallazgos  $1$nl"
}

# ---------------------------------------------------------------- las filas de la raíz
# Una fila es `| Capacidad | Herramienta | Ruta |`: la herramienta y la ruta van entre backticks, y
# eso es lo que se lee. La cabecera y la línea de guiones no traen backticks, así que se caen solas.
filas=""          # capacidad-en-minúsculas por línea
herramientas=""   # nombre de herramienta por línea
n_filas=0

for pat in $RESOLVERS; do
 for file in "$brain"/$pat; do
  [ -f "$file" ] || continue
  rel="${file#$brain/}"
  n=0
  while IFS= read -r line || [ -n "$line" ]; do
    n=$(( n + 1 ))
    case "$line" in
      '|'*) ;;
      *) continue ;;
    esac
    tool=""
    ruta=""
    i=0
    while IFS= read -r tok; do
      i=$(( i + 1 ))
      [ "$i" = "1" ] && tool="$tok"
      [ "$i" = "2" ] && ruta="$tok"
    done <<CELDAS
$(os_backticks "$line")
CELDAS
    [ -n "$tool" ] || continue
    cap="${line#|}"
    cap=$(os_trim "${cap%%|*}")
    [ -n "$cap" ] || continue
    n_filas=$(( n_filas + 1 ))
    filas="$filas$(os_lower "$cap")$nl"
    herramientas="$herramientas$tool$nl"
    if [ -z "$ruta" ]; then
      push "$rel:$n — ilusión de capacidad: la fila \"$cap\" no declara ruta"
    elif [ ! -e "$brain/$ruta" ]; then
      push "$rel:$n — ilusión de capacidad: no existe $ruta"
    fi
  done < "$file"
 done
done

tiene_fila_para_herramienta() {
  case "$nl$herramientas" in
    *"$nl$1$nl"*) return 0 ;;
  esac
  return 1
}

tiene_fila_para_capacidad() {
  case "$nl$filas" in
    *"$nl$(os_lower "$1")$nl"*) return 0 ;;
  esac
  return 1
}

# ---------------------------------------------------------------- lo instalado
# Un invocable se declara con `command:` en primera columna; un handoff nombra la capacidad que hace
# falta con `handoff:`, en primera columna también. Las dos marcas son un grep, que es lo que vuelve
# verificable el grafo entero.
n_tools=0
n_handoffs=0

while IFS= read -r f || [ -n "$f" ]; do
  [ -n "$f" ] || continue
  rel="${f#$brain/}"

  marca=$(grep -n -E '^(# )?command:' "$f" | head -1)
  if [ -n "$marca" ]; then
    linea="${marca%%:*}"
    value="${marca#*:}"
    value="${value#\# }"
    value="${value#command:}"
    value=$(os_trim "$value")
    n_tools=$(( n_tools + 1 ))
    if ! tiene_fila_para_herramienta "$value"; then
      push "$rel:$linea — capacidad oscura: nada rutea a \"$value\""
    fi
  fi

  while IFS= read -r hl || [ -n "$hl" ]; do
    [ -n "$hl" ] || continue
    linea="${hl%%:*}"
    cap="${hl#*handoff:}"
    cap=$(os_trim "$cap")
    [ -n "$cap" ] || continue
    n_handoffs=$(( n_handoffs + 1 ))
    if ! tiene_fila_para_capacidad "$cap"; then
      push "$rel:$linea — eslabón roto: ninguna fila provee \"$cap\""
    fi
  done <<HANDOFFS
$(grep -n -E '^(# )?handoff:' "$f")
HANDOFFS
done <<INSTALADO
$(find -L "$brain/.os" -type f -print 2>/dev/null | sort)
INSTALADO

# ---------------------------------------------------------------- salida
printf 'check-resolvable — raíz\n'
if [ "$n_hallazgos" = "0" ]; then
  # Sin herramientas y sin filas no hay grafo que auditar. "Sin hallazgos" ahí es un verde que un
  # cron lee como sistema sano, cuando lo que hay es un brain sin el producto instalado.
  if [ "$n_tools" = "0" ] && [ "$n_filas" = "0" ]; then
    printf '  nada instalado que auditar: el brain no tiene herramientas ni filas de resolver en la raíz\n'
    exit 0
  fi
  printf '  sin hallazgos: %s herramientas con fila · %s capacidades de handoff con proveedor · %s filas que alcanzan su herramienta\n' \
    "$n_tools" "$n_handoffs" "$n_filas"
  exit 0
fi
printf '%s' "$hallazgos"
printf '  %s hallazgos sobre %s herramientas, %s handoffs y %s filas\n' \
  "$n_hallazgos" "$n_tools" "$n_handoffs" "$n_filas"
exit 1
