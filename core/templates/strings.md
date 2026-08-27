# Strings — the fixed prose of what bootstrap writes, in every language it writes

The templates hold the structure; this file holds their prose. **One structure, one translation
per string**: a language is a column here, never a second copy of a template — a duplicated
template desyncs the first time the structure changes.

Format, one block per key:

```
key: SOME_KEY
en: the English text
es: el texto en español
```

- A value with several lines repeats its language prefix, one line each. `en:` with nothing after
  it is an empty line inside the value.
- A key reaches a template as `{{T_SOME_KEY}}`.
- A key without its line in the language being written falls back to `en` **and says so** on
  stderr. It never falls back in silence.
- Supported languages: `en`, `es`. Adding one is adding its prefix to every block here.

key: OPERATOR_VOICE_POINTER
en: Voice: `voice.md`.
es: Voz: `voice.md`.

key: OPERATOR_PROFILE_HEADING
en: Profile
es: Perfil

key: OPERATOR_REPLY_HEADING
en: How I want to be answered
es: Cómo quiero que me contesten

key: OPERATOR_REPLY_MARK
en: **Learned with use.** This section was not asked in the interview: it is a default. Correct it
en: the first time an answer misses, and it stops being generic.
es: **Se aprende con el uso.** Esta sección no se preguntó en la entrevista: es un default. Se
es: corrige la primera vez que una respuesta no da en el clavo, y deja de ser genérica.

key: OPERATOR_REPLY_DEFAULT
en: - The answer first. The first three lines carry the result; the reasoning goes after, and only
en:   if it adds something.
en: - Short. A message that runs long without a document being asked for is wrong.
en: - No process narration: which files were read, what was checked, what was corrected.
es: - La respuesta primero. Las primeras tres líneas traen el resultado; el razonamiento va después,
es:   y solo si aporta.
es: - Corto. Un mensaje largo sin que se haya pedido un documento está mal.
es: - Nada de meta: qué archivos leí, qué chequeé, qué corregí.

key: VOICE_TITLE
en: Voice of
es: Voz de

key: VOICE_INTRO
en: The record is per channel: with no channel declared, it goes here. A channel with a personality
en: of its own becomes an identity, with its own `voice.md` in its own node.
es: El registro es por canal: sin canal declarado, entra acá. Un canal con personalidad propia se
es: vuelve una identidad, con su `voice.md` en su nodo.

key: VOICE_PENDING
en: Not declared yet. The interview asks for it and takes "later" for an answer: it gets written
en: the first time something comes out sounding like someone else.
es: Todavía sin declarar. La entrevista la pregunta y acepta "después": se escribe la primera vez
es: que algo sale sonando a otra persona.

key: ORG_OPERATOR_HERE
en: The operator here:
es: El operador acá:

key: ORG_IDENTITY_PLACEHOLDER
en: What it is, for whom, and how it makes money. Three or four lines.
es: Qué es, para quién y cómo gana plata. Tres o cuatro líneas.

key: PRODUCT_IDENTITY_PLACEHOLDER
en: What it is and who it is for. Two or three lines.
es: Qué es y para quién. Dos o tres líneas.

key: MEMORY_IDENTITY_PLACEHOLDER
en: What it is and what is known about it. Two or three lines.
es: Qué es y qué se sabe de esto. Dos o tres líneas.

key: RESOLVER_TITLE_HEAD
en: Resolver of
es: Resolver de

key: RESOLVER_TITLE_TAIL
en: — where what gets written goes
es: — dónde va lo que se escribe

key: RESOLVER_INTRO
en: Content → destination. One row per exception: whatever the structure already answers gets no
en: row. The system writes it when something had to be decided that the structure did not answer.
en:
en: It is born with no rows.
es: Contenido → destino. Una fila por excepción: lo que la estructura ya contesta no lleva fila. Lo
es: escribe el sistema cuando hubo que decidir algo que la estructura no contestaba.
es:
es: Nace sin filas.

key: RESOLVER_TABLE_HEAD
en: | Content | Destination |
en: |---|---|
es: | Contenido | Destino |
es: |---|---|

key: RESOLVER_REFERENCES_HEADING
en: References
es: Referencias

