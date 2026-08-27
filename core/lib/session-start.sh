#!/usr/bin/env bash
# Barrido de arranque de sesión sobre un ámbito: una organización, o la raíz (el trabajo propio del
# operador, spec 018). Interno: no es invocable — lo dispara el contrato de sesión (core/CLAUDE.md)
# antes de que el modelo conteste el primer mensaje.
#
# Uso: session-start.sh --brain DIR --org SLUG [--mounts ARCHIVO]
#      session-start.sh --brain DIR --workspace SLUG [--mounts ARCHIVO]
#      session-start.sh --brain DIR --root      [--mounts ARCHIVO]
#
# `--workspace` es sinónimo exacto de `--org` (spec 039): los dos con el mismo valor, o uno solo,
# siguen igual; los dos con valores distintos frenan con error.
#
# `--org`/`--workspace` y `--root` son excluyentes. `--root` es un flag aparte y no un valor
# reservado del otro: un valor de texto siempre puede colisionar con lo que un operador nombre a un
# espacio de trabajo; un flag distinto, nunca.
#
# Lee el frontmatter de cada cabeza y los archivos que se cargan siempre. Nunca abre el cuerpo de
# una iniciativa: al `---` de cierre deja de leer. El recorrido son los globs de `tree.md` más las
# cabezas de este ámbito que vivan en un montaje: la tabla del entorno se lee sola desde la raíz del
# brain y `--mounts` es override.
#
# La salida son las mismas cuatro secciones fijas, siempre las cuatro, con vacío explícito, y una
# última línea con el conteo de nodos y el tiempo — con `--org` o con `--root` es el mismo formato.
# Cada sección tiene tope propio y declara lo que no entró: con 12 o con 40 iniciativas la salida
# mide lo mismo.
#
# Chequeos suma, cuando el brain es un repo git y el árbol no está limpio, una línea `sin commitear:
# N archivos · ruta, ruta` (spec 031) — lo que `close-session.sh` no pudo commitear en el cierre
# anterior, o lo que otra sesión dejó a medias. Con el árbol limpio, o sin `.git`, la línea no existe.
#
# Exit: 0 siempre que el ámbito exista — un chequeo avisa y no bloquea. 2 si la organización no
# existe.
# 1 if the install is broken: `templates/strings.md` (the bilingual catalog, spec 033) is missing,
# which `os_lang_load` requires to print anything — `os_die` says so on stderr before it dies.
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
workspace=""
mounts=""
root=0
while [ $# -gt 0 ]; do
  case "$1" in
    --brain) brain="${2:-}"; shift 2 ;;
    --org) org="${2:-}"; shift 2 ;;
    --workspace) workspace="${2:-}"; shift 2 ;;
    --root) root=1; shift ;;
    --mounts) mounts="${2:-}"; shift 2 ;;
    *) os_die "argumento desconocido: $1" ;;
  esac
done

# `--workspace` es sinónimo exacto de `--org` (P3, spec 039): nadie hacia afuera ve la palabra
# "org", así que la opción también dice "workspace". Los dos con valores distintos son un error;
# los dos con el mismo valor, o uno solo, siguen igual.
if [ -n "$org" ] && [ -n "$workspace" ] && [ "$org" != "$workspace" ]; then
  os_die "--org y --workspace con valores distintos: $org / $workspace"
fi
[ -n "$org" ] || org="$workspace"

[ -n "$brain" ] || os_die "falta --brain"
if [ "$root" = "1" ]; then
  [ -z "$org" ] || os_die "--root y --org/--workspace son excluyentes"
else
  [ -n "$org" ] || os_die "falta --org, --workspace o --root"
fi
[ -d "$brain" ] || os_die "no existe el brain: $brain"
brain=$(cd "$brain" && pwd)

