#!/usr/bin/env bash
# Parte determinística de `rename-heads`: adopta la forma única de nodo —una carpeta con su
# `README.md` adentro— en un brain nacido antes de ella (spec 040). Interno: no es invocable.
#
# Uso: rename-heads.sh --brain DIR
#
# Corre solo a pedido del operador — nunca lo corre el instalador ni el arranque de sesión.
#
# **La forma la declara el árbol, y el árbol se reescribe último.** Mientras `tree.md` diga la forma
# anterior, una corrida cortada a la mitad sabe todavía cómo se llamaba la cabeza y termina sola en
# la siguiente. `os_head_file` (common.sh) es el único lector: devuelve el nombre de la cabeza de
# nodo y, en su código de salida, la forma —nueva, anterior, o un árbol que no declara ninguna
# cabeza, que este comando no puede migrar porque no sabe qué está mirando—.
#
# El orden:
#
#   1. La forma, de las dos alturas que declaran cabezas. Si las dos ya están en la forma nueva, no
#      hay nada que hacer y se dice. Si el árbol no declara ninguna cabeza, se dice que el layout no
#      se reconoce y se sale distinto de cero. Un brain a medio migrar —una altura en cada forma— no
#      es un error: es exactamente lo que este comando termina, migrando la que sigue en la forma
#      anterior.
#   2. El plan. Se arma la lista completa de movimientos —cabeza de cada espacio de trabajo y de
#      cada producto, cabeza de cada iniciativa, documentos fechados de `context/` a `research/`—
#      **antes de mover nada**. Cada par origen/destino cae en uno de cuatro casos: los dos existen
#      (conflicto: se lista y no se toca nada, ni un archivo — elegir cuál gana no es de un script);
#      solo el origen (se mueve); solo el destino (ya lo movió una corrida anterior: entra al mapa
#      de reescritura igual, que es lo que hace reanudable el paso 4); ninguno (nada).
#   3. Los movimientos, en el orden del plan. `git mv` en un brain git —así el índice lo registra
#      como rename— y `mv -n` si no; nunca uno que pise.
#   4. La reescritura de rutas. **Solo se reescribe un token que coincide exactamente con una ruta
#      que este comando movió**, o con esa misma ruta relativa al nodo dueño del archivo que se está
#      reescribiendo. Nunca por sufijo: una ruta con el mismo final que no es cabeza de nadie queda
#      intacta, igual que una URL que lleve la misma ruta adentro. Del token se separan y se
#      conservan el `#ancla`, el `:línea` del final y el `./` del principio; **un nombre pelado —sin
#      una sola barra— nunca se resuelve contra la carpeta del archivo**: el nombre de la cabeza
#      suelto en la prosa de un resolver es un archivo de otro repo, no una ruta de este brain.
#   5. El árbol.
#   6. Lo que quedó nombrando la forma anterior se lista, sin tocarlo.
#   7. No commitea: la sesión commitea después, como todo lo demás del brain.
#
# Límites conocidos, por diseño: una ruta con espacios adentro no se reescribe (el texto se parte en
# tokens por espacio), y se ve en el listado del paso 6. No reescribir es el modo seguro de fallar;
# corromper, no.
#
# Solo bash, carácter a carácter — nada de sed ni awk (E7, PATH restringido).
#
# Exit: 0 renombró, o no había nada que renombrar · 1 layout inválido (un destino ya existe) ·
#       2 el árbol no declara ninguna cabeza.
#
# Sin `set -e`: un fallo a mitad de la reescritura tiene que dejar ver qué quedó hecho.

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

nl=$(printf '\nx'); nl="${nl%x}"
nuevo="README.md"
wsdir=$(os_ws_dir "$brain")
forma=0
viejo=$(os_head_file "$brain") || forma=$?

# ---------------------------------------------------------------- (1) la forma
if [ "$forma" = "2" ]; then
  printf '%s\n' "$S_HEADS_RENAME_UNKNOWN" >&2
  exit 2