key: RESOLVER_REFERENCES_INTRO
en: What this node uses from outside, by path. If the agent cannot reach it, it says so instead of
en: assuming.
es: Lo que este nodo usa de afuera, por ruta. Si el agente no lo alcanza, lo dice en vez de asumir.

key: ROOT_RESOLVER_TITLE
en: Root resolver — origin: personal
es: Resolver de la raíz — origen: personal

key: ROOT_RESOLVER_INTRO
en: Capability → tool. The operator's rows go here: what the product does not route, or what they
en: would rather route differently. They win over the product's rows when both cover the same
en: capability.
en:
en: It is born with no rows. A row goes in when a competent agent would have chosen wrong without
en: it, and comes out when it is systematically ignored.
es: Capacidad → herramienta. Acá van las filas del operador: lo que el producto no rutea, o lo que
es: prefiere rutear distinto. Ganan sobre las filas del producto cuando las dos cubren la misma
es: capacidad.
es:
es: Nace sin filas. Una fila entra cuando un agente competente habría elegido mal sin ella, y sale
es: cuando se la ignora sistemáticamente.

key: ROOT_RESOLVER_TABLE_HEAD
en: | Capability | Tool | Path |
en: |---|---|---|
es: | Capacidad | Herramienta | Ruta |
es: |---|---|---|

key: BACKLOG_TITLE
en: Backlog of
es: Backlog de

key: BACKLOG_INTRO
en: What is missing and belongs to no initiative. One line per task: nothing is left with no state,
en: and whatever is postponed carries the date it comes back.
es: Lo que falta y no es de ninguna iniciativa. Una línea por tarea: nada queda sin estado y lo
es: postergado lleva la fecha en la que resurge.

key: FIRST_COMMIT
en: the brain is born
es: nace el brain

key: PACK_TASK
en: Product Builder pack pending: install it from the brain folder with
es: Pack Product Builder pendiente: instalarlo desde la carpeta del brain con

key: SESSION_WAITING_TITLE
en: Waiting for your decision
es: Espera tu decisión

key: SESSION_WAITING_EMPTY
en: nothing is waiting on you
es: nada espera tu decisión

key: SESSION_INPROGRESS_TITLE
en: In progress
es: En curso

key: SESSION_INPROGRESS_EMPTY
en: nothing in progress
es: nada en curso

key: SESSION_QUEUE_TITLE
en: Queued
es: En cola

key: SESSION_CHECKS_TITLE
en: Checks
es: Chequeos

key: SESSION_CHECKS_EMPTY
en: no findings
es: sin hallazgos

key: SESSION_MORE
en: and %s more
es: y %s más

key: SESSION_CHECK_UNCOMMITTED
en: uncommitted: %s files · %s
es: sin commitear: %s archivos · %s

key: SESSION_CHECK_NO_TREE
en: missing tree.md — the scan does not know which paths to walk
es: falta tree.md — el barrido no sabe qué rutas recorrer

key: SESSION_CHECK_LANGUAGE_NOT_DECLARED
en: language not declared in operator.md — assuming en
es: language: no declarado en operator.md — se asume en

key: SESSION_CHECK_MOUNTS_TABLE_MISSING
en: declared table not found: %s — the scan covers only the brain
es: tabla declarada no encontrada: %s — el arranque cubre solo el brain

key: SESSION_CHECK_MOUNT_ROW_UNREADABLE
en: unreadable row: %s — could not read the mount
es: fila ilegible: %s — no se pudo leer el montaje

key: SESSION_CHECK_MOUNT_UNREACHED
en: mount not reached: %s — declared at %s, no local checkout
es: montaje no alcanzado: %s — declarado en %s, sin checkout local

key: SESSION_CHECK_MISSING_FILE
en: missing %s
es: falta %s

key: SESSION_READ_MISSING
en: missing: %s
es: falta: %s

key: SESSION_IDENTITY_DIAG
en: identity %s/%s · resolver %s rows
es: identidad %s/%s · resolver %s filas

key: SESSION_IDENTITY_SIMPLE
en: identity %s/%s
es: identidad %s/%s