# Layout inválido frena acá, antes de cualquier $(...) que arme una ruta con el nombre de la
# carpeta (P2, spec 039).
os_ws_check "$brain"
wsdir=$(os_ws_dir "$brain")
# La forma de la cabeza es dato del brain (spec 040): se lee del árbol una sola vez, y todo lo que
# arma una ruta de cabeza o cuenta un canónico la recibe de acá.
head=$(os_head_file "$brain") || true
org_propios=$(os_org_propios "$brain")

# Los tipos de nodo de memoria declarados en el árbol (spec 041): `products` fue el primero y ya no
# vive escrito a mano acá — cualquier carpeta hermana declarada con sus 3 líneas glob entra igual.
# Calculado una sola vez, antes de cualquier loop que lo necesite.
memory_types_org=$(os_memory_types "$brain" org) || memory_types_org=""
memory_types_root=$(os_memory_types "$brain" root) || memory_types_root=""

# All the fixed or template text this script prints for the operator comes out of the bilingual
# catalog (spec 021/033): with `language: en` in `operator.md` it comes out in English, and with
# `es` (or no `operator.md` yet, `os_language` falls back to `en` — Checks says so, further down)
# it comes out exactly like it did before this spec — the catalog's `es:` column carries the same
# prose.
lang=$(os_language "$brain")
os_lang_load "$lang"

# translate_fm_broken VALUE -> the same `fm_roto`/`bl_roto` value (always in Spanish: common.sh
# returns it, and it does not know the scan's language) translated with the catalog already loaded
# above. Does not touch `common.sh`: `sweep.sh` and `check-resolvable.sh` keep reading those values
# as-is, without the full catalog loaded, and are not affected by this local translation.
translate_fm_broken() {
  case "$1" in
    'sin frontmatter') printf '%s' "$S_FM_NO_FRONTMATTER" ;;
    'frontmatter sin cerrar') printf '%s' "$S_FM_UNCLOSED" ;;
    'frontmatter demasiado largo') printf '%s' "$S_FM_TOO_LONG" ;;
    *) printf '%s' "$1" ;;
  esac
}

# translate_bl_broken VALUE -> the same, for `bl_roto` (from `os_backlog_lee` in common.sh).
translate_bl_broken() {
  case "$1" in
    'marcador en formato viejo: '*)
      printf "$S_BACKLOG_OLD_MARKER" "${1#marcador en formato viejo: }" ;;
    *) printf '%s' "$1" ;;
  esac
}

# ---------------------------------------------------------------- el ámbito se valida contra el listado
# El slug se compara byte a byte contra los nombres reales de la carpeta de espacios de trabajo,
# nunca con `-d`. Un test de
# directorio acepta lo que el filesystem acepte: en un FS que no distingue mayúsculas `--org Acme`
# pasa y después no matchea contra el slug `acme`, y `--org ../..` sale del árbol. Las dos formas
# devolvían las cuatro secciones vacías con exit 0 — un barrido vacío que se lee como un brain vacío.
# El script no adivina el ámbito: lista lo que hay y devuelve el control. La skill pregunta con eso.
#
# La raíz no tiene este chequeo: siempre existe, así que `--root` nunca puede fallar por ámbito.
if [ "$root" = "0" ]; then
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
    printf "$S_SESSION_ORG_NOT_FOUND\n" "$org" >&2
    if [ -n "$org_slugs" ]; then
      printf '%s' "$org_slugs" >&2
    else
      printf '  %s\n' "$S_SESSION_NO_ORGS" >&2
    fi
    exit 2
  fi
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

# ---------------------------------------------------------------- estado de git del brain (spec 031)
# `close-session.sh` commitea lo que la sesión escribió; lo que sigue sucio al arrancar la próxima es
# de otra sesión o de una escritura fuera del cierre. Decirlo acá evita que se lea como ruido cuando
# `git status` ya lo muestra aparte.
if sucios=$(os_git_sucio "$brain"); then
  git_n=0
  git_lista=""
  while IFS= read -r r || [ -n "$r" ]; do
    [ -n "$r" ] || continue
    git_n=$(( git_n + 1 ))
    if [ -z "$git_lista" ]; then git_lista="$r"; else git_lista="$git_lista, $r"; fi
  done <<SUCIOS
