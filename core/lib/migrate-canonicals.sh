#!/usr/bin/env bash
# One-time split of what `decisions.md`/`learnings.md` already hold into `decisions/<date>-<slug>.md`
# and `learnings/<slug>.md`, leaving the canonical file as the index (spec 043; spec 053 closed its
# residuals — see below). Internal: not invocable — run on demand, over any brain; no skill wraps it
# yet (out of scope of the spec that built it).
#
# Usage: migrate-canonicals.sh --brain DIR
#
# Idempotent: a canonical file that no longer has any `## ` entry block (already an index, from a
# previous run of this same script or from `close-session.sh` writing since) is left untouched, and
# a second run over an already-migrated brain leaves `git status --porcelain` empty.
#
# Two entry shapes are recognized inside a `---`-separated block, and a block with no `---` at all
# (spec 053 C2 — everything from the file's first `## ` line onward is treated as one block):
#   `## <date> · <title>`   a dated entry, same shape `close-session.sh` already writes — the date
#                            and title come straight from the heading. A block can hold more than one
#                            of these back to back with no `---` between them (spec 053 C1): each
#                            heading opens a new entry, its body running to the next one.
#   `## <heading>`          a themed heading with `- <text>` bullets under it (the shape this
#                            repo's own pre-043 `decisions.md`/`learnings.md` mixed in) — each bullet
#                            becomes its own undated learning. Its date is the one declared in the
#                            file's own header (a `Desde: YYYY-MM-DD` line before the first `---` or
#                            `## `), or — with no such line — the date of the file's first commit
#                            (`git log --diff-filter=A`). Nothing here ever stamps today's date on a
#                            fact the source did not date, which is exactly what would happen if the
#                            write date were used instead.
# Prose before a block's first `## ` (spec 053 C3) is not lost: it is appended to the index's own
# header, once, right before the block's entries are written.
#
# Every entry body is staged in a scratch directory first and the whole canonical is moved into
# place with one `mkdir -p` + `mv` only once it split clean end to end (spec 053 C5) — a stop midway
# leaves the brain's `decisions/`/`learnings/` folder and the canonical file exactly as they were.
#
# Stops without changing anything, and reports why (the spec's own stopping conditions):
#   - a block with no `## ` heading in it — an entry the format cannot name
#   - two entries with the same title and the same date — the migration does not invent a `-2`
#     the way the live writer does for a same-day collision; a genuine duplicate is a data problem,
#     not a naming one
#   - two different entries whose name collides after the slug is cut to its cap, or an entry whose
#     target file already exists on disk with different content (spec 053 C4) — same principle: a
#     collision is a data problem the migration reports, never one it resolves by guessing
#   - the entry cannot be written (spec 053 C4) — permissions, a read-only target, disk full
#   - the target canonical file has uncommitted changes — another session's work in progress, left
#     alone

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

nl=$(printf '\nx'); nl="${nl%x}"

wsdir=$(os_ws_dir "$brain")
memory_types_org=$(os_memory_types "$brain" org) || memory_types_org=""
memory_types_root=$(os_memory_types "$brain" root) || memory_types_root=""

reporte=""
push() { reporte="$reporte$1$nl"; }

es_git=0
[ -d "$brain/.git" ] && es_git=1

sucio() {
  # sucio RUTA_RELATIVA -> 0 si tiene cambios sin commitear, o no está trackeada.
  [ "$es_git" = "1" ] || return 1
  local out
  out=$(git -C "$brain" status --porcelain -- "$1" 2>/dev/null)
  [ -n "$out" ]
}

fecha_primer_commit() {
  # fecha_primer_commit RUTA_RELATIVA -> YYYY-MM-DD de cuándo se agregó el archivo, o vacío.
  [ "$es_git" = "1" ] || { printf ''; return 0; }
  git -C "$brain" log --diff-filter=A --format=%ad --date=format:%Y-%m-%d -- "$1" 2>/dev/null | tail -1
}