key: SESSION_WAITING_IDENTITY_OVER
en: %s — %s · summarize the history or split into context/
es: %s — %s · resumir la historia o partir a context/

key: SESSION_CHECK_ROLE_NOT_ACTIVATED
en: %s: %s — the role does not activate
es: %s: %s — el rol no se activa

key: SESSION_CHECK_CAPABILITY_MISSING
en: capability not installed: position role "%s"%s
es: capacidad no instalada: rol de posición "%s"%s

key: SESSION_UNKNOWN_STATUS
en: unknown status: %s
es: estado desconocido: %s

key: SESSION_MISSING_HORIZON
en: no horizon
es: sin horizon

key: SESSION_MISSING_STATUS
en: no status
es: sin status

key: SESSION_UNCLASSIFIED
en: unclassified (%s): %s
es: sin clasificar (%s): %s

key: SESSION_WAITING_GATE
en: waiting %s
es: espera %s

key: SESSION_WAITING_YOU
en: waiting on you
es: te espera a vos

key: SESSION_BLOCKED_WITH_REASON
en: blocked: %s
es: trabada: %s

key: SESSION_BLOCKED
en: blocked
es: trabada

key: SESSION_WAITING_ON
en: waiting on %s
es: espera a %s

key: SESSION_NO_HORIZON_LABEL
en: no horizon
es: sin horizonte

key: SESSION_NO_STATUS_LABEL
en: no status
es: sin estado

key: SESSION_ROUTE_NOT_REACHED
en: %s:%s — not reached: %s
es: %s:%s — no se alcanza: %s

key: SESSION_OUTSIDE_TREE
en: no glob in tree.md reaches (%s): %s
es: ningún glob de tree.md alcanza (%s): %s

key: SESSION_BACKLOG_READY
en: backlog: %s ready of %s pending
es: backlog: %s listas de %s pendientes

key: SESSION_OLD_MARKER_LINE
en: (line %s)
es: (línea %s)

key: SESSION_INBOX_UNCLASSIFIED
en: inbox: %s unclassified
es: inbox: %s sin clasificar

key: SESSION_ORG_NOT_FOUND
en: the workspace "%s" does not exist. Here's what there is:
es: el espacio de trabajo "%s" no existe. Los que hay:

key: SESSION_NO_ORGS
en: (none)
es: (ninguno)

key: SESSION_NODE_COUNT
en: %s nodes · %s
es: %s nodos · %s

key: INSTALL_VERSION_LINE
en: AI First OS v%s
es: AI First OS v%s

key: FM_NO_FRONTMATTER
en: no frontmatter
es: sin frontmatter

key: FM_UNCLOSED
en: frontmatter left open
es: frontmatter sin cerrar

key: FM_TOO_LONG
en: frontmatter too long
es: frontmatter demasiado largo

key: BACKLOG_OLD_MARKER
en: old-format marker: %s
es: marcador en formato viejo: %s

key: OLD_KEY_LINE
en: old key: %s → %s
es: clave vieja: %s → %s

key: BACKUP_TASK
en: Remote backup pending: create the account at github.com (the operator creates it, never the agent), run `gh auth login`, and then ask any session to run `.os/core/lib/remote-backup.sh --brain .`
es: Respaldo remoto pendiente: crear la cuenta en github.com (la crea el operador, nunca el agente), correr `gh auth login`, y después pedirle a cualquier sesión que corra `.os/core/lib/remote-backup.sh --brain .`

key: REPO_INTRO
en: The body of an initiative: the specs, the decisions and the as-built of what gets built here.
en: The head —what it is for and what state it is in— lives in the brain that mounted this repo.
en: This repo reads on its own: nothing here assumes the brain is within reach.
es: El cuerpo de una iniciativa: las specs, las decisiones y el as-built de lo que se construye acá.
es: La cabeza —para qué es y en qué estado está— vive en el brain que montó este repo. Este repo se
es: lee solo: nada de acá asume que el brain esté al alcance.

key: REPO_LAYOUT_HEADING
en: Where each thing lives
es: Dónde está cada cosa

