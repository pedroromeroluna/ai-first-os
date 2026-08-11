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

key: BACKUP_TASK
en: Remote backup pending: create the account at github.com (the operator creates it, never the agent), run `gh auth login`, and then ask any session to run `.os/core/lib/remote-backup.sh --brain .`
es: Respaldo remoto pendiente: crear la cuenta en github.com (la crea el operador, nunca el agente), correr `gh auth login`, y después pedirle a cualquier sesión que corra `.os/core/lib/remote-backup.sh --brain .`
