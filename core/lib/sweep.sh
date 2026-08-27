#!/usr/bin/env bash
# Barrido global con tres modos. Interno: no es invocable — el invocable es `skills/sweep.md`.
#
# Uso: sweep.sh --brain DIR --mode pending|blocked|roadmap [--mounts ARCHIVO]
#
#   pending   las cabezas activas, una línea por cabeza, agrupadas por organización
#   blocked   las que tienen `blocked`, `waiting_on` o `depends_on` sin cerrar, con el porqué
#   roadmap   agrupado por `horizon`, con las dependencias cross-nodo visibles
#
# No tiene ámbito propio: siempre es global. El trabajo de la raíz (spec 018) entra al mismo
# recorrido, agrupado bajo `OS_ROOT_LABEL` — la misma tabla, sin sección nueva.
#
# Lee el frontmatter de cada cabeza y nunca abre un cuerpo. El recorrido son los globs de `tree.md`
# más los montajes de la tabla del entorno —`mounts.md` de la raíz del brain, que se lee sola:
# `--mounts` es override—; un montaje declarado sin checkout local se reporta como no alcanzado,
# nunca se omite, y sin tabla el barrido lo declara y sigue con el brain.
#
# Lo que no se pudo clasificar —sin `status`, sin `horizon`, frontmatter ilegible— se declara. Un
# barrido incompleto presentado como completo es peor que uno latente: nada le avisa al operador.
#
# Exit: 0 siempre que los argumentos sean válidos. Un barrido avisa, no bloquea.
#
# Sin `set -e` a propósito: un chequeo que falla no puede vaciar el resto del barrido.

set -u

here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"

t_inicio=$(os_now_ms)

# Los archivos propios de un nodo organización viven en common.sh (`OS_ORG_PROPIOS`). Todo lo demás
# que un glob alcance adentro de la carpeta de espacios de trabajo es una cabeza de iniciativa, a
# cualquier profundidad.

# Los estados terminales viven en common.sh: `os_cerrado`. Un estado terminal saca la cabeza de
# "pendiente" y cierra una dependencia que la nombre.
nl=$(printf '\nx')
nl="${nl%x}"
sep="$OS_SEP"

brain=""
mode=""
mounts=""
while [ $# -gt 0 ]; do
  case "$1" in
    --brain) brain="${2:-}"; shift 2 ;;
    --mode) mode="${2:-}"; shift 2 ;;
    --mounts) mounts="${2:-}"; shift 2 ;;
    *) os_die "argumento desconocido: $1" ;;
  esac
done

[ -n "$brain" ] || os_die "falta --brain"
[ -n "$mode" ] || os_die "falta --mode: pending, blocked o roadmap"
[ -d "$brain" ] || os_die "no existe el brain: $brain"
brain=$(cd "$brain" && pwd)

# Layout inválido frena acá, antes de cualquier $(...) que arme una ruta con el nombre de la
# carpeta (P2, spec 039).
os_ws_check "$brain"
wsdir=$(os_ws_dir "$brain")
# La forma de la cabeza, leída del árbol una sola vez (spec 040).
head=$(os_head_file "$brain") || true
org_propios=$(os_org_propios "$brain")

# Los tipos de nodo de memoria declarados en el árbol (spec 041): `products` fue el primero y ya no
# vive escrito a mano acá — cualquier carpeta hermana declarada con sus 3 líneas glob entra igual.
# Calculado una sola vez, antes del recorrido más abajo.
memory_types_org=$(os_memory_types "$brain" org) || memory_types_org=""
memory_types_root=$(os_memory_types "$brain" root) || memory_types_root=""

# Only the Checks title and its empty message go through the catalog (spec 033), reusing
# `session-start.sh`'s keys — the rest of this sweep stays in Spanish: the spec did not ask for it.
os_lang_load "$(os_language "$brain")" > /dev/null 2>&1

case "$mode" in
  pending|blocked|roadmap) ;;
  *) os_die "modo desconocido: $mode — pending, blocked o roadmap" ;;
esac

# ---------------------------------------------------------------- acumuladores
s_chequeos=""
push_chequeo() { s_chequeos="$s_chequeos  $1$nl"; }

leidos=0