primera_linea_no_vacia() {
  # primera_linea_no_vacia CHUNK -> "NUM:CONTENIDO" de la primera línea con algo más que espacios,
  # o vacío si el trozo entero está en blanco. Un trozo trae una línea en blanco justo después del
  # `---` que lo abre; sin saltarla, "la primera línea" sería esa, no el encabezado.
  grep -n -m1 '[^[:space:]]' "$1" 2>/dev/null
}

os_migrate_header_end_linea() {
  # os_migrate_header_end_linea ARCHIVO -> número de línea (1-based) del primer "## " del archivo,
  # o vacío si no tiene ninguno. El único corte que dice dónde termina la cabecera de un canónico
  # (spec 055 C1): nunca el primer "---", esté donde esté. Lo usan `fecha_declarada_en_header` y
  # `migrar_archivo` — el mismo corte, escrito una sola vez.
  local l
  l=$(grep -n '^## ' "$1" | head -1)
  printf '%s' "${l%%:*}"
}

fecha_declarada_en_header() {
  # fecha_declarada_en_header ARCHIVO -> la fecha de una línea "Desde: YYYY-MM-DD" en la cabecera
  # real del archivo —todo antes de su primer "## " (spec 055 C1), sin importar si hay un "---"
  # antes—, o vacío. Convención de este migrador — el escritor en vivo no la usa, así que un
  # archivo que nunca la tuvo cae al commit.
  local archivo="$1" cut line n=0
  cut=$(os_migrate_header_end_linea "$archivo")
  while IFS= read -r line || [ -n "$line" ]; do
    n=$((n + 1))
    if [ -n "$cut" ] && [ "$n" -ge "$cut" ]; then break; fi
    case "$line" in
      'Desde: '*) printf '%s' "${line#Desde: }"; return 0 ;;
    esac
  done < "$archivo"
  return 1
}

# creados — los cuerpos que este archivo fue escribiendo mientras se procesaba (rutas de la carpeta
# de trabajo, spec 053 C5: nada de esto es todavía el brain real). Si el archivo entero se frena
# antes de terminar, `detener` borra la carpeta de trabajo entera; esta lista es una limpieza
# adicional, no la única.
creados=""
marcar_creado() { creados="$creados$1$nl"; }

# titulos_archivo — "rel → título" de cada cuerpo ya escrito en la carpeta de trabajo del canónico
# en curso, para poder nombrar qué se estaba escribiendo si el `mv` final (spec 053 C5) falla.
titulos_archivo=""
marcar_titulo() { titulos_archivo="$titulos_archivo$1 → $2$nl"; }

detener() {
  local f
  if [ -n "$creados" ]; then
    while IFS= read -r f || [ -n "$f" ]; do
      [ -n "$f" ] || continue
      rm -f "$f"
    done <<CREADOS
$creados
CREADOS
  fi
  # chunk_dir es local de migrar_archivo, pero sigue en el stack dinámico de bash mientras se llama
  # a detener desde cualquier función que ese archivo esté procesando — spec 053 C5: nada de lo que
  # se estaba armando en la carpeta de trabajo sobrevive a una parada.
  [ -n "${chunk_dir:-}" ] && rm -rf "$chunk_dir" 2>/dev/null
  printf 'migración detenida: %s\n' "$1" >&2
  [ -n "$reporte" ] && printf '%s' "$reporte" >&2
  exit 1
}

# visto — títulos+fechas ya emitidos en el archivo que se está migrando ahora mismo; se reinicia por
# archivo (migrar_archivo lo hace). Un duplicado exacto es la condición de parada de la spec.
visto=""
dup_visto() {
  case "$nl$visto$nl" in
    *"$nl$1$OS_SEP$2$nl"*) return 0 ;;
  esac
  return 1
}
marcar_visto() { visto="$visto$1$OS_SEP$2$nl"; }