key: REPO_LAYOUT
en: | Question | Where | Lifecycle |
en: |---|---|---|
en: | How it is built | `ARCHITECTURE.md` (the as-built) | Live, overwritten |
en: | What is missing | `specs/` (+ `done/`) | Transient |
en: | What was decided and why | `decisions.md` | **Append-only**, never corrected |
en: | What we learned | `learnings/` | Live: updated or deleted |
en: | What broke, and why | `docs/postmortems/` | Dated, not overwritten |
en: | Research evidence | `docs/research/` | Dated, not overwritten |
en: | The check for each criterion | `evals/run.sh` | Live: one check per criterion |
es: | Pregunta | Dónde | Ciclo de vida |
es: |---|---|---|
es: | Cómo está construido | `ARCHITECTURE.md` (el as-built) | Vivo, se pisa |
es: | Qué falta | `specs/` (+ `done/`) | Transitorio |
es: | Qué se decidió y por qué | `decisions.md` | **Append-only**, nunca se corrige |
es: | Qué aprendimos | `learnings/` | Vivo: se actualiza o se borra |
es: | Qué se rompió, y por qué | `docs/postmortems/` | Fechado, no se pisa |
es: | Evidencia de investigación | `docs/research/` | Fechada, no se pisa |
es: | El chequeo de cada criterio | `evals/run.sh` | Vivo: un chequeo por criterio |

key: REPO_GATES
en: - **Gate 1**: no implementation starts without an approved spec.
en: - **Gate 2**: a person merges. Agents work on branches, never push to `main` and never merge:
en:   `.claude/settings.json` denies them both commands.
en: - The PR carries the evidence of the evals. Whoever reviews it reports nothing they cannot quote
en:   literally with `file:line`, and nothing without naming what breaks.
es: - **Gate 1**: ninguna implementación arranca sin spec aprobada.
es: - **Gate 2**: el merge lo hace una persona. Los agentes trabajan en ramas, nunca pushean a `main`
es:   ni mergean: `.claude/settings.json` les niega los dos comandos.
es: - El PR lleva la evidencia de los evals. El que lo revisa no reporta nada que no pueda citar
es:   textualmente con `archivo:línea`, ni nada sin nombrar qué se rompe.

key: REPO_DOD
en: - The spec's criteria pass their evals, with the evidence recorded. Claiming with no evidence is
en:   not done.
en: - No regression on the critical path.
en: - No code from abandoned attempts in the diff.
en: - No secrets in code, docs or commits.
en: - `ARCHITECTURE.md` updated if it changed; new decisions in `decisions.md`; whatever serves the
en:   next time, in `learnings/`.
en: - Spec archived in `specs/done/`. Ready to ASK for the merge — never autonomous.
es: - Los criterios de la spec pasan sus evals, con la evidencia registrada. Afirmar sin evidencia no
es:   es done.
es: - Sin regresión del camino crítico.
es: - Sin código de intentos abandonados en el diff.
es: - Sin secretos en código, docs ni commits.
es: - `ARCHITECTURE.md` actualizado si cambió; decisiones nuevas en `decisions.md`; lo que sirva para
es:   la próxima vez, en `learnings/`.
es: - Spec archivada en `specs/done/`. Listo para PEDIR el merge — nunca autónomo.

key: REPO_WRITING_HEADING
en: How it is written
es: Cómo se escribe