# ---------------------------------------------------------------- el recorrido
# Los globs del brain, más los montajes. Cada entrada del recorrido es "raíz|ruta relativa": la raíz
# es el brain o el checkout de un montaje, y el grupo se nombra por su slug.
#
# El recorrido se arma solo con `os_tree_files` — la clase `glob:`. Las líneas `content:` (spec 007,
# lector `os_tree_content_files` en common.sh) quedan afuera sin que este script las filtre: nunca
# entran a `recorrido`, así que un archivo de contenido nunca se cuenta ni se clasifica acá. No hace
# falta un chequeo de "fuera del árbol" para el contenido en este barrido porque este barrido no
# tiene ese chequeo para ningún archivo — es de session-start.sh.
recorrido=""
if matches=$(os_tree_files "$brain"); then
  while IFS= read -r f || [ -n "$f" ]; do
    [ -n "$f" ] || continue
    recorrido="$recorrido$brain$sep$f$nl"
  done <<GLOBS
$matches
GLOBS
else
  push_chequeo "falta tree.md — el barrido no sabe qué rutas recorrer"
fi

# La tabla del entorno: `mounts.md` en la raíz del brain, una fila por montaje. Es dato de la
# máquina, no del producto, y la escribe `mount-repo`. El barrido solo la lee, y la lee por default:
# `--mounts` es override. El formato vive en common.sh, que es donde lo escribe quien la crea.
#
# Los tres casos se distinguen porque no son el mismo error: no haber tabla es un brain sin nodos
# compartidos; una declarada que no existe es una ruta mal escrita, y decirle "sin tabla" deja al
# operador creyendo que barrió todo. La fila que no se puede parsear se declara, nunca se saltea.
declarada=1
if [ -z "$mounts" ]; then
  declarada=0
  mounts="$brain/$OS_MOUNTS_ARCHIVO"
fi

if [ ! -f "$mounts" ]; then
  if [ "$declarada" = "1" ]; then
    push_chequeo "tabla declarada no encontrada: $mounts — el barrido cubre solo el brain"
  else
    push_chequeo "sin tabla del entorno: el barrido cubre solo el brain"
  fi
else
  tabla="${mounts##*/}"
  while IFS="$sep" read -r n remote ruta || [ -n "$n" ]; do
    [ -n "$n" ] || continue
    if [ -z "$remote" ] || [ -z "$ruta" ]; then
      push_chequeo "fila ilegible: $tabla:$n — no se pudo leer el montaje"
      continue
    fi
    if [ ! -d "$ruta" ]; then
      push_chequeo "montaje no alcanzado: $remote — declarado en $tabla:$n, sin checkout local"
      continue
    fi
    ruta=$(cd "$ruta" && pwd)
    if m2=$(os_tree_files "$ruta"); then
      while IFS= read -r f || [ -n "$f" ]; do
        [ -n "$f" ] || continue
        recorrido="$recorrido$ruta$sep$f$nl"
      done <<GLOBS2
$m2
GLOBS2
    fi
  done <<FILAS
$(os_mounts_filas "$mounts")
FILAS
fi

# ---------------------------------------------------------------- las cabezas
# Un registro por cabeza, leído una sola vez. Clasificar después sobre los registros evita releer
# un archivo para resolver una dependencia que lo nombra.
registros=""
indice=""