# bloque_headings_mixtos CHUNK -> 0 si el bloque trae encabezados fechados y temáticos mezclados.
# La spec no dice cuál regla gana (spec 053, condición de parada): esto no elige, para la corrida.
# Solo bash + grep/head/tail — nada de sed/cut/awk (E7, PATH restringido): el número de línea de
# `grep -n` se separa con expansión de parámetros, no con `cut`.
bloque_headings_mixtos() {
  local chunk="$1" linea texto tipo tipo_primero=""
  while IFS= read -r linea; do
    [ -n "$linea" ] || continue
    texto="${linea#*:}"
    case "$texto" in
      '## '*' · '*) tipo=fechado ;;
      *) tipo=tematico ;;
    esac
    if [ -z "$tipo_primero" ]; then
      tipo_primero="$tipo"
    elif [ "$tipo" != "$tipo_primero" ]; then
      return 0
    fi
  done <<HEADS
$(grep -n '^## ' "$chunk")
HEADS
  return 1
}

# escribir_cuerpo WD PREFIJO NOMBRE NUEVO_INDICE FECHA TITULO CUERPO
# El único lugar que escribe un cuerpo: a la carpeta de trabajo WD/out/<rel> (nunca al brain
# directamente — spec 053 C5), verificando la escritura (spec 053 C4) y deteniendo la corrida ante
# cualquiera de las dos colisiones que la spec nombra y no resuelve por sí sola: dos entradas de esta
# misma corrida que caen en el mismo nombre, o un archivo que ya existe en el brain con otro
# contenido. Un contenido idéntico en cualquiera de los dos casos no es colisión: se admite sin
# volver a escribir nada.
escribir_cuerpo() {
  local wd="$1" prefijo="$2" nombre="$3" nuevo="$4" fecha="$5" titulo="$6" cuerpo="$7"
  local rel destino real tmp_entry
  if [ "$nombre" = "decisions" ]; then
    rel=$(os_decision_path "$brain" "$prefijo" "$fecha" "$titulo")
  else
    rel=$(os_learning_path "$brain" "$prefijo" "$titulo") || true
  fi
  destino="$wd/out/$rel"
  real="$brain/${prefijo}${rel}"

  tmp_entry=$(mktemp "$wd/entry.XXXXXX")
  if ! {
        printf '# %s\n\n' "$titulo"
        printf '> **Cuándo se lee**: %s\n\n' "$OS_CUANDO_FALTA"
        printf '%s\n' "$cuerpo"
      } > "$tmp_entry" 2>/dev/null
  then
    rm -f "$tmp_entry"
    detener "$rel — no se pudo escribir el cuerpo de \"$titulo\""
  fi

  if [ -e "$destino" ]; then
    if diff -q "$tmp_entry" "$destino" > /dev/null 2>&1; then
      rm -f "$tmp_entry"
      os_index_line "$fecha" "$titulo" "$rel" "$OS_CUANDO_FALTA" >> "$nuevo"
      push "$nombre → ${prefijo}${rel}: $titulo"
      return 0
    fi
    rm -f "$tmp_entry"
    detener "$rel — dos entradas de esta migración producen el mismo nombre de archivo: \"$titulo\""
  fi

  if [ -e "$real" ]; then
    if diff -q "$tmp_entry" "$real" > /dev/null 2>&1; then
      rm -f "$tmp_entry"
      os_index_line "$fecha" "$titulo" "$rel" "$OS_CUANDO_FALTA" >> "$nuevo"
      push "$nombre → ${prefijo}${rel}: $titulo (ya existía, mismo contenido)"
      return 0
    fi
    rm -f "$tmp_entry"
    detener "$rel — ya existe en el brain con otro contenido: \"$titulo\""
  fi

  if ! mkdir -p "$(dirname "$destino")" 2>/dev/null; then
    rm -f "$tmp_entry"
    detener "$rel — no se pudo escribir el cuerpo de \"$titulo\""
  fi
  if ! mv "$tmp_entry" "$destino" 2>/dev/null; then
    rm -f "$tmp_entry"
    detener "$rel — no se pudo escribir el cuerpo de \"$titulo\""
  fi
  marcar_creado "$destino"
  marcar_titulo "$rel" "$titulo"
  os_index_line "$fecha" "$titulo" "$rel" "$OS_CUANDO_FALTA" >> "$nuevo"
  push "$nombre → ${prefijo}${rel}: $titulo"
  return 0
}