fi
if [ "$forma" = "0" ]; then
  printf '%s\n' "$S_HEADS_RENAME_NOTHING"
  exit 0
fi
# Con la altura del espacio de trabajo ya en la forma nueva —o sin declarar—, `os_head_file` imprime
# el nombre de nacimiento y no hay cabezas de nodo que mover: lo que queda por migrar es la otra
# altura.
[ "$viejo" = "$nuevo" ] && viejo=""

es_git=0
if git -C "$brain" rev-parse --is-inside-work-tree > /dev/null 2>&1; then es_git=1; fi

# ---------------------------------------------------------------- (2) el plan
# Un registro por movimiento: "origen<sep>destino". Nada se mueve hasta que el plan entero esté
# armado y sin conflictos.
plan=""
conflictos=""
mapa=""

plan_add() {
  # plan_add ORIGEN DESTINO — los dos relativos al brain. Los cuatro casos del encabezado.
  local hay_origen=0 hay_destino=0
  [ -e "$brain/$1" ] && hay_origen=1
  [ -e "$brain/$2" ] && hay_destino=1
  if [ "$hay_origen" = "1" ] && [ "$hay_destino" = "1" ]; then
    conflictos="$conflictos  $1 · $2$nl"
    return 0
  fi
  if [ "$hay_origen" = "1" ]; then
    plan="$plan$1$OS_SEP$2$nl"
    return 0
  fi
  # Ya movido —por una corrida anterior que se cortó—: no hay nada que mover, pero la ruta vieja
  # sigue siendo una ruta de cabeza de este brain y las referencias que la nombran hay que
  # reescribirlas igual.
  [ "$hay_destino" = "1" ] && mapa="$mapa$1$OS_SEP$2$nl"
  return 0
}

# las cabezas de nodo: cada espacio de trabajo y cada producto
if [ -n "$viejo" ]; then
  for d in "$brain/$wsdir"/*; do
    [ -d "$d" ] || continue
    rel="${d#$brain/}"
    plan_add "$rel/$viejo" "$rel/$nuevo"
    for p in "$d"/products/*; do
      [ -d "$p" ] || continue
      prel="${p#$brain/}"
      plan_add "$prel/$viejo" "$prel/$nuevo"
    done
  done
fi

# las carpetas de iniciativas del brain, relativas a él: la de la raíz y la de cada espacio de
# trabajo. Se arman con `$brain` adelante —un glob suelto se expande contra el cwd, no contra el
# brain— y se guardan relativas, que es como se nombran las rutas del sistema.
ini_dirs="initiatives"
for d in "$brain/$wsdir"/*; do
  [ -d "$d/initiatives" ] || continue
  ini_dirs="$ini_dirs$OS_SEP${d#$brain/}/initiatives"
done

old_ifs="$IFS"
IFS="$OS_SEP"
for dir in $ini_dirs; do
  IFS="$old_ifs"
  for f in "$brain/$dir"/*.md; do
    [ -f "$f" ] || continue
    slug="${f##*/}"; slug="${slug%.md}"
    plan_add "$dir/$slug.md" "$dir/$slug/$nuevo"
  done
  # las que una corrida anterior ya movió: la carpeta con su cabeza adentro y nada suelto al lado
  for f in "$brain/$dir"/*/"$nuevo"; do
    [ -f "$f" ] || continue
    slug="${f%/*}"; slug="${slug##*/}"
    [ -f "$brain/$dir/$slug.md" ] && continue
    plan_add "$dir/$slug.md" "$dir/$slug/$nuevo"
  done
  IFS="$OS_SEP"
done
IFS="$old_ifs"