key: REPO_WRITING
en: **The primary reader of these documents is an agent in another session, with nothing of the
en: conversation that produced them.**
en:
en: 1. **Each rule is stated in a single place.** The other documents reference it by path.
en: 2. **Numbers and checks go isolated**, never embedded in a sentence.
en: 3. **No narrative connectors**: they do not instruct and they take up context.
en:
en: A decision has four fields and no more:
en:
en: ```
en: ## DATE · [scope] Title that states the rule, not the topic
en:
en: **What is decided**: one or two lines. The rule, with no argument.
en: **Why**: one paragraph. One.
en: **Replaces**: only if it applies, naming the previous decision.
en: **What would invalidate it**: the condition that would make it false.
en: ```
en:
en: File names, commands and code in English. The product's language rule is stated once, in the
en: constitution of the product repo that ships `.os/core` — `CLAUDE.md` at its root — and is not
en: repeated here.
es: **El lector primario de estos documentos es un agente en otra sesión, sin nada de la conversación
es: que los produjo.**
es:
es: 1. **Cada regla se enuncia en un solo lugar.** Los demás documentos la referencian por ruta.
es: 2. **Los números y los chequeos van aislados**, nunca embebidos en una oración.
es: 3. **Sin conectores narrativos**: no instruyen y ocupan contexto.
es:
es: Una decisión tiene cuatro campos y ninguno más:
es:
es: ```
es: ## FECHA · [ámbito] Título que enuncia la regla, no el tema
es:
es: **Qué se decide**: una o dos líneas. La regla, sin argumento.
es: **Por qué**: un párrafo. Uno.
es: **Reemplaza a**: solo si aplica, nombrando la decisión anterior.
es: **La invalidaría**: la condición que la haría falsa.
es: ```
es:
es: Nombres de archivo, comandos y código en inglés. La regla del idioma del producto se enuncia una
es: sola vez, en la constitución del repo del producto que publica `.os/core` —`CLAUDE.md` en su
es: raíz— y no se repite acá.

key: REPO_GOTCHAS
en: <!-- What trips you up and cannot be deduced by opening a file goes here, one line each. What an
en:      `ls` already answers does not. It is born empty on purpose. -->
es: <!-- Lo que hace tropezar y no se deduce abriendo un archivo va acá, una línea cada cosa. Lo que
es:      un `ls` ya contesta, no. Nace vacío a propósito. -->

key: REPO_ARCHITECTURE_TITLE
en: Architecture (as-built)
es: Arquitectura (as-built)

key: REPO_ARCHITECTURE_INTRO
en: > Newborn repo: this gets written when the first implementation exists. It describes what is
en: > built, never what is planned — what is missing lives in `specs/`.
es: > Repo recién nacido: se escribe cuando exista la primera implementación. Describe lo construido,
es: > nunca lo planeado — lo que falta vive en `specs/`.

key: REPO_DECISIONS_TITLE
en: Decisions
es: Decisiones

key: REPO_DECISIONS_INTRO
en: > Append-only: nothing here gets corrected. Four fields per decision — the format is in
en: > `CLAUDE.md`.
en: >
en: > It is born with no entries.
es: > Append-only: acá no se corrige nada. Cuatro campos por decisión — el formato está en
es: > `CLAUDE.md`.
es: >
es: > Nace sin entradas.

key: REPO_EVALS_INTRO
en: The repo's evals — one check per acceptance criterion of each spec. Run: `evals/run.sh`
es: Los evals del repo — un chequeo por criterio de aceptación de cada spec. Se corre: `evals/run.sh`

key: REPO_EVALS_SLOT
en: Each spec adds its checks here, one function per criterion, and calls them below.
es: Cada spec suma acá sus chequeos, una función por criterio, y los llama abajo.

key: REPO_EVALS_SUMMARY
en: %s pass · %s fail
es: %s pasan · %s fallan

key: REPO_FIRST_COMMIT
en: the repo is born
es: nace el repo

key: MOUNT_NOTHING_WRITTEN
en: nothing was written.
es: no se escribió nada.