escribir_desde_bloque_fechado() {
  # escribir_desde_bloque_fechado CHUNK PREFIJO NOMBRE NUEVO_INDICE WD
  # CHUNK empieza siempre en su primer "## " (procesar_bloque ya lo recortó ahí). Spec 053 C1: puede
  # traer más de un encabezado fechado seguido, sin "---" entre ellos — cada uno abre una entrada
  # nueva, y su cuerpo corre hasta el próximo encabezado o el fin del bloque.
  local chunk="$1" prefijo="$2" nombre="$3" nuevo="$4" wd="$5"
  local -a heads=()
  local -a textos=()
  local linea total_lineas
  # Solo bash + grep/head/tail — nada de sed/cut/awk (E7, PATH restringido): `grep -n` ya trae el
  # número y el texto en la misma línea ("N:texto"), separados acá con expansión de parámetros.
  while IFS= read -r linea; do
    [ -n "$linea" ] || continue
    heads+=("${linea%%:*}")
    textos+=("${linea#*:}")
  done <<HEADS
$(grep -n '^## ' "$chunk")
HEADS
  total_lineas=$(wc -l < "$chunk")
  local total=${#heads[@]} i
  i=0
  while [ "$i" -lt "$total" ]; do
    local hl="${heads[$i]}" hl_fin texto resto fecha titulo cuerpo sig=$((i + 1))
    texto="${textos[$i]}"
    resto="${texto#\#\# }"
    fecha="${resto%% · *}"
    titulo="${resto#* · }"
    if [ "$sig" -lt "$total" ]; then
      hl_fin=$(( ${heads[$sig]} - 1 ))
    else
      hl_fin="$total_lineas"
    fi
    cuerpo=$(head -n "$hl_fin" "$chunk" | tail -n +"$((hl + 1))")
    if dup_visto "$fecha" "$titulo"; then
      detener "entrada duplicada — $fecha · $titulo"
    fi
    marcar_visto "$fecha" "$titulo"
    escribir_cuerpo "$wd" "$prefijo" "$nombre" "$nuevo" "$fecha" "$titulo" "$cuerpo"
    i=$((i + 1))
  done
  return 0
}

# os_migrate_trim_izq LINEA -> LINEA sin los espacios que la abren. Sin sed/cut/awk (E7): el clásico
# recorte por expansión de parámetros, quitando el prefijo que solo trae espacios.
os_migrate_trim_izq() {
  local s="$1"
  printf '%s' "${s#"${s%%[![:space:]]*}"}"
}

# os_migrate_bullet_sin_soporte LINEA -> 0 si LINEA (ya recortada) es un bloque de código o una fila
# de tabla — las dos formas que la spec 054 deja como condición de parada: el agente no decide cómo
# migrar eso, frena.
os_migrate_bullet_sin_soporte() {
  case "$1" in
    '```'*) return 0 ;;
    '|'*) return 0 ;;
  esac
  return 1
}

escribir_desde_tematico() {
  # escribir_desde_tematico CHUNK PREFIJO NOMBRE NUEVO_INDICE FECHA_HEADER WD REL_CANONICO
  # Spec 054 C1: un bullet temático puede venir cortado en varias líneas (el brain escribe a cien
  # columnas). Toda línea que arranca con dos o más espacios y sigue a un "- " es su continuación,
  # hasta el próximo "- ", un encabezado, texto sin indentar, o el fin del bloque — se juntan en un
  # párrafo (un espacio donde había salto) y el título sale de la primera oración del bullet entero,
  # igual que hoy cuando el bullet era de una sola línea. Un sub-bullet ("  - ") es continuación del
  # padre, no un aprendizaje aparte (decisión cerrada de la spec).
  local chunk="$1" prefijo="$2" nombre="$3" nuevo="$4" fecha_header="$5" wd="$6" rel="$7"
  local -a lineas=()
  local -a partes=()
  local line en_bullet=0 trimmed cuerpo titulo

  flush_bullet() {
    [ "$en_bullet" = "1" ] || return 0
    cuerpo="${partes[*]}"
    titulo="${cuerpo%%. *}"
    [ -n "$titulo" ] || titulo="$cuerpo"
    if dup_visto "$fecha_header" "$titulo"; then
      detener "entrada duplicada — $fecha_header · $titulo"
    fi
    marcar_visto "$fecha_header" "$titulo"
    escribir_cuerpo "$wd" "$prefijo" "$nombre" "$nuevo" "$fecha_header" "$titulo" "$cuerpo"
    partes=()
    en_bullet=0
  }

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      '- '*)
        flush_bullet
        trimmed="${line#- }"
        if os_migrate_bullet_sin_soporte "$trimmed"; then
          detener "$rel — un bullet cortado trae un bloque de código o una tabla: \"$trimmed\""
        fi
        partes=("$trimmed")
        en_bullet=1
        ;;
      '  '*)
        [ -n "$line" ] || continue
        trimmed=$(os_migrate_trim_izq "$line")
        [ -n "$trimmed" ] || continue
        if [ "$en_bullet" = "1" ]; then
          if os_migrate_bullet_sin_soporte "$trimmed"; then
            detener "$rel — un bullet cortado trae un bloque de código o una tabla: \"$trimmed\""
          fi
          partes+=("$trimmed")
        fi
        ;;
      '## '*) flush_bullet ;;
      '') : ;;
      *) flush_bullet ;;
    esac
  done < "$chunk"
  flush_bullet
  return 0
}