# los documentos fechados de cada producto: `context/` queda con un solo sentido —la capa
# estratégica— y todo lo fechado vive en `research/`.
for p in "$brain/$wsdir"/*/products/*; do
  [ -d "$p/context" ] || continue
  prel="${p#$brain/}"
  for f in "$p/context"/*.md; do
    [ -f "$f" ] || continue
    fbase="${f##*/}"
    case "$fbase" in
      [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-*) ;;
      *) continue ;;
    esac
    plan_add "$prel/context/$fbase" "$prel/research/$fbase"
  done
done

# lo fechado que una corrida anterior ya movió
for p in "$brain/$wsdir"/*/products/*; do
  [ -d "$p/research" ] || continue
  prel="${p#$brain/}"
  for f in "$p/research"/*.md; do
    [ -f "$f" ] || continue
    fbase="${f##*/}"
    case "$fbase" in
      [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-*) ;;
      *) continue ;;
    esac
    [ -e "$p/context/$fbase" ] && continue
    plan_add "$prel/context/$fbase" "$prel/research/$fbase"
  done
done

if [ -n "$conflictos" ]; then
  printf '%s\n' "$S_HEADS_RENAME_BOTH" >&2
  printf '%s' "$conflictos" >&2
  exit 1
fi

# ---------------------------------------------------------------- (3) los movimientos
mover() {
  if [ "$es_git" = "1" ]; then
    git -C "$brain" mv "$1" "$2" > /dev/null 2>&1 && return 0
  fi
  mv -n "$brain/$1" "$brain/$2" || return 1
  [ -e "$brain/$1" ] && return 1
  return 0
}

movidas=""
fechados=""
hubo_cambio=0

while IFS= read -r registro || [ -n "$registro" ]; do
  [ -n "$registro" ] || continue
  origen="${registro%%$OS_SEP*}"
  destino="${registro#*$OS_SEP}"
  mkdir -p "$brain/${destino%/*}" || os_die "no se pudo crear ${destino%/*}"
  mover "$origen" "$destino" || os_die "no se pudo mover $origen a $destino"
  mapa="$mapa$origen$OS_SEP$destino$nl"
  case "$destino" in
    */research/*) fechados="$fechados  $origen -> $destino$nl" ;;
    *) movidas="$movidas  $origen -> $destino$nl" ;;
  esac
  hubo_cambio=1
done <<PLAN
$plan
PLAN

# ---------------------------------------------------------------- (4) la reescritura de rutas
# rt_lookup RUTA -> el destino de una ruta que este comando movió, por stdout. Exit 1 si esa ruta no
# está en el mapa: entonces el token no se toca. La coincidencia es exacta, nunca por sufijo.
rt_lookup() {
  local linea
  [ -n "$1" ] || return 1
  while IFS= read -r linea || [ -n "$linea" ]; do
    [ -n "$linea" ] || continue
    case "$linea" in
      "$1$OS_SEP"*) printf '%s' "${linea#*$OS_SEP}"; return 0 ;;
    esac
  done <<MAPA
$mapa
MAPA
  return 1
}

rt_out=""

rewrite_token() {
  # rewrite_token TOKEN DIR — DIR es la carpeta del archivo que se está reescribiendo, relativa al
  # brain, para resolver una referencia relativa al propio nodo.
  local tok="$1" dir="${2:-}" ruta="" ancla="" punto="" linea="" destino
  # Una URL —con esquema o con la forma `usuario@host:ruta`— no es una ruta de este brain.
  case "$tok" in
    *://*|*@*:*) rt_out="$rt_out$tok"; return 0 ;;
  esac
  ruta="$tok"
  # el ancla del final
  case "$ruta" in
    *'#'*) ancla="#${ruta#*#}"; ruta="${ruta%%#*}" ;;
  esac
  # el `:línea` del final, y el `:` suelto de una cita
  case "$ruta" in
    *:) linea=":"; ruta="${ruta%:}" ;;
    *:[0-9]) linea=":${ruta##*:}"; ruta="${ruta%:*}" ;;
    *:[0-9][0-9]|*:[0-9][0-9][0-9]|*:[0-9][0-9][0-9][0-9]) linea=":${ruta##*:}"; ruta="${ruta%:*}" ;;
  esac
  # el `./` del principio
  case "$ruta" in
    ./*) punto="./"; ruta="${ruta#./}" ;;
  esac
  if [ -n "$ruta" ]; then
    if destino=$(rt_lookup "$ruta"); then
      rt_out="$rt_out$punto$destino$linea$ancla"; return 0
    fi
    # Relativa al nodo dueño del archivo. Solo si el token es una ruta —tiene al menos una barra—:
    # un nombre pelado adentro de la carpeta de un nodo no es una referencia a la cabeza de ese
    # nodo, y resolverlo contra la carpeta reescribía prosa que hablaba de otro repo.
    case "$ruta" in
      */*)
        if [ -n "$dir" ] && destino=$(rt_lookup "$dir/$ruta"); then
          rt_out="$rt_out$punto${destino#$dir/}$linea$ancla"; return 0
        fi
        ;;
    esac
  fi
  rt_out="$rt_out$tok"
}