key: MOUNT_NO_PYTHON3
en: python3 is missing: install it from the official channel (macOS: run `xcode-select --install`, the same command that brings git; Windows: python.org; Linux: your distro's package manager) and run this same command again.
es: falta python3: instalalo desde el canal oficial (macOS: correr `xcode-select --install`, el mismo comando que trae git; Windows: python.org; Linux: el gestor de paquetes de la distro) y volvé a correr este mismo comando.

key: MOUNT_HEAD_ABSOLUTE
en: the head is named relative to the brain: %s
es: la cabeza se nombra relativa al brain: %s

key: MOUNT_HEAD_ESCAPES
en: the head cannot leave the brain: %s
es: la cabeza no puede salir del brain: %s

key: MOUNT_HEAD_MISSING
en: the head does not exist: %s
en: mount-repo mounts a repo onto a head that already exists; it does not invent one.
es: no existe la cabeza: %s
es: mount-repo monta un repo sobre una cabeza que ya existe; no la inventa.

key: MOUNT_HEAD_FM_BROKEN
en: %s: %s — nothing gets written over a frontmatter that cannot be understood
es: %s: %s — no se escribe sobre un frontmatter que no se entiende

key: MOUNT_HEAD_REPO_CONFLICT
en: conflict: %s already declares repo: %s
es: conflicto: %s ya declara repo: %s

key: MOUNT_HEAD_REPO_CONFLICT_TAIL
en: the remote asked for is %s. Which one stays belongs to the operator: nothing was written.
es: el remote pedido es %s. Cuál queda es del operador: no se escribió nada.

key: MOUNT_REMOTE_DOWN
en: the remote does not answer: %s
es: el remote no responde: %s

key: MOUNT_CLONE_ROOT_DECLARED
en: the clone root was already declared: %s — that one is used and --clone-root is ignored
es: la raíz de clonado ya estaba declarada: %s — se usa esa y se ignora --clone-root

key: MOUNT_CLONE_ROOT_MISSING
en: the clone root is missing: where this machine's checkouts live.
en: It is asked once and stays written in %s. There is no default: nothing was written.
es: falta la raíz de clonado: dónde viven los checkouts de esta máquina.
es: Se pregunta una vez y queda escrita en %s. No hay default: no se escribió nada.

key: MOUNT_CLONE_ROOT_RELATIVE
en: the clone root belongs to the environment and goes absolute: %s
es: la raíz de clonado es del entorno y va absoluta: %s

key: MOUNT_CLONE_ROOT_IN_BRAIN
en: the clone root falls inside the brain: %s
en: the body is cloned flat and outside. Nothing was written.
es: la raíz de clonado cae adentro del brain: %s
es: el cuerpo se clona plano y afuera. No se escribió nada.

key: MOUNT_CLONE_ROOT_IN_REPO
en: the clone root falls inside another repo: %s
en: the body is cloned flat, never nested. Nothing was written.
es: la raíz de clonado cae adentro de otro repo: %s
es: el cuerpo se clona plano, nunca anidado. No se escribió nada.

key: MOUNT_NAME_UNDERIVABLE
en: the checkout name could not be derived from the remote: %s
es: no se pudo derivar el nombre del checkout desde el remote: %s

key: MOUNT_TITLE
en: Mount
es: Montaje

key: MOUNT_CHECKOUT_ALREADY
en:   checkout: it was already at %s — it is not cloned again
es:   checkout: ya estaba en %s — no se vuelve a clonar

key: MOUNT_CHECKOUT
en:   checkout: %s
es:   checkout: %s

key: MOUNT_DEST_NOT_REPO
en: the checkout path exists and is not a repo: %s
es: la ruta del checkout existe y no es un repo: %s

key: MOUNT_CLONE_ROOT_UNWRITABLE
en: the clone root could not be created: %s
es: no se pudo crear la raíz de clonado: %s

key: MOUNT_CLONE_FAILED
en: cloning %s into %s failed
es: falló el clonado de %s en %s

key: MOUNT_HEAD_REPO_ALREADY
en:   %s: repo: was already there
es:   %s: repo: ya estaba

key: MOUNT_HEAD_REPO_WRITTEN
en:   %s: repo: %s
es:   %s: repo: %s

key: MOUNT_HEAD_REPO_WRITE_FAILED
en: repo: could not be written into %s
es: no se pudo escribir repo: en %s

key: MOUNT_TABLE_CLONE_ROOT_ADDED
en:   %s: clone-root: %s — the table did not declare it
es:   %s: clone-root: %s — la tabla no lo declaraba

key: MOUNT_TABLE_MANY_ROWS
en:   %s: %s rows: %s — the last one is used
es:   %s: %s filas: %s — se usa la última

key: MOUNT_TABLE_LINE_LIST
en: line %s
es: línea %s

key: MOUNT_TABLE_LINE_AND
en: and
es: y

key: MOUNT_TABLE_ROW_ALREADY
en:   %s: the row was already there (line %s)
es:   %s: la fila ya estaba (línea %s)

key: MOUNT_TABLE_BORN
en:   %s was born with this piece of data
es:   %s nació con este dato

key: MOUNT_SETTINGS_ADDED
en:   %s: additionalDirectories: %s
es:   %s: additionalDirectories: %s

key: MOUNT_SETTINGS_ALREADY
en:   %s: additionalDirectories: was already there
es:   %s: additionalDirectories: ya estaba

key: MOUNT_SETTINGS_INVALID
en:   %s: not valid JSON — it was not modified (%s)
es:   %s: no es JSON válido — no se modificó (%s)

key: MOUNT_GITIGNORE_DECLARED
en:   .gitignore — entry declared: %s
es:   .gitignore — entrada declarada: %s

key: MOUNT_TREE_GLOB_DECLARED
en:   tree.md — glob declared: %s
es:   tree.md — glob declarado: %s

key: MOUNT_TREE_MISSING
en:   tree.md is missing — the glob "%s" was left undeclared
es:   falta tree.md — el glob "%s" quedó sin declarar

key: MOUNT_NEW_HINT
en: the repo does not exist yet? --new creates it from the product's scaffold and mounts it, in a single run.
es: ¿el repo todavía no existe? --new lo crea desde la plantilla del producto y lo monta, en una sola corrida.

key: MOUNT_NEW_ALREADY_BORN_HINT
en: the repo is already born locally at %s: what is missing is creating the remote and pushing it.
es: el repo ya nació local en %s: falta crear el remoto y pushearlo.

key: MOUNT_NEW_REMOTE_ALIVE
en: the remote answers: %s — there is nothing to create: it is mounted without --new.
es: el remote responde: %s — no hay nada que crear: se monta sin --new.

key: MOUNT_NEW_DEST_EXISTS
en: the checkout path already exists and it is not this remote's repo: %s — --new does not write over what is already there.
es: la ruta del checkout ya existe y no es el repo de este remote: %s — --new no escribe sobre lo que ya está.

key: MOUNT_NEW_ROW_ELSEWHERE
en: %s points this remote at %s (line %s), outside the clone root — with --new the repo is born at %s. Fix the row and run it again.
es: %s apunta este remote a %s (línea %s), fuera de la raíz de clonado — con --new el repo nace en %s. Corregí la fila y volvé a correrlo.

key: MOUNT_NEW_FAILED
en: the birth of the repo failed: %s
es: falló el nacimiento del repo: %s

key: MOUNT_NEW_CLEANED
en: what had been created in %s was removed.
es: se borró lo que se había creado en %s.

key: MOUNT_NEW_LEFTOVER
en: %s could not be removed: that is what the failed birth left behind.
es: no se pudo borrar %s: eso es lo que quedó del nacimiento fallido.

key: MOUNT_NEW_BORN
en:   born: %s — scaffold, first commit on main, origin declared
es:   nació: %s — plantilla, primer commit en main, origin declarado

key: MOUNT_NEW_ALREADY_BORN
en:   born: it was already at %s with this origin — it is not born again
es:   nació: ya estaba en %s con este origin — no vuelve a nacer

key: MOUNT_NEW_GENERIC_IDENTITY
en:   first commit signed with a generic identity — configure git (user.name, user.email) for the ones that follow
es:   primer commit firmado con una identidad genérica — configurá git (user.name, user.email) para los que siguen

key: MOUNT_NEW_REMOTE_GH
en:   the remote does not exist yet: gh is authenticated — these two are run by the operator, never by this script
es:   el remoto todavía no existe: gh autenticado — estos dos los corre el operador, nunca este script

key: MOUNT_NEW_REMOTE_GH_CREATE
en:     gh repo create %s --private
es:     gh repo create %s --private

key: MOUNT_NEW_REMOTE_MANUAL
en:   the remote does not exist yet: create it at your provider as %s (private), and then push it
es:   el remoto todavía no existe: crealo en tu proveedor como %s (privado), y después pusheálo

key: MOUNT_NEW_REMOTE_PUSH
en:     git -C '%s' push -u origin main
es:     git -C '%s' push -u origin main

key: WS_LAYOUT_BOTH
en: this brain has both a `workspaces` folder and an `orgs` folder — pick one before running this command: move the one you are not keeping, or run `rename-workspaces` to adopt the current name.
es: este brain tiene una carpeta `workspaces` y una carpeta `orgs` a la vez — elegí una antes de correr este comando: movés la que no vas a usar, o corré `rename-workspaces` para adoptar el nombre actual.

key: WS_LAYOUT_MISMATCH_WS
en: the tree (`tree.md`) declares the `workspaces` folder but this brain only has `orgs` on disk — the tree is out of sync with the folder; fix `tree.md` or the folder before running this command again.
es: el árbol (`tree.md`) declara la carpeta `workspaces` pero este brain solo tiene `orgs` en disco — el árbol quedó desincronizado de la carpeta; arreglá `tree.md` o la carpeta antes de volver a correr este comando.

key: WS_LAYOUT_MISMATCH_ORGS
en: the tree (`tree.md`) declares the `orgs` folder but this brain only has `workspaces` on disk — the tree is out of sync with the folder; fix `tree.md` or the folder before running this command again.
es: el árbol (`tree.md`) declara la carpeta `orgs` pero este brain solo tiene `workspaces` en disco — el árbol quedó desincronizado de la carpeta; arreglá `tree.md` o la carpeta antes de volver a correr este comando.

key: INSTALL_WS_OLD_NAME
en: this brain uses the previous name of the workspaces folder (`orgs/`) — it keeps working as is; to adopt the current name (`workspaces/`), run `rename-workspaces`.
es: este brain usa el nombre anterior de la carpeta de espacios de trabajo (`orgs/`) — sigue funcionando tal cual; para adoptar el nombre actual (`workspaces/`), corré `rename-workspaces`.

key: WS_RENAME_NOTHING
en: nothing to rename: this brain already uses the `workspaces` folder.
es: nada que renombrar: este brain ya usa la carpeta `workspaces`.

key: WS_RENAME_MOVED
en: moved the `orgs` folder to `workspaces`.
es: se movió la carpeta `orgs` a `workspaces`.

key: WS_RENAME_REWROTE
en: rewrote the `orgs` prefix to `workspaces` in:
es: se reescribió el prefijo `orgs` por `workspaces` en:

key: WS_RENAME_LEFTOVER
en: still carrying the `orgs` prefix — left untouched, review by hand:
es: todavía tienen el prefijo `orgs` — quedaron sin tocar, para revisar a mano:

key: WS_RENAME_NONE_LEFT
en: no other file carries the `orgs` prefix.
es: ningún otro archivo tiene el prefijo `orgs`.

key: HEADS_RENAME_NOTHING
en: nothing to rename: every node of this brain already keeps its head in `README.md`.
es: nada que renombrar: todos los nodos de este brain ya tienen su cabeza en `README.md`.

key: HEADS_RENAME_BOTH
en: something is already sitting where a file would move — nothing was touched, not one file; keep one of each pair before running this command again:
es: ya hay algo donde un archivo tendría que moverse — no se tocó nada, ni un archivo; dejá uno de cada par antes de volver a correr este comando:

key: HEADS_RENAME_UNKNOWN
en: this brain's tree (`tree.md`) declares no head at all — there is nothing this command can recognize as a node, and it will not guess: fix the tree before running it again.
es: el árbol (`tree.md`) de este brain no declara ninguna cabeza — no hay nada que este comando pueda reconocer como nodo, y no lo adivina: arreglá el árbol antes de volver a correrlo.

key: HEADS_RENAME_MOVED
en: heads moved into their node's folder:
es: cabezas movidas adentro de la carpeta de su nodo:

key: HEADS_RENAME_RESEARCH
en: dated documents moved from `context/` to `research/`:
es: documentos fechados movidos de `context/` a `research/`:

key: HEADS_RENAME_REWROTE
en: rewrote the head paths in:
es: se reescribieron las rutas de cabeza en:

key: HEADS_RENAME_LEFTOVER
en: still name a head in the previous shape — left untouched, review by hand:
es: todavía nombran una cabeza en la forma anterior — quedaron sin tocar, para revisar a mano:

key: HEADS_RENAME_NONE_LEFT
en: no other file names a head in the previous shape.
es: ningún otro archivo nombra una cabeza en la forma anterior.