$sucios
SUCIOS
  if [ "$git_n" -gt 0 ]; then
    push_chequeo "$(printf "$S_SESSION_CHECK_UNCOMMITTED" "$git_n" "$git_lista")"
  fi
fi

# ---------------------------------------------------------------- el árbol se lee, no se infiere
# La lectura de frontmatter (`fm_read`) y la expansión de los globs (`os_tree_files`) viven en
# common.sh: las comparten este arranque y los barridos globales.
tree_files=""
if matches=$(os_tree_files "$brain"); then
  [ -n "$matches" ] && tree_files="$matches$nl"
else
  push_chequeo "$S_SESSION_CHECK_NO_TREE"
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
    push_chequeo "$(printf "$S_SESSION_CHECK_MOUNTS_TABLE_MISSING" "$mounts")"
  fi
else
  tabla="${mounts##*/}"
  while IFS="$sep" read -r n remote ruta || [ -n "$n" ]; do
    [ -n "$n" ] || continue
    if [ -z "$remote" ] || [ -z "$ruta" ]; then
      push_chequeo "$(printf "$S_SESSION_CHECK_MOUNT_ROW_UNREADABLE" "$tabla:$n")"
      continue
    fi
    if [ ! -d "$ruta" ]; then
      push_chequeo "$(printf "$S_SESSION_CHECK_MOUNT_UNREACHED" "$remote" "$tabla:$n")"
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

# identidad_tipo TIPO PREFIJO -> una línea por nodo de un tipo de memoria cuya identidad pasa el
# tope, empujada a "Espera tu decisión". Mismo mecanismo que ya usaba `products` (contar_lineas +
# OS_IDENTITY_CAP): un nodo de memoria es memoria y su cabeza puede crecer igual que la de la
# organización o la del operador. PREFIJO es la ruta hasta el tipo, relativa al brain (con o sin
# `$wsdir/$org/` según el ámbito).
identidad_tipo() {
  local tipo="$1" prefijo="$2" node_ctx ident_n
  for node_ctx in "$brain/$prefijo$tipo/"*/"$head"; do
    [ -f "$node_ctx" ] || continue
    ident_n=$(contar_lineas "$node_ctx")
    if [ "$ident_n" -gt "$OS_IDENTITY_CAP" ]; then
      push_espera "$(printf "$S_SESSION_WAITING_IDENTITY_OVER" "${node_ctx#$brain/}" \
        "$(printf "$S_SESSION_IDENTITY_SIMPLE" "$ident_n" "$OS_IDENTITY_CAP")")"
    fi
  done
}

# La raíz no tiene cabeza de nodo propia: su identidad es `operator.md`, que ya se cuenta abajo, y su
# resolver es el de la raíz (`resolver.md`), sin el `<wsdir>/<slug>/resolver.md` de un espacio de
# trabajo. Sí puede tener tipos de nodo de memoria propios (`channels/` en la raíz, spec 041): su
# identidad entra al mismo chequeo que la de un espacio de trabajo.
if [ "$root" = "1" ]; then
  if [ -f "$brain/resolver.md" ]; then marcar_leido; fi
  filas=$(contar_filas_resolver "$brain/resolver.md")
  for tipo in $memory_types_root; do
    identidad_tipo "$tipo" ""
  done