# rewrite_line LINEA DIR -> la línea con las rutas de cabeza reescritas, por stdout.
rewrite_line() {
  local line="$1" dir="${2:-}" i=0 len=${#1} c tok=""
  rt_out=""
  while [ "$i" -lt "$len" ]; do
    c="${line:$i:1}"
    case "$c" in
      ' '|$'\t'|'`'|'|'|'('|')'|'['|']'|'<'|'>'|'"'|"'"|','|';'|'!')
        rewrite_token "$tok" "$dir"; tok=""; rt_out="$rt_out$c" ;;
      *) tok="$tok$c" ;;
    esac
    i=$(( i + 1 ))
  done
  rewrite_token "$tok" "$dir"
  printf '%s' "$rt_out"
}

# rewrite_paths ARCHIVO_RELATIVO -> reescribe el archivo si alguna línea cambió; exit 0 si reescribió.
rewrite_paths() {
  local rel="$1" file="$brain/$1" dir tmp line nueva cambio=0
  [ -f "$file" ] || return 1
  case "$rel" in
    */*) dir="${rel%/*}" ;;
    *) dir="" ;;
  esac
  tmp="$file.os-tmp"
  : > "$tmp"
  while IFS= read -r line || [ -n "$line" ]; do
    nueva=$(rewrite_line "$line" "$dir")
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

objetivos="operator.md${OS_SEP}resolver.md${OS_SEP}backlog.md${OS_SEP}decisions.md${OS_SEP}learnings.md${OS_SEP}"
objetivos="$objetivos${OS_MOUNTS_ARCHIVO:-mounts.md}$OS_SEP"
for f in "$brain/initiatives"/*/"$nuevo" \
         "$brain/$wsdir"/*/resolver.md "$brain/$wsdir"/*/backlog.md \
         "$brain/$wsdir"/*/decisions.md "$brain/$wsdir"/*/learnings.md \
         "$brain/$wsdir"/*/"$nuevo" \
         "$brain/$wsdir"/*/initiatives/*/"$nuevo" \
         "$brain/$wsdir"/*/products/*/resolver.md "$brain/$wsdir"/*/products/*/decisions.md \
         "$brain/$wsdir"/*/products/*/"$nuevo"; do
  [ -f "$f" ] || continue
  objetivos="$objetivos${f#$brain/}$OS_SEP"
done

reescritos=""
old_ifs="$IFS"
IFS="$OS_SEP"
for rel in $objetivos; do
  IFS="$old_ifs"
  if [ -n "$rel" ] && rewrite_paths "$rel"; then
    reescritos="$reescritos  $rel$nl"
    hubo_cambio=1
  fi
  IFS="$OS_SEP"
done
IFS="$old_ifs"

# ---------------------------------------------------------------- (5) el árbol, último
tree_tmp="$brain/tree.md.os-tmp"
if [ -f "$brain/tree.md" ]; then
  cambio_tree=0
  : > "$tree_tmp"
  while IFS= read -r line || [ -n "$line" ]; do
    nueva="$line"
    case "$line" in
      "glob: initiatives/*.md") nueva="glob: initiatives/*/$nuevo" ;;
      "glob: $wsdir/*/initiatives/*.md") nueva="glob: $wsdir/*/initiatives/*/$nuevo" ;;
      *)
        if [ -n "$viejo" ]; then
          case "$line" in
            "glob: "*"/$viejo") nueva="${line%/*}/$nuevo" ;;
          esac
        fi
        ;;
    esac
    [ "$nueva" = "$line" ] || cambio_tree=1
    printf '%s\n' "$nueva"
  done < "$brain/tree.md" >> "$tree_tmp"
  if [ "$cambio_tree" = "1" ]; then
    mv "$tree_tmp" "$brain/tree.md"
    reescritos="$reescritos  tree.md$nl"
    hubo_cambio=1
  else
    rm -f "$tree_tmp"
  fi