# El trabajo propio de la raíz (spec 018) entra al mismo recorrido, con `OS_ROOT_LABEL` como grupo:
# una etiqueta que nunca puede ser un slug real de la carpeta de espacios de trabajo (ver el
# comentario de la constante en common.sh). Antes de la 018 todo lo que no empezaba con el prefijo
# de esa carpeta quedaba afuera sin excepción — con un brain sin archivos de nodo en la raíz esa
# rama nunca matchea, así que la salida no cambia.
while IFS= read -r linea || [ -n "$linea" ]; do
  [ -n "$linea" ] || continue
  raiz="${linea%%$sep*}"
  f="${linea#*$sep}"
  base="${f##*/}"
  case "$f" in
    "$wsdir"/*)
      resto="${f#$wsdir/}"
      case "$resto" in
        */*) ;;
        *) continue ;;
      esac
      org="${resto%%/*}"
      propio=0
      # Mismo criterio que `session-start.sh`: el nombre propio solo cuenta a la altura directa de
      # la organización — una subcarpeta (`products/<slug>/<cabeza>`) puede compartir basename con
      # un canónico sin serlo (Q-12 del nodo de producto).
      resto2="${resto#$org/}"
      case "$resto2" in
        */*) ;;
        *) for p in $org_propios; do [ "$resto2" = "$p" ] && propio=1; done ;;
      esac
      [ "$propio" = "1" ] && continue
      ;;
    *)
      [ "$raiz" = "$brain" ] || continue
      propio=0
      for p in $OS_ROOT_PROPIOS; do
        [ "$base" = "$p" ] && propio=1
      done
      [ "$propio" = "1" ] && continue
      org="$OS_ROOT_LABEL"
      ;;
  esac

  nombre=$(os_node_name "$f")
  fm_read "$raiz/$f"
  leidos=$(( leidos + 1 ))
  # Un nodo de memoria es memoria, no estado (spec 036, generalizado por la 041 a cualquier tipo
  # declarado, no solo `products`): cuenta para el total de nodos —ya sumado arriba— pero no entra a
  # ninguna clasificación. No tiene `status`/`horizon` que reportar, y tratarlo como "sin status"
  # sería ruido fijo en cada corrida, nunca un hallazgo real.
  if os_memory_own_file "$wsdir" "$head" "$memory_types_org" "$memory_types_root" "$f"; then
    continue
  fi
  registros="$registros$org$sep$nombre$sep$fm_status$sep$fm_horizon$sep$fm_waiting_on$sep$fm_blocked$sep$fm_depends_on$sep$fm_roto$nl"
  [ -n "$fm_roto" ] || indice="$indice$org#$nombre=$fm_status$nl"
done <<RECORRIDO
$recorrido
RECORRIDO

# dep_estado REF -> el estado de la cabeza que la referencia nombra, o "no alcanzado".
# La referencia sigue la convención `ámbito#nombre` que ya usa `depends_on`. Si el ámbito no es una
# organización del recorrido —un repo, otro brain—, el barrido lo dice en vez de darla por cerrada.
dep_estado() {
  local ref="$1" idx="$nl$indice" resto
  case "$idx" in
    *"$nl$ref="*)
      resto="${idx#*$nl$ref=}"
      printf '%s' "${resto%%$nl*}"
      ;;
    *) printf 'no alcanzado' ;;
  esac
  return 0
}

# deps_abiertas VALOR -> las referencias sin cerrar, con su estado entre paréntesis.
deps_abiertas() {
  local v="$1" ref estado salida=""
  v="${v#[}"
  v="${v%]}"
  v="${v//,/ }"
  for ref in $v; do
    [ -n "$ref" ] || continue
    estado=$(dep_estado "$ref")
    if [ "$estado" != "no alcanzado" ] && os_cerrado "$estado"; then continue; fi
    [ -n "$estado" ] || estado="sin estado"
    [ -n "$salida" ] && salida="$salida, $ref ($estado)" || salida="$ref ($estado)"
  done
  printf '%s' "$salida"
}

# ---------------------------------------------------------------- clasificación por modo
grupos=""      # "clave<sep>línea" por cada fila que entra al reporte
sin_clasificar=""

registrar_grupo() { grupos="$grupos$1$sep$2$nl"; }

while IFS="$sep" read -r org nombre status horizon waiting blocked deps roto || [ -n "$org" ]; do
  [ -n "$org" ] || continue

  if [ -n "$roto" ]; then
    sin_clasificar="$sin_clasificar  $org/$nombre ($roto)$nl"
    continue
  fi

  # Un `status:` fuera del vocabulario del esquema no se interpreta: se declara. Tratarlo como
  # abierto deja la cabeza en la lista para siempre; tratarlo como cerrado la desaparece.
  if [ -n "$status" ] && ! os_estado_valido "$status"; then
    sin_clasificar="$sin_clasificar  $org/$nombre (estado desconocido: $status)$nl"
    continue
  fi

  abiertas=""
  [ -n "$deps" ] && abiertas=$(deps_abiertas "$deps")

  case "$mode" in
    pending)
      if [ -z "$status" ]; then
        sin_clasificar="$sin_clasificar  $org/$nombre (sin status)$nl"
        continue
      fi
      os_cerrado "$status" && continue
      registrar_grupo "$org" "$nombre · ${horizon:-sin horizonte} · $status"
      ;;

    blocked)
      motivo=""
      [ -n "$blocked" ] && motivo="trabada: $blocked"
      if [ -z "$motivo" ] && [ "$status" = "blocked" ]; then motivo="trabada"; fi
      if [ -n "$waiting" ]; then
        [ -n "$motivo" ] && motivo="$motivo · espera a $waiting" || motivo="espera a $waiting"
      fi
      if [ -n "$abiertas" ]; then
        [ -n "$motivo" ] && motivo="$motivo · depende de $abiertas" || motivo="depende de $abiertas"
      fi
      if [ -z "$motivo" ]; then
        # Sin señal y sin estado no se puede afirmar que no esté trabada: se declara.
        [ -n "$status" ] || sin_clasificar="$sin_clasificar  $org/$nombre (sin status)$nl"
        continue
      fi
      os_cerrado "$status" && continue
      registrar_grupo "$org" "$nombre · $motivo"
      ;;

    roadmap)
      if [ -z "$horizon" ]; then
        sin_clasificar="$sin_clasificar  $org/$nombre (sin horizon)$nl"
        continue
      fi
      os_cerrado "$status" && continue
      linea="$org/$nombre"
      [ -n "$abiertas" ] && linea="$linea · depende de $abiertas"
      registrar_grupo "$horizon" "$linea"
      ;;
  esac
done <<REGISTROS
$registros
REGISTROS

# ---------------------------------------------------------------- salida
case "$mode" in
  pending) printf 'Pendiente\n' ;;
  blocked) printf 'Trabado\n' ;;
  roadmap) printf 'Roadmap\n' ;;
esac

# El orden de los grupos: los horizontes en su orden de tiempo y el resto alfabético, para que dos
# corridas sobre el mismo brain devuelvan lo mismo.
claves=""
while IFS="$sep" read -r clave linea || [ -n "$clave" ]; do
  [ -n "$clave" ] || continue
  case "$nl$claves" in
    *"$nl$clave$nl"*) ;;
    *) claves="$claves$clave$nl" ;;
  esac
done <<GRUPOS
$grupos
GRUPOS

orden=""
if [ "$mode" = "roadmap" ]; then
  for h in now next later; do
    case "$nl$claves" in
      *"$nl$h$nl"*) orden="$orden$h$nl" ;;
    esac
  done
  while IFS= read -r clave || [ -n "$clave" ]; do
    [ -n "$clave" ] || continue
    case "$clave" in
      now|next|later) continue ;;
    esac
    orden="$orden$clave$nl"
  done <<CLAVES
$(printf '%s' "$claves" | sort)
CLAVES
else
  orden=$(printf '%s' "$claves" | sort)
  [ -n "$orden" ] && orden="$orden$nl"
fi

if [ -z "$orden" ]; then
  case "$mode" in
    pending) printf '  nada pendiente\n' ;;
    blocked) printf '  nada trabado\n' ;;
    roadmap) printf '  ninguna cabeza con horizonte\n' ;;
  esac
else
  while IFS= read -r clave || [ -n "$clave" ]; do
    [ -n "$clave" ] || continue
    printf '%s\n' "$clave"
    while IFS="$sep" read -r c linea || [ -n "$c" ]; do
      [ "$c" = "$clave" ] || continue
      printf '  %s\n' "$linea"
    done <<GRUPOS2
$grupos
GRUPOS2
  done <<ORDEN
$orden
ORDEN
fi

printf '\nSin clasificar\n'
if [ -z "$sin_clasificar" ]; then
  printf '  nada sin clasificar\n'
else
  printf '%s' "$sin_clasificar"
fi

printf '\n%s\n' "$S_SESSION_CHECKS_TITLE"
if [ -z "$s_chequeos" ]; then
  printf '  %s\n' "$S_SESSION_CHECKS_EMPTY"
else
  printf '%s' "$s_chequeos"
fi

t_fin=$(os_now_ms)
printf '%s nodos · %s\n' "$leidos" "$(os_elapsed "$t_inicio" "$t_fin")"
exit 0