procesar_bloque() {
  # procesar_bloque CHUNK PREFIJO NOMBRE NUEVO_INDICE FECHA_HEADER WD REL_CANONICO
  # Encuentra el primer "## " del bloque (spec 053 C3: puede no ser su primera línea — hay prosa
  # antes), conserva esa prosa en la cabecera del índice nuevo una sola vez, y recorta el bloque
  # para que arranque justo en el encabezado antes de decidir cómo partirlo.
  local chunk="$1" prefijo="$2" nombre="$3" nuevo="$4" fecha_header="$5" wd="$6" rel="$7"
  local primer_heading ln0 num0 prosa recortado primera_linea_heading

  primera_linea_heading=$(grep -n '^## ' "$chunk" | head -1)
  primer_heading="${primera_linea_heading%%:*}"
  if [ -z "$primer_heading" ]; then
    detener "$rel — un bloque sin encabezado \"## \""
  fi

  ln0=$(primera_linea_no_vacia "$chunk")
  num0="${ln0%%:*}"
  if [ "$num0" != "$primer_heading" ]; then
    prosa=$(head -n "$((primer_heading - 1))" "$chunk")
    { printf '%s\n' "$prosa"; printf '\n'; } >> "$nuevo"
  fi
  recortado=$(mktemp "$wd/blk.XXXXXX")
  tail -n +"$primer_heading" "$chunk" > "$recortado"
  chunk="$recortado"

  if bloque_headings_mixtos "$chunk"; then
    detener "$rel — bloque con entradas fechadas y temáticas mezcladas"
  fi

  local primera
  primera=$(head -n 1 "$chunk")
  case "$primera" in
    '## '*' · '*)
      escribir_desde_bloque_fechado "$chunk" "$prefijo" "$nombre" "$nuevo" "$wd"
      ;;
    '## '*)
      if [ -z "$fecha_header" ]; then
        detener "$rel — bullet sin fecha de header ni commit para fecharlo"
      fi
      escribir_desde_tematico "$chunk" "$prefijo" "$nombre" "$nuevo" "$fecha_header" "$wd" "$rel"
      ;;
  esac
}

