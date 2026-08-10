#!/usr/bin/env bash
# Barrido de arranque de sesión sobre una organización. Interno: no es invocable — lo dispara el
# contrato de sesión (core/CLAUDE.md) antes de que el modelo conteste el primer mensaje.
#
# Uso: session-start.sh --brain DIR --org SLUG [--mounts ARCHIVO]
#
# Lee el frontmatter de cada cabeza y los archivos que se cargan siempre. Nunca abre el cuerpo de
# una iniciativa: al `---` de cierre deja de leer. El recorrido son los globs de `tree.md` más las
# cabezas de esta organización que vivan en un montaje: la tabla del entorno se lee sola desde la
# raíz del brain y `--mounts` es override.
#
# La salida son cuatro secciones fijas, siempre las cuatro, con vacío explícito, y una última línea
# con el conteo de nodos y el tiempo. Cada sección tiene tope propio y declara lo que no entró: con
# 12 o con 40 iniciativas la salida mide lo mismo.
#
# Exit: 0 siempre que la organización exista — un chequeo avisa y no bloquea. 2 si no existe.
#
# Sin `set -e` a propósito: un chequeo que falla no puede abortar el arranque de una sesión.

set -u

here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"

t_inicio=$(os_now_ms)

# Topes por sección. La suma acotada es lo que sostiene el costo O(1) al modelo.
CAP_ESPERA=5
CAP_CURSO=10
CAP_CHEQUEOS=6
CAP_NOMBRES=3

# Los archivos propios del nodo organización viven en common.sh (`OS_ORG_PROPIOS`): los comparten
# este arranque y los barridos globales.

nl=$(printf '\nx')
nl="${nl%x}"
sep="$OS_SEP"

brain=""
org=""
mounts=""
while [ $# -gt 0 ]; do
  case "$1" in
    --brain) brain="${2:-}"; shift 2 ;;
    --org) org="${2:-}"; shift 2 ;;
    --mounts) mounts="${2:-}"; shift 2 ;;
    *) os_die "argumento desconocido: $1" ;;
  esac
done

[ -n "$brain" ] || os_die "falta --brain"
[ -n "$org" ] || os_die "falta --org"
[ -d "$brain" ] || os_die "no existe el brain: $brain"
brain=$(cd "$brain" && pwd)

# ---------------------------------------------------------------- el ámbito se valida contra el listado
# El slug se compara byte a byte contra los nombres reales de `orgs/`, nunca con `-d`. Un test de
# directorio acepta lo que el filesystem acepte: en un FS que no distingue mayúsculas `--org Acme`
# pasa y después no matchea contra el slug `acme`, y `--org ../..` sale del árbol. Las dos formas
# devolvían las cuatro secciones vacías con exit 0 — un barrido vacío que se lee como un brain vacío.
# El script no adivina el ámbito: lista lo que hay y devuelve el control. La skill pregunta con eso.
org_existe=0
org_slugs=""
while IFS= read -r slug || [ -n "$slug" ]; do
  [ -n "$slug" ] || continue
  org_slugs="$org_slugs  $slug$nl"
  if [ "$slug" = "$org" ]; then org_existe=1; fi
done <<SLUGS
$(os_org_slugs "$brain")
SLUGS
if [ "$org_existe" = "0" ]; then
  printf 'la organización "%s" no existe. Las que hay:\n' "$org" >&2
  if [ -n "$org_slugs" ]; then
    printf '%s' "$org_slugs" >&2
  else
    printf '  (ninguna)\n' >&2
  fi
  exit 2
fi

# ---------------------------------------------------------------- acumuladores
s_espera=""; n_espera=0
s_curso=""; n_curso=0
s_cola=""
s_chequeos=""; n_chequeos=0

push_espera() {
  n_espera=$(( n_espera + 1 ))
  if [ "$n_espera" -le "$CAP_ESPERA" ]; then s_espera="$s_espera  $1$nl"; fi
}
push_curso() {
  n_curso=$(( n_curso + 1 ))
  if [ "$n_curso" -le "$CAP_CURSO" ]; then s_curso="$s_curso  $1$nl"; fi
}
push_cola() { s_cola="$s_cola  $1$nl"; }
push_chequeo() {
  n_chequeos=$(( n_chequeos + 1 ))
  if [ "$n_chequeos" -le "$CAP_CHEQUEOS" ]; then s_chequeos="$s_chequeos  $1$nl"; fi
}