else
  ctx="$brain/$wsdir/$org/$head"
  res_org="$brain/$wsdir/$org/resolver.md"

  if [ -f "$ctx" ]; then marcar_leido; else push_chequeo "$(printf "$S_SESSION_CHECK_MISSING_FILE" "$wsdir/$org/$head")"; fi
  if [ -f "$res_org" ]; then marcar_leido; else push_chequeo "$(printf "$S_SESSION_CHECK_MISSING_FILE" "$wsdir/$org/resolver.md")"; fi
  if [ -f "$brain/resolver.md" ]; then marcar_leido; fi

  ident=$(contar_lineas "$ctx")
  filas=$(contar_filas_resolver "$res_org")
  diagnostico=$(printf "$S_SESSION_IDENTITY_DIAG" "$ident" "$OS_IDENTITY_CAP" "$filas")

  if [ "$ident" -gt "$OS_IDENTITY_CAP" ]; then
    push_espera "$(printf "$S_SESSION_WAITING_IDENTITY_OVER" "$wsdir/$org/$head" "$diagnostico")"
  fi

  # La identidad de cada nodo de memoria de la organización entra al mismo chequeo (spec 036,
  # generalizado por la 041 a cualquier tipo declarado, no solo `products`): un nodo de memoria es
  # memoria y su cabeza puede crecer igual que la de la organización. Nada si ningún tipo tiene
  # nodos sobre el tope — sin resolver propio que reportar acá, misma forma que operator.md abajo.
  for tipo in $memory_types_org; do
    identidad_tipo "$tipo" "$wsdir/$org/"
  done
fi

ident_op=$(contar_lineas "$brain/operator.md")
if [ "$root" = "1" ]; then
  diagnostico=$(printf "$S_SESSION_IDENTITY_DIAG" "$ident_op" "$OS_IDENTITY_CAP" "$filas")
fi
if [ "$ident_op" -gt "$OS_IDENTITY_CAP" ]; then
  push_espera "$(printf "$S_SESSION_WAITING_IDENTITY_OVER" "operator.md" \
    "$(printf "$S_SESSION_IDENTITY_SIMPLE" "$ident_op" "$OS_IDENTITY_CAP")")"
fi

# ---------------------------------------------------------------- rol activado por el nodo
# El handoff nombra la capacidad, nunca la herramienta: si el oficio no está, se dice qué falta.
# Y si el frontmatter del nodo no se pudo leer, el rol no se activa pero se dice por qué: descartar
# el `role:` en silencio y devolver "sin hallazgos" es un barrido incompleto presentado como completo.
#
# La búsqueda del oficio es una sola (`os_buscar_oficio` en common.sh): la mitad negativa —el aviso
# de acá abajo— y la positiva —la línea `active-role:` al final de la salida (spec 009)— leen del
# mismo lugar, para no tener dos copias del mismo recorrido.
#
# La raíz no activa rol: el operador no es una posición (fuera de alcance de la spec 018), y no tiene
# cabeza con `role:` que leer.
role=""
rol_ruta=""
if [ "$root" = "0" ]; then
  fm_read "$ctx"
  if [ -n "$fm_roto" ]; then
    push_chequeo "$(printf "$S_SESSION_CHECK_ROLE_NOT_ACTIVATED" "$wsdir/$org/$head" \
      "$(translate_fm_broken "$fm_roto")")"
  fi
  role="$fm_role"
  if [ -n "$role" ]; then
    if rol_ruta=$(os_buscar_oficio "$brain" "$role"); then
      :
    else
      rol_ruta=""
      # El ofrecimiento del pack va pegado al aviso (spec 029): un oficio que no resuelve es la
      # demanda, y sin ningún pack instalado el comando que lo trae es la respuesta.
      # `os_pack_hint` always returns its text in Spanish — translating it means touching
      # `pack-install.sh`, which generates the line, and is out of this spec's scope (documented
      # gap).
      push_chequeo "$(printf "$S_SESSION_CHECK_CAPABILITY_MISSING" "$role" "$(os_pack_hint "$brain")")"
    fi
  fi
fi