migrar_archivo() {
  # migrar_archivo PREFIJO NOMBRE CONTENT_GLOB
  local prefijo="$1" nombre="$2" content_glob="$3"
  local archivo rel
  archivo="$brain/${prefijo}${nombre}.md"
  rel="${prefijo}${nombre}.md"
  [ -f "$archivo" ] || return 0

  os_tree_ensure "$brain" "$content_glob" content > /dev/null 2>&1 || true

  grep -q '^## ' "$archivo" || return 0

  if sucio "$rel"; then
    detener "$rel tiene cambios sin commitear — otra sesión puede estar trabajando en él"
  fi

  creados=""
  titulos_archivo=""

  local fecha_header=""
  fecha_header=$(fecha_declarada_en_header "$archivo") || true
  [ -n "$fecha_header" ] || fecha_header=$(fecha_primer_commit "$rel")

  # Spec 055 C1 · la cabecera es siempre lo de antes del primer "## " del archivo entero — nunca lo
  # de antes del primer "---" — así que ese corte (os_migrate_header_end_linea) se calcula primero
  # y el "---" solo cuenta para partir en bloques lo que queda desde ahí. El `grep -q '^## '` de
  # arriba ya garantiza que el corte no es vacío antes de llegar acá.
  local chunk_dir i=1 n lineno=0 heading_ln
  heading_ln=$(os_migrate_header_end_linea "$archivo")
  chunk_dir=$(mktemp -d)
  mkdir -p "$chunk_dir/out"
  : > "$chunk_dir/header"
  : > "$chunk_dir/c1"
  while IFS= read -r line || [ -n "$line" ]; do
    lineno=$((lineno + 1))
    if [ "$lineno" -lt "$heading_ln" ]; then
      printf '%s\n' "$line" >> "$chunk_dir/header"
      continue
    fi
    if [ "$lineno" -gt "$heading_ln" ] && [ "$line" = "---" ]; then
      i=$((i + 1))
      : > "$chunk_dir/c$i"
      continue
    fi
    printf '%s\n' "$line" >> "$chunk_dir/c$i"
  done < "$archivo"

  visto=""
  local nuevo="$chunk_dir/nuevo-indice"
  cp "$chunk_dir/header" "$nuevo"

  n=1
  while [ "$n" -le "$i" ]; do
    if [ -s "$chunk_dir/c$n" ]; then
      procesar_bloque "$chunk_dir/c$n" "$prefijo" "$nombre" "$nuevo" "$fecha_header" "$chunk_dir" "$rel"
    fi
    n=$((n + 1))
  done

  # Todo el canónico se pudo partir: recién ahora se toca el disco real del brain — un `mkdir -p`
  # más un solo `mv` (spec 053 C5), nunca antes de saber que terminó entero.
  if [ -n "$(ls -A "$chunk_dir/out/$nombre" 2>/dev/null)" ]; then
    if ! mkdir -p "$brain/${prefijo}${nombre}" 2>/dev/null; then
      detener "$rel — no se pudo crear ${prefijo}${nombre}/"
    fi
    if ! mv "$chunk_dir/out/$nombre"/* "$brain/${prefijo}${nombre}/" 2>"$chunk_dir/mv-err"; then
      local detalle
      detalle=$(cat "$chunk_dir/mv-err" 2>/dev/null)
      detener "$rel — no se pudo escribir en ${prefijo}${nombre}/ ($detalle) — quedaban: $titulos_archivo"
    fi
  fi

  mv "$nuevo" "$archivo"
  rm -rf "$chunk_dir"
  push "índice reescrito: $rel"
}

migrar_todo() {
  local o d t
  migrar_archivo "" decisions "decisions/*.md"
  migrar_archivo "" learnings "learnings/*.md"
  for o in $(os_org_slugs "$brain"); do
    migrar_archivo "$wsdir/$o/" decisions "$wsdir/*/decisions/*.md"
    migrar_archivo "$wsdir/$o/" learnings "$wsdir/*/learnings/*.md"
    for t in $memory_types_org; do
      [ -d "$brain/$wsdir/$o/$t" ] || continue
      for d in "$brain/$wsdir/$o/$t"/*; do
        [ -d "$d" ] || continue
        migrar_archivo "$wsdir/$o/$t/$(basename "$d")/" decisions "$wsdir/*/$t/*/decisions/*.md"
      done
    done
  done
  for t in $memory_types_root; do
    [ -d "$brain/$t" ] || continue
    for d in "$brain/$t"/*; do
      [ -d "$d" ] || continue
      migrar_archivo "$t/$(basename "$d")/" decisions "$t/*/decisions/*.md"
    done
  done
}
migrar_todo

if [ -z "$reporte" ]; then
  printf 'nada para migrar: todo canónico ya era índice\n'
else
  printf '%s' "$reporte"
fi
exit 0