leidos=0
marcar_leido() { leidos=$(( leidos + 1 )); }

# ---------------------------------------------------------------- el árbol se lee, no se infiere
# La lectura de frontmatter (`fm_read`) y la expansión de los globs (`os_tree_files`) viven en
# common.sh: las comparten este arranque y los barridos globales.
tree_files=""
if matches=$(os_tree_files "$brain"); then
  [ -n "$matches" ] && tree_files="$matches$nl"
else
  push_chequeo "falta tree.md — el barrido no sabe qué rutas recorrer"
fi

# Lo que un `content:` alcanza (spec 007) cuenta como alcanzado por el árbol —nunca aparece en
# "ningún glob de tree.md alcanza"— pero no entra a `tree_files`: la construcción de cabezas más
# abajo solo lee `tree_files`, así que el contenido nunca se lee como cabeza sin necesidad de
# filtrarlo aparte.
content_files=""
if cmatches=$(os_tree_content_files "$brain"); then
  [ -n "$cmatches" ] && content_files="$cmatches$nl"
fi

en_tree() {
  case "$nl$tree_files$content_files" in
    *"$nl$1$nl"*) return 0 ;;
  esac
  return 1
}

# ---------------------------------------------------------------- los montajes de esta organización
# La cabeza de una iniciativa vive en el nodo dueño: las de un equipo, en el checkout compartido. La
# tabla del entorno es `mounts.md` de la raíz y se lee sola —`--mounts` es override—; el formato y el
# lector viven en common.sh, los mismos que usa el barrido global.
#
# La ausencia de tabla NO se declara acá: un brain sin nodos compartidos no la tiene nunca, y una
# línea fija en cada arranque gasta el tope de la sección 4 sin decir nada. Lo que sí se declara es
# el error —tabla escrita que no está, fila que no se puede leer, montaje sin checkout—, que es
# información que el operador no tiene de otro lado.
montados=""
mounts_declarada=1
if [ -z "$mounts" ]; then
  mounts_declarada=0
  mounts="$brain/$OS_MOUNTS_ARCHIVO"
fi
if [ ! -f "$mounts" ]; then
  if [ "$mounts_declarada" = "1" ]; then
    push_chequeo "tabla declarada no encontrada: $mounts — el arranque cubre solo el brain"
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
        montados="$montados$ruta$sep$f$nl"
      done <<GLOBS
$m2
GLOBS
    fi
  done <<FILAS
$(os_mounts_filas "$mounts")
FILAS
fi

# ---------------------------------------------------------------- el operador
operador=""
if [ -f "$brain/operator.md" ]; then
  marcar_leido
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      '# '*) operador=$(os_trim "${line#\# }"); break ;;
    esac
  done < "$brain/operator.md"
fi

# ---------------------------------------------------------------- tope de identidad
# El script diagnostica, no arregla: identidad y filas de resolver por separado, para que cuál de
# las dos creció sea evidente. Resumir o partir lo elige el operador.
contar_lineas() {
  local n
  [ -f "$1" ] || { printf '0'; return 0; }
  n=$(wc -l < "$1")
  printf '%s' "$(printf '%s' "$n" | tr -d ' ')"
}

contar_filas_resolver() {
  local n
  [ -f "$1" ] || { printf '0'; return 0; }
  n=$(grep -c '^| ' "$1")
  n=$(printf '%s' "$n" | tr -d ' ')
  n=$(( n - 1 ))
  [ "$n" -ge 0 ] || n=0
  printf '%s' "$n"
}

ctx="$brain/orgs/$org/context.md"
res_org="$brain/orgs/$org/resolver.md"

if [ -f "$ctx" ]; then marcar_leido; else push_chequeo "falta orgs/$org/context.md"; fi
if [ -f "$res_org" ]; then marcar_leido; else push_chequeo "falta orgs/$org/resolver.md"; fi
if [ -f "$brain/resolver.md" ]; then marcar_leido; fi

ident=$(contar_lineas "$ctx")
filas=$(contar_filas_resolver "$res_org")
diagnostico="identidad $ident/$OS_IDENTITY_CAP · resolver $filas filas"

if [ "$ident" -gt "$OS_IDENTITY_CAP" ]; then
  push_espera "orgs/$org/context.md — $diagnostico · resumir la historia o partir a context/"
fi

ident_op=$(contar_lineas "$brain/operator.md")
if [ "$ident_op" -gt "$OS_IDENTITY_CAP" ]; then
  push_espera "operator.md — identidad $ident_op/$OS_IDENTITY_CAP · resumir la historia o partir a context/"