fi

# Las líneas de contenido de la forma nueva: el cuerpo de una iniciativa al lado de su cabeza, y los
# documentos fechados de un producto. Sin ellas, lo que ya vive ahí aparece como no alcanzado.
os_tree_ensure "$brain" "initiatives/*/*.md" content > /dev/null || true
os_tree_ensure "$brain" "$wsdir/*/initiatives/*/*.md" content > /dev/null || true
os_tree_ensure "$brain" "$wsdir/*/products/*/research/*.md" content > /dev/null || true

# ---------------------------------------------------------------- nada que hacer
if [ "$hubo_cambio" = "0" ]; then
  printf '%s\n' "$S_HEADS_RENAME_NOTHING"
  exit 0
fi

if [ -n "$movidas" ]; then
  printf '%s\n' "$S_HEADS_RENAME_MOVED"
  printf '%s' "$movidas"
fi
if [ -n "$fechados" ]; then
  printf '%s\n' "$S_HEADS_RENAME_RESEARCH"
  printf '%s' "$fechados"
fi
if [ -n "$reescritos" ]; then
  printf '%s\n' "$S_HEADS_RENAME_REWROTE"
  printf '%s' "$reescritos"
fi

# ---------------------------------------------------------------- (6) lo que quedó en la forma vieja
# Todo `.md` del brain, sin `.git`, sin `.os`, sin `.claude`. Lo que este paso lista es siempre
# trabajo del operador que la reescritura de (4) no tocó a propósito: prosa libre, decisiones,
# cualquier cita que no coincida exactamente con una ruta movida —una ruta con espacios adentro
# entra acá—. El operador decide.
patrones=""
[ -n "$viejo" ] && patrones="-e $viejo"
while IFS= read -r registro || [ -n "$registro" ]; do
  [ -n "$registro" ] || continue
  patrones="$patrones -e ${registro%%$OS_SEP*}"
done <<MAPA
$mapa
MAPA

faltan=""
if [ -n "$patrones" ]; then
  while IFS= read -r f || [ -n "$f" ]; do
    [ -n "$f" ] || continue
    n=$(grep -c -F $patrones "$f" 2>/dev/null)
    n="${n:-0}"
    n=$(printf '%s' "$n" | tr -d ' \n')
    [ "$n" = "0" ] && continue
    faltan="$faltan  ${f#$brain/} ($n)$nl"
  done <<LISTADO
$(find "$brain" -type d \( -name .git -o -name .os -o -name .claude \) -prune -o -type f -name '*.md' -print)
LISTADO
fi

if [ -n "$faltan" ]; then
  printf '%s\n' "$S_HEADS_RENAME_LEFTOVER"
  printf '%s' "$faltan"
else
  printf '%s\n' "$S_HEADS_RENAME_NONE_LEFT"
fi

exit 0