# ---------------------------------------------------------------- las cabezas
# Cada entrada es "raíz<sep>ruta relativa": la raíz es el brain o el checkout de un montaje. Una
# cabeza montada es una cabeza como cualquier otra — el barrido no distingue de dónde vino.
cabezas=""
while IFS="$sep" read -r raiz f || [ -n "$raiz" ]; do
  [ -n "$f" ] || continue
  if [ "$root" = "1" ]; then
    # Solo lo que vive en el brain mismo: la raíz no tiene montajes propios en esta spec, y un
    # archivo montado con ruta que no empieza en el prefijo de la carpeta de espacios de trabajo no
    # puede confundirse con una cabeza propia.
    [ "$raiz" = "$brain" ] || continue
    case "$f" in
      "$wsdir"/*) continue ;;
    esac
    propios="$OS_ROOT_PROPIOS"
  else
    case "$f" in
      "$wsdir/$org/"*) ;;
      *) continue ;;
    esac
    propios="$org_propios"
  fi
  base=$(basename "$f")
  propio=0
  if [ "$root" = "1" ]; then
    for p in $propios; do [ "$base" = "$p" ] && propio=1; done
  else
    # El nombre propio solo cuenta a la altura directa de la organización: un archivo debajo de una
    # subcarpeta (`products/<slug>/<cabeza>`) puede compartir basename con un canónico de la
    # organización sin serlo — comparar solo por basename lo excluía del conteo de nodos aunque el
    # árbol lo alcance con su propio `glob:` (Q-12 del nodo de producto).
    resto="${f#$wsdir/$org/}"
    case "$resto" in
      */*) ;;
      *) for p in $propios; do [ "$resto" = "$p" ] && propio=1; done ;;
    esac
  fi
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
  nombre=$(os_node_name "$f")

  # Un nodo de memoria es memoria, no estado (spec 036, generalizado por la 041 a cualquier tipo
  # declarado, no solo `products`): ya sumó al conteo de nodos con `marcar_leido` de arriba, pero no
  # entra a ninguna de las cuatro secciones. No tiene `status`/`horizon` que reportar, y tratarlo
  # como "sin status" sería ruido fijo en cada arranque, nunca un hallazgo real.
  if os_memory_own_file "$wsdir" "$head" "$memory_types_org" "$memory_types_root" "$f"; then
    continue
  fi

  # Lo que no se pudo clasificar se declara. Un barrido incompleto presentado como completo es peor
  # que uno latente: el operador confía de más y nada le avisa.
  falta=""
  if [ -n "$fm_roto" ]; then
    # Un frontmatter que no se pudo leer no aporta filas a ninguna sección: lo que hay adentro del
    # archivo no se sabe, y adivinarlo es fabricar estado.
    sin_clasificar=$(( sin_clasificar + 1 ))
    if [ "$sin_clasificar" -le "$CAP_NOMBRES" ]; then
      fm_roto_tr=$(translate_fm_broken "$fm_roto")
      [ -n "$nombres_sin" ] && nombres_sin="$nombres_sin, $nombre ($fm_roto_tr)" \
        || nombres_sin="$nombre ($fm_roto_tr)"
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
      estado_desc=$(printf "$S_SESSION_UNKNOWN_STATUS" "$fm_status")
      [ -n "$nombres_sin" ] && nombres_sin="$nombres_sin, $nombre ($estado_desc)" \
        || nombres_sin="$nombre ($estado_desc)"
    fi
    continue
  fi

  [ -n "$fm_horizon" ] || falta="$S_SESSION_MISSING_HORIZON"
  if [ -z "$fm_status" ]; then
    [ -n "$falta" ] && falta="$falta, $S_SESSION_MISSING_STATUS" || falta="$S_SESSION_MISSING_STATUS"
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
      gate-*) etiqueta=$(printf "$S_SESSION_WAITING_GATE" "$fm_waiting_on") ;;
      operador) etiqueta="$S_SESSION_WAITING_YOU" ;;
      *)
        if [ -n "$op_low" ] && [ "$wo_low" = "$op_low" ]; then etiqueta="$S_SESSION_WAITING_YOU"; fi
        ;;
    esac
  fi
  if [ -n "$etiqueta" ]; then
    push_espera "$nombre — $etiqueta"
    continue
  fi

  senal=""
  [ -n "$fm_blocked" ] && senal=$(printf "$S_SESSION_BLOCKED_WITH_REASON" "$fm_blocked")
  if [ -z "$senal" ] && [ "$fm_status" = "blocked" ]; then senal="$S_SESSION_BLOCKED"; fi
  if [ -z "$senal" ] && [ -n "$fm_waiting_on" ]; then senal=$(printf "$S_SESSION_WAITING_ON" "$fm_waiting_on"); fi

  if [ "$fm_horizon" = "now" ] || [ -n "$senal" ]; then
    linea="$nombre · ${fm_horizon:-$S_SESSION_NO_HORIZON_LABEL} · ${fm_status:-$S_SESSION_NO_STATUS_LABEL}"
    [ -n "$senal" ] && linea="$linea · $senal"
    push_curso "$linea"
  fi