fi

# ---------------------------------------------------------------- rol activado por el nodo
# El handoff nombra la capacidad, nunca la herramienta: si el oficio no está, se dice qué falta.
# Y si el frontmatter del nodo no se pudo leer, el rol no se activa pero se dice por qué: descartar
# el `role:` en silencio y devolver "sin hallazgos" es un barrido incompleto presentado como completo.
#
# La búsqueda del oficio es una sola (`os_buscar_oficio` en common.sh): la mitad negativa —el aviso
# de acá abajo— y la positiva —la línea `rol activo:` al final de la salida (spec 009)— leen del
# mismo lugar, para no tener dos copias del mismo recorrido.
fm_read "$ctx"
if [ -n "$fm_roto" ]; then
  push_chequeo "orgs/$org/context.md: $fm_roto — el rol no se activa"
fi
role="$fm_role"
rol_ruta=""
if [ -n "$role" ]; then
  if rol_ruta=$(os_buscar_oficio "$brain" "$role"); then
    :
  else
    rol_ruta=""
    push_chequeo "capacidad no instalada: rol de posición \"$role\""
  fi
fi

# ---------------------------------------------------------------- las cabezas
# Cada entrada es "raíz<sep>ruta relativa": la raíz es el brain o el checkout de un montaje. Una
# cabeza montada es una cabeza como cualquier otra — el barrido no distingue de dónde vino.
cabezas=""
while IFS="$sep" read -r raiz f || [ -n "$raiz" ]; do
  [ -n "$f" ] || continue
  case "$f" in
    "orgs/$org/"*) ;;
    *) continue ;;
  esac
  base=$(basename "$f")
  propio=0
  for p in $OS_ORG_PROPIOS; do
    [ "$base" = "$p" ] && propio=1
  done
  [ "$propio" = "1" ] && continue
  cabezas="$cabezas$raiz$sep$f$nl"
done <<TREE
$(while IFS= read -r f || [ -n "$f" ]; do
    [ -n "$f" ] || continue
    printf '%s%s%s\n' "$brain" "$sep" "$f"
  done <<PROPIAS
$tree_files
PROPIAS
printf '%s' "$montados")
TREE

n_next=0
n_later=0
sin_clasificar=0
nombres_sin=""
op_low=$(os_lower "$operador")