done <<CABEZAS
$cabezas
CABEZAS

if [ "$sin_clasificar" -gt 0 ]; then
  resto=$(( sin_clasificar - CAP_NOMBRES ))
  msg=$(printf "$S_SESSION_UNCLASSIFIED" "$sin_clasificar" "$nombres_sin")
  if [ "$resto" -gt 0 ]; then
    msg="$msg $(printf "$S_SESSION_MORE" "$resto")"
  fi
  push_chequeo "$msg"
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
        push_chequeo "$(printf "$S_SESSION_ROUTE_NOT_REACHED" "$rel" "$n" "$tok")"
      fi
    done <<TOKENS
$(os_backticks "$line")
TOKENS
  done < "$file"
}

revisar_rutas "$brain/resolver.md" "resolver.md"
revisar_rutas "$brain/.os/core/resolver.md" ".os/core/resolver.md"
if [ "$root" = "0" ]; then
  revisar_rutas "$res_org" "$wsdir/$org/resolver.md"
fi

# ---------------------------------------------------------------- nodos fuera del árbol
# El check de la raíz es de la spec 003: acá el barrido mira solo su ámbito — su espacio de
# trabajo, o (con `--root`) los archivos propios de la raíz: sueltos en el brain, o bajo
# `initiatives/` y `voice/`, nunca la carpeta de espacios de trabajo ni lo que instala el producto.
fuera=""
n_fuera=0
if [ "$root" = "1" ]; then
  listado=$(cd "$brain" && {
      for f in *.md; do
        [ -f "$f" ] || continue
        [ "$f" = "CLAUDE.md" ] && continue
        [ "$f" = "tree.md" ] && continue
        printf '%s\n' "$f"
      done
      [ -d initiatives ] && find initiatives -type f -name '*.md'
      [ -d voice ] && find voice -type f -name '*.md'
    } | sort)
else
  listado=$(cd "$brain" && find "$wsdir/$org" -type f -name '*.md' | sort)
fi
while IFS= read -r f || [ -n "$f" ]; do
  [ -n "$f" ] || continue
  if ! en_tree "$f"; then
    n_fuera=$(( n_fuera + 1 ))
    if [ "$n_fuera" -le "$CAP_NOMBRES" ]; then
      [ -n "$fuera" ] && fuera="$fuera, $f" || fuera="$f"
    fi
  fi
done <<FUERA
$listado
FUERA
if [ "$n_fuera" -gt 0 ]; then
  resto=$(( n_fuera - CAP_NOMBRES ))
  msg=$(printf "$S_SESSION_OUTSIDE_TREE" "$n_fuera" "$fuera")
  if [ "$resto" -gt 0 ]; then
    msg="$msg $(printf "$S_SESSION_MORE" "$resto")"
  fi
  push_chequeo "$msg"
fi

# ---------------------------------------------------------------- la cola
push_cola "next $n_next · later $n_later"

# Tarea lista: sin `blocked-by` y sin `hold` vigente. El formato de línea y qué cuenta como lista
# viven en common.sh: los comparten quien escribe la tarea y quien la cuenta. Reconocer los
# marcadores por substring convertía el texto del operador en estructura — "revisar el blocked-by:
# de la spec 3" desaparecía del conteo de listas sin que nada lo dijera.
if [ "$root" = "1" ]; then
  backlog="$brain/backlog.md"
  backlog_rel="backlog.md"
else
  backlog="$brain/$wsdir/$org/backlog.md"
  backlog_rel="$wsdir/$org/backlog.md"
fi
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
      [ -n "$b_viejo_linea" ] || b_viejo_linea="$(translate_bl_broken "$bl_roto") $(printf "$S_SESSION_OLD_MARKER_LINE" "$b_n")"
    fi
    [ "$bl_hecha" = "0" ] || continue
    b_pend=$(( b_pend + 1 ))
    if os_backlog_lista "$hoy"; then b_listas=$(( b_listas + 1 )); fi
  done < "$backlog"
  push_cola "$(printf "$S_SESSION_BACKLOG_READY" "$b_listas" "$b_pend")"
  if [ "$b_viejos" -gt 0 ]; then
    if [ "$b_viejos" = "1" ]; then
      push_chequeo "$backlog_rel — $b_viejo_linea"
    else
      push_chequeo "$backlog_rel — $b_viejo_linea $(printf "$S_SESSION_MORE" "$(( b_viejos - 1 ))")"
    fi
  fi
fi

if [ -f "$brain/inbox.md" ]; then
  marcar_leido
  i_n=$(grep -c '^- ' "$brain/inbox.md")
  i_n=$(printf '%s' "$i_n" | tr -d ' ')
  push_cola "$(printf "$S_SESSION_INBOX_UNCLASSIFIED" "$i_n")"
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
    if [ "$resto" -gt 0 ]; then printf "  $S_SESSION_MORE\n" "$resto"; fi
  fi
}

imprimir "$S_SESSION_WAITING_TITLE" "$s_espera" "$n_espera" "$CAP_ESPERA" "$S_SESSION_WAITING_EMPTY"
printf '\n'
imprimir "$S_SESSION_INPROGRESS_TITLE" "$s_curso" "$n_curso" "$CAP_CURSO" "$S_SESSION_INPROGRESS_EMPTY"
printf '\n'
printf '%s\n' "$S_SESSION_QUEUE_TITLE"
printf '%s' "$s_cola"
printf '\n'
printf '%s\n' "$S_SESSION_CHECKS_TITLE"
printf '  %s\n' "$diagnostico"
if [ "$n_chequeos" = "0" ]; then
  printf '  %s\n' "$S_SESSION_CHECKS_EMPTY"
else
  printf '%s' "$s_chequeos"
  resto=$(( n_chequeos - CAP_CHEQUEOS ))
  if [ "$resto" -gt 0 ]; then printf "  $S_SESSION_MORE\n" "$resto"; fi
fi


# ---------------------------------------------------------------- active-role
# Al final de la salida, antes del cierre — formato aprobado en el Gate 1 de la spec 009. Solo
# aparece con `role:` declarado y el oficio instalado; sin `role:`, la línea no existe y la salida
# queda idéntica a la de antes de esta spec.
if [ -n "$rol_ruta" ]; then
  printf '\n'
  # Fixed marker, in English, the same in both languages (spec 033): core/CLAUDE.md matches it as
  # a structural identifier, not as translatable prose.
  printf 'active-role: %s · %s\n' "$role" "$rol_ruta"
fi

t_fin=$(os_now_ms)
# The closing line carries the product version as a suffix of the line that already exists, never as
# a line of its own (spec 038): the output keeps its line count and the ` nodes · ` substring the
# other specs match on. The suffix is fixed and the same in both languages, like `active-role:`
# above — it is a structural marker, not translatable prose. With no `core/VERSION` (an install
# hooked to an older core/), the line comes out exactly as before.
version=$(os_version)
if [ -n "$version" ]; then
  printf "$S_SESSION_NODE_COUNT · v%s\n" "$leidos" "$(os_elapsed "$t_inicio" "$t_fin")" "$version"
else
  printf "$S_SESSION_NODE_COUNT\n" "$leidos" "$(os_elapsed "$t_inicio" "$t_fin")"
fi
exit 0