while IFS="$sep" read -r raiz f || [ -n "$raiz" ]; do
  [ -n "$f" ] || continue
  marcar_leido
  fm_read "$raiz/$f"
  base=$(basename "$f")
  nombre="${base%.md}"

  # Lo que no se pudo clasificar se declara. Un barrido incompleto presentado como completo es peor
  # que uno latente: el operador confía de más y nada le avisa.
  falta=""
  if [ -n "$fm_roto" ]; then
    # Un frontmatter que no se pudo leer no aporta filas a ninguna sección: lo que hay adentro del
    # archivo no se sabe, y adivinarlo es fabricar estado.
    sin_clasificar=$(( sin_clasificar + 1 ))
    if [ "$sin_clasificar" -le "$CAP_NOMBRES" ]; then
      [ -n "$nombres_sin" ] && nombres_sin="$nombres_sin, $nombre ($fm_roto)" \
        || nombres_sin="$nombre ($fm_roto)"
    fi
    continue
  fi

  # Una cabeza en estado terminal no está en curso, no espera a nadie y no cuenta en la cola. La
  # lista vive en common.sh: el arranque y los barridos globales tienen que contestar lo mismo sobre
  # el mismo archivo, o una iniciativa cerrada reaparece en "En curso" en cada sesión.
  if os_cerrado "$fm_status"; then continue; fi

  # Un `status:` fuera del vocabulario del esquema se declara, igual que en los barridos globales:
  # ni abierto para siempre ni desaparecido en silencio.
  if [ -n "$fm_status" ] && ! os_estado_valido "$fm_status"; then
    sin_clasificar=$(( sin_clasificar + 1 ))
    if [ "$sin_clasificar" -le "$CAP_NOMBRES" ]; then
      [ -n "$nombres_sin" ] && nombres_sin="$nombres_sin, $nombre (estado desconocido: $fm_status)" \
        || nombres_sin="$nombre (estado desconocido: $fm_status)"
    fi
    continue
  fi

  [ -n "$fm_horizon" ] || falta="sin horizon"
  if [ -z "$fm_status" ]; then
    [ -n "$falta" ] && falta="$falta, sin status" || falta="sin status"
  fi
  if [ -n "$falta" ]; then
    sin_clasificar=$(( sin_clasificar + 1 ))
    if [ "$sin_clasificar" -le "$CAP_NOMBRES" ]; then
      [ -n "$nombres_sin" ] && nombres_sin="$nombres_sin, $nombre ($falta)" \
        || nombres_sin="$nombre ($falta)"
    fi
  fi

  case "$fm_horizon" in
    next) n_next=$(( n_next + 1 )) ;;
    later) n_later=$(( n_later + 1 )) ;;
  esac

  # Sección 1 gana sobre la 2: lo que el operador destraba no se repite abajo. Quién destraba lo
  # dice el valor de `waiting_on:` — un gate (`gate-1`, `gate-2`) o el operador, por el literal
  # `operador` o por su nombre. Cualquier otro valor es una espera ajena: señal, y va a la 2.
  etiqueta=""
  if [ -n "$fm_waiting_on" ]; then
    wo_low=$(os_lower "$fm_waiting_on")
    case "$wo_low" in
      gate-*) etiqueta="espera $fm_waiting_on" ;;
      operador) etiqueta="te espera a vos" ;;
      *)
        if [ -n "$op_low" ] && [ "$wo_low" = "$op_low" ]; then etiqueta="te espera a vos"; fi
        ;;
    esac
  fi
  if [ -n "$etiqueta" ]; then
    push_espera "$nombre — $etiqueta"
    continue
  fi

  senal=""
  [ -n "$fm_blocked" ] && senal="trabada: $fm_blocked"
  if [ -z "$senal" ] && [ "$fm_status" = "blocked" ]; then senal="trabada"; fi
  if [ -z "$senal" ] && [ -n "$fm_waiting_on" ]; then senal="espera a $fm_waiting_on"; fi

  if [ "$fm_horizon" = "now" ] || [ -n "$senal" ]; then
    linea="$nombre · ${fm_horizon:-sin horizonte} · ${fm_status:-sin estado}"
    [ -n "$senal" ] && linea="$linea · $senal"
    push_curso "$linea"
  fi
done <<CABEZAS
$cabezas
CABEZAS

if [ "$sin_clasificar" -gt 0 ]; then
  resto=$(( sin_clasificar - CAP_NOMBRES ))
  if [ "$resto" -gt 0 ]; then
    push_chequeo "sin clasificar ($sin_clasificar): $nombres_sin y $resto más"
  else
    push_chequeo "sin clasificar ($sin_clasificar): $nombres_sin"
  fi
fi

# ---------------------------------------------------------------- rutas declaradas que no se alcanzan
# Una fila muerta del resolver y una referencia que no se alcanza son el mismo hallazgo: una ruta
# escrita que no existe. Se buscan por línea, sin parsear secciones — las rutas van entre backticks.
revisar_rutas() {
  local file="$1" rel="$2" n=0 line tok
  [ -f "$file" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    n=$(( n + 1 ))
    while IFS= read -r tok; do
      case "$tok" in
        *' '*|*'*'*|*'{{'*|'') continue ;;
        */*|*.md) ;;
        *) continue ;;
      esac
      if [ ! -e "$brain/$tok" ]; then
        push_chequeo "$rel:$n — no se alcanza: $tok"
      fi
    done <<TOKENS
$(os_backticks "$line")
TOKENS
  done < "$file"
}

revisar_rutas "$brain/resolver.md" "resolver.md"
revisar_rutas "$brain/.os/core/resolver.md" ".os/core/resolver.md"
revisar_rutas "$res_org" "orgs/$org/resolver.md"

# ---------------------------------------------------------------- nodos fuera del árbol
# El check de la raíz es de la spec 003: acá el barrido mira solo su organización.
fuera=""
n_fuera=0
while IFS= read -r f || [ -n "$f" ]; do
  [ -n "$f" ] || continue
  if ! en_tree "$f"; then
    n_fuera=$(( n_fuera + 1 ))
    if [ "$n_fuera" -le "$CAP_NOMBRES" ]; then
      [ -n "$fuera" ] && fuera="$fuera, $f" || fuera="$f"
    fi
  fi
done <<FUERA
$(cd "$brain" && find "orgs/$org" -type f -name '*.md' | sort)
FUERA
if [ "$n_fuera" -gt 0 ]; then
  resto=$(( n_fuera - CAP_NOMBRES ))
  if [ "$resto" -gt 0 ]; then
    push_chequeo "ningún glob de tree.md alcanza ($n_fuera): $fuera y $resto más"
  else
    push_chequeo "ningún glob de tree.md alcanza ($n_fuera): $fuera"
  fi
fi

# ---------------------------------------------------------------- la cola
push_cola "next $n_next · later $n_later"

# Tarea lista: sin `blocked-by` y sin `hold` vigente. El formato de línea y qué cuenta como lista
# viven en common.sh: los comparten quien escribe la tarea y quien la cuenta. Reconocer los
# marcadores por substring convertía el texto del operador en estructura — "revisar el blocked-by:
# de la spec 3" desaparecía del conteo de listas sin que nada lo dijera.
backlog="$brain/orgs/$org/backlog.md"
if [ -f "$backlog" ]; then
  marcar_leido
  hoy=$(date +%Y-%m-%d)
  b_pend=0
  b_listas=0
  b_n=0
  b_viejos=0
  b_viejo_linea=""
  while IFS= read -r line || [ -n "$line" ]; do
    b_n=$(( b_n + 1 ))
    os_backlog_lee "$line" || continue
    # Una clave reservada suelta en el texto —el formato que escribía la 002, sin paréntesis— ya no
    # se lee como marcador: se declara con su número de línea. El conteo no cambia; lo que cambia es
    # que el marcador perdido deja de perderse en silencio.
    if [ -n "$bl_roto" ]; then
      b_viejos=$(( b_viejos + 1 ))
      [ -n "$b_viejo_linea" ] || b_viejo_linea="$bl_roto (línea $b_n)"
    fi
    [ "$bl_hecha" = "0" ] || continue
    b_pend=$(( b_pend + 1 ))
    if os_backlog_lista "$hoy"; then b_listas=$(( b_listas + 1 )); fi
  done < "$backlog"
  push_cola "backlog: $b_listas listas de $b_pend pendientes"
  if [ "$b_viejos" -gt 0 ]; then
    if [ "$b_viejos" = "1" ]; then
      push_chequeo "orgs/$org/backlog.md — $b_viejo_linea"
    else
      push_chequeo "orgs/$org/backlog.md — $b_viejo_linea y $(( b_viejos - 1 )) más"
    fi
  fi
fi

if [ -f "$brain/inbox.md" ]; then
  marcar_leido
  i_n=$(grep -c '^- ' "$brain/inbox.md")
  i_n=$(printf '%s' "$i_n" | tr -d ' ')
  push_cola "inbox: $i_n sin clasificar"
fi

# ---------------------------------------------------------------- salida
imprimir() {
  # imprimir TITULO CONTENIDO N CAP VACIO
  printf '%s\n' "$1"
  if [ -z "$3" ] || [ "$3" = "0" ]; then
    printf '  %s\n' "$5"
  else
    printf '%s' "$2"
    resto=$(( $3 - $4 ))
    if [ "$resto" -gt 0 ]; then printf '  y %s más\n' "$resto"; fi
  fi
}

imprimir "Espera tu decisión" "$s_espera" "$n_espera" "$CAP_ESPERA" "nada espera tu decisión"
printf '\n'
imprimir "En curso" "$s_curso" "$n_curso" "$CAP_CURSO" "nada en curso"
printf '\n'
printf 'En cola\n'
printf '%s' "$s_cola"
printf '\n'
printf 'Chequeos\n'
printf '  %s\n' "$diagnostico"
if [ "$n_chequeos" = "0" ]; then
  printf '  sin hallazgos\n'
else
  printf '%s' "$s_chequeos"
  resto=$(( n_chequeos - CAP_CHEQUEOS ))
  if [ "$resto" -gt 0 ]; then printf '  y %s más\n' "$resto"; fi
fi


# ---------------------------------------------------------------- rol activo
# Al final de la salida, antes del cierre — formato aprobado en el Gate 1 de la spec 009. Solo
# aparece con `role:` declarado y el oficio instalado; sin `role:`, la línea no existe y la salida
# queda idéntica a la de antes de esta spec.
if [ -n "$rol_ruta" ]; then
  printf '\n'
  printf 'rol activo: %s · %s\n' "$role" "$rol_ruta"
fi

t_fin=$(os_now_ms)
printf '%s nodos · %s\n' "$leidos" "$(os_elapsed "$t_inicio" "$t_fin")"
exit 0
