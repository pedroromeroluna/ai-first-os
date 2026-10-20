# AI First OS — cómo funciona este sistema

> [!NOTE] Este archivo es el manual del sistema
> Es parte del producto y está enlazado desde él, así que se mantiene solo: cuando el sistema se
> actualiza, este texto se actualiza con él. Nada de lo que escribís vive acá: lo que edites en este
> archivo lo pisa la próxima actualización. Tus cosas viven en los otros archivos, y este manual dice
> cuáles son.

## La idea en una línea

**Tu agente lee tu contexto de archivos, trabaja con vos en la sesión y lo que importa queda
escrito** — nunca adentro de la memoria de un chat.

Los archivos son tuyos: texto plano, en tu carpeta, legibles sin este sistema instalado. Lo que el
sistema agrega es dónde va cada cosa y quién la vuelve a leer.

## Dos nombres, dos cosas

- **AI First OS** es el software: los skills, el contrato de sesión, los agentes. Se instala y se
  actualiza, y no guarda nada tuyo.
- **Tu brain** es esta carpeta: tu identidad, tu voz y tu trabajo. Es lo que el sistema opera y lo
  único que es tuyo.

La analogía es un sistema operativo y tu disco: el OS se actualiza; tu brain no se toca. Por eso
no se "instala un brain" — se instala el OS, y tu brain nace una sola vez, con la entrevista.

## Qué ves en esta carpeta

**En la raíz de esta carpeta se ven cuatro cosas. Todo lo demás está oculto, porque solo lo lee el
sistema.** La raíz tiene la maquinaria del sistema y tu cuenta — nunca trabajo. Tu trabajo propio es
un espacio de trabajo.

| En la carpeta | Qué es | Quién lo edita |
|---|---|---|
| `AGENTS.md` | El reglamento que sigue toda sesión antes de contestar. Es un enlace al producto | Nadie: está en solo lectura a propósito |
| `HOW-IT-WORKS.md` | Este manual, en tu idioma. También es un enlace al producto | Nadie |
| `account/` | Vos: quién sos, cómo querés que te contesten y cómo escribís | Vos |
| `workspaces/` | Tu trabajo: una carpeta por espacio de trabajo — el tuyo, una empresa, un cliente | Vos y el agente, juntos |

Adentro de `account/`:

| Archivo | Qué contesta |
|---|---|
| `account/operator.md` | Quién sos y cómo querés que te contesten. **Tus reglas propias para el agente van acá** |
| `account/voice/voice.md` | Cómo escribís cuando escribís bien. El agente la lee cuando está por escribir algo en tu nombre, no al arrancar cada sesión |

### El reglamento, y el aviso de arriba

`AGENTS.md` y `.claude/CLAUDE.md` son dos enlaces al mismo archivo, así cada agente (Claude Code,
Codex, Cursor, OpenCode) encuentra el reglamento donde lo busca. El archivo abre con un bloque
`[!WARNING]` que dice que no se edita, por qué, y que tus reglas van en `account/operator.md`. El
aviso, en español, dice:

> [!WARNING]
> **No edites este archivo.** Es el reglamento del sistema, igual para todos los que lo usan, y está
> en solo lectura a propósito. Si lo editás igual, tu cambio se pierde con la próxima actualización,
> y hasta entonces tus sesiones siguen un reglamento que nadie revisó. Tus reglas propias van en
> `account/operator.md`.

La razón es simple: ese archivo es el mismo para todos, así que editarlo en tu copia significa que tus
cambios se pierden con la próxima actualización. En una copia instalada el sistema además le saca el
permiso de escritura, para que el editor te frene antes de empezar.

> [!TIP] Tus reglas propias van en account/operator.md
> **Tus reglas propias nunca van en el reglamento.** Van en `account/operator.md`. Si esta carpeta
> ya tenía un archivo de reglas tuyo cuando se instaló el sistema, instalar con `--adopt` agrega
> su contenido al final de `account/operator.md`, bajo un título que dice de dónde viene, y deja
> el enlace del sistema en su lugar. Nada de lo que escribiste se pierde.

### Qué es tuyo para editar, y qué no

- **Tuyo:** `account/` (los dos archivos), todo lo que está adentro de `workspaces/` — las cabezas de
  tus espacios de trabajo, iniciativas y productos, sus `resources/`, `context/` y `research/` — y
  cualquier skill que escribas vos.
- **No es tuyo:** `AGENTS.md`, `HOW-IT-WORKS.md` y `.claude/CLAUDE.md` (enlaces al producto), `.os/`
  (enlaces a las herramientas del producto) y todo **archivo generado**.
- **Se edita poco, y con cuidado:** `.system/`. Es la maquinaria que necesita la raíz para funcionar:
  `tree.md` (el mapa de las rutas que recorre un barrido), `resolver.md` (la tabla de capacidades y la
  herramienta que resuelve cada una; tus filas ganan sobre las del producto) y, en una máquina que
  monta repos, `mounts.md` (la tabla del entorno: qué repos están montados, y dónde). Está oculta
  porque nadie necesita abrirla en un día normal: la lee el sistema, y los comandos que crean algo (un
  espacio de trabajo, un producto) le suman sus propias líneas.

### Archivos generados

Un **archivo generado** es uno que el sistema escribe por vos y reescribe solo. Su frontmatter dice
`generated: true`, y la cabecera de abajo dice de qué archivos sale. El `index.md` de un producto, una
cuenta o un canal es uno: una tabla con las iniciativas y las listas de decisiones y aprendizajes
que tratan de ese producto. **No lo edites**: tu edición desaparece en el próximo arranque de sesión. Editá la fuente —
la iniciativa, la decisión o el aprendizaje— y el índice la sigue. Un archivo generado no se sube a
git: cada copia del brain arma el suyo.

### Cómo arranca una sesión

1. Nombrás el espacio de trabajo en el que vas a trabajar.
2. El agente corre el **barrido** y la **lectura de arranque** antes de contestar: primero
   `account/operator.md`, después la cabeza del espacio de trabajo y su propia tabla de herramientas,
   su glosario y su mapa de contextos si los tiene, sus decisiones clave, y las tablas de
   herramientas del sistema y de la raíz. No carga tu voz: la lee cuando va a escribir algo en tu
   nombre.
3. Elegís un foco, y recién ahí se carga el cuerpo de esa iniciativa o de ese producto.

El detalle de cada paso está en el ciclo de una sesión, más abajo.

**Tu trabajo propio es un espacio de trabajo, `personal`** — el que trae todo brain al nacer, al lado
de cualquier empresa o cliente que sumes después. Hay un solo primitivo, repetido a todas las
alturas, para cada espacio de trabajo: el **nodo**. Todos los nodos contestan las mismas preguntas, y
cada pregunta es un archivo:

| Archivo | Qué contesta |
|---|---|
| `workspaces/<nombre>/README.md` | Qué es ese espacio de trabajo y qué oficio tuyo activa |
| `workspaces/<nombre>/<tipo>/<slug>/README.md` | Qué es un nodo de memoria, para quién, y qué se sabe de él — `products/` es el único tipo que el sistema trae con herramienta propia |
| `workspaces/<nombre>/people/<slug>.md` | Quién es una persona, su organización y su cargo, su contacto y cómo conviene tratarla — contenido del espacio de trabajo, nunca un nodo: el barrido nunca lo lee |
| `workspaces/<nombre>/initiatives/<slug>/README.md` | El trabajo: una cabeza por iniciativa, con su estado, su horizonte y, si hace falta, `about:` con el producto, curso, canal o cuenta del que trata — uno, o varios como `[<ruta>, <ruta>]` |
| `workspaces/<nombre>/initiatives/<slug>/backlog.md` | Las tareas de esa iniciativa, y solo de esa — toda tarea vive en una iniciativa; las de un producto sin un proyecto puntual van a su iniciativa permanente |
| `workspaces/<nombre>/decisions/<fecha>-<slug>.md` | Una decisión por archivo, con el porqué y qué la volvería falsa, y `about:` cuando trata de un producto, un curso, un canal o una cuenta; `decisions/index.md` las lista todas, generado |
| `workspaces/<nombre>/learnings/<slug>.md` | Un aprendizaje por archivo, incluido lo que se intentó y no cerró; `learnings/index.md` los lista todos, generado |

**Todo nodo tiene la misma forma: una carpeta con el nombre de la cosa, y `README.md` adentro.** El
nombre aparece una sola vez —la carpeta—, la cabeza se llama siempre igual, y cualquiera que abra la
carpeta sabe por dónde empezar.

> [!TIP] Un brain de antes de esta forma puede tener trabajo escrito directamente en su raíz
> `migrate-root.sh` lo mueve a `workspaces/personal`, creando ese espacio de trabajo primero si
> todavía no existe — corre una vez, a tu pedido, nunca solo.

**Un nodo de memoria es memoria, una iniciativa es empuje.** Un nodo de memoria guarda qué es, para
quién y qué se sabe de él; una iniciativa guarda su estado, su horizonte y cuándo cierra. Un nodo de
memoria puede sobrevivir a todas las iniciativas que se construyeron a su alrededor, y una iniciativa
nunca necesita uno para existir.

Un archivo nace la primera vez que tiene algo real que guardar. Un archivo vacío no es estructura:
es ruido que hay que leer todas las sesiones.

### Nodos de memoria: cualquier carpeta puede ser un tipo

**La carpeta es el tipo.** No hay ningún campo `type:`: la ruta ya dice de qué tipo de cosa se trata.
`products/` es el único tipo que el sistema trae con herramienta propia (`prd`, que escribe su capa
estratégica). Cualquier carpeta hermana de nodos que guarden memoria en vez de empuje funciona igual:
`accounts/` para cuentas de clientes, `channels/` para los canales por los que publicás, o un nombre
que inventes vos.

`new-memory --type <tipo>` crea un tipo la primera vez que se usa —la carpeta más las cinco líneas
que necesita en `.system/tree.md`— y le suma su primer nodo. El mismo comando con el mismo `--type` y otro
`--slug` suma otro nodo a un tipo que ya existe —otra cuenta, otro canal— sin líneas nuevas ni
duplicadas. Un tipo que es tuyo, no de un cliente, vive adentro de tu propio espacio de trabajo
(`personal`) — la raíz nunca tiene uno, porque es solo maquinaria.

Un tipo que el sistema trae se nombra en inglés —hoy, solo `products`—. Un tipo que inventás se
nombra como quieras: es contenido de tu brain, no un componente del sistema. Tres nombres para
arrancar, si preferís un catálogo antes que inventar uno: `products` (qué construís, para quién),
`accounts` (una relación con un cliente o una empresa), `channels` (dónde publicás). Inventar el tuyo
—cualquier cosa que sea memoria y no empuje— es igual de legítimo: la carpeta más sus líneas en
`.system/tree.md`, y un `context/` que llenás a mano hasta que exista una herramienta propia como `prd`, si
alguna vez existe.

### Las personas, y la relación que las nombra

Una persona nunca es un nodo. `workspaces/<nombre>/people/<slug>.md` es contenido, la misma clase que
el `resources/voice.md` de un espacio de trabajo o el `research/` de un producto: el árbol lo alcanza y lo
cuenta, y ni el barrido ni un foco lo abren salvo que la sesión lo nombre por ruta. Quién es, para
quién trabaja y su cargo, cómo contactarla y cómo conviene tratarla viven todos en ese archivo, escrito
a mano desde `core/templates/person.md` — ningún comando lo crea, y su frontmatter nunca se chequea
contra una lista fija: una clave de más no es un hallazgo, y este manual no promete que lo sea.

**Lo que ata a una persona con un nodo es una línea en el nodo, nunca un campo de la persona.** La
misma persona puede decidir una iniciativa y ser parte del equipo del espacio de trabajo a la vez, y
escribir las dos relaciones en el archivo de la persona obligaría a mantener dos copias sincronizadas
a mano en vez de una. La línea lleva la ruta de la persona entre backticks, su rol, y desde cuándo:

`` `people/<slug>.md` · <rol> · desde <fecha> ``

Nada la analiza sola —un chequeo que abriera el cuerpo de cada iniciativa para verificar una ruta
volvería a pagar el costo que el barrido existe para evitar— y se escribe en tres alturas, cada una su
propia sección:

- **Stakeholders de una iniciativa** — su propia sección `## Stakeholders`, para quien decide o le
  afecta ese trabajo puntual.
- **Stakeholders de una entidad** — la misma sección en la cabeza de un producto, una cuenta o un
  canal, para quien es stakeholder de la cosa misma, no de una iniciativa construida a su alrededor.
- **Equipo del espacio de trabajo** — una sección `## Team` en la cabeza del espacio de trabajo, para
  quien es parte de él de forma permanente, sin atarse a ninguna iniciativa.

## El ciclo de una sesión

> [!EXAMPLE] Una sesión de punta a punta
> 1. **Arranque.** Nombrás el espacio de trabajo —tu trabajo propio es `personal`, el que trae todo
>    brain al nacer— y el agente corre el **barrido** antes de contestar nada: qué espera tu decisión,
>    qué está en curso, qué está trabado y por quién, qué hay en cola y qué encontraron los chequeos.
>    Después elegís foco, y recién ahí se carga el cuerpo de esa iniciativa.
> 2. **Trabajo.** Cada pedido se rutea a su herramienta por el resolver. Nada se activa solo, y
>    ninguna acción irreversible —mandar, publicar, firmar, mergear— corre sin tu sí.
> 3. **Captura.** Lo que aparece al vuelo se archiva donde corresponde sin cortar el hilo, y la
>    respuesta dice dónde quedó.
> 4. **Cierre.** Dos preguntas —qué no puede perderse y qué casi funcionó— y un veredicto en cuatro
>    partes: qué se archivó, qué no, qué fila podría ganar el resolver y por dónde retomar. Nunca un
>    "listo" a secas: un cierre que solo dice que terminó no se distingue de uno que perdió algo.

## Living Memory: encontrar lo que el foco no carga

El barrido y el foco solo cargan una lista fija de archivos, más un salto por `about:`. Una decisión
escrita meses atrás en otro espacio de trabajo es real, pero nada la saca a la luz sola — hasta que
vos, o el agente en tu nombre, se la pedís a `recall`.

`recall` busca en todo lo que el árbol alcanza, partido en entradas —un encabezado y su cuerpo, o un
ítem de lista, nunca un archivo entero de una— y devuelve las coincidencias más cercanas con su
archivo, línea y fecha, con lo vigente siempre antes de lo que un archivo dice que fue reemplazado.
`recall --expand <ruta>` muestra los vecinos inmediatos de un resultado: de qué trata, quién trata
de él, qué lo reemplazó, a qué reemplazó.

**Encuentra, no decide.** Dos resultados vigentes que dicen cosas distintas se te entregan como una
contradicción para resolver, nunca elegidos en silencio. Y es descartable: lo que busca es un
archivo chico que se reconstruye solo desde tus propios archivos, nunca algo que vos escribís o
respaldás.

## Dónde vive la maquinaria

Las herramientas —skills, scripts, agentes— viven en `.os/`, `.claude/` y `.agents/`. Esas carpetas
están ocultas en Obsidian y se ven desde la terminal, y lo que el sistema pone adentro es un
**enlace** al producto instalado: actualizar el sistema no toca tus datos, y tus datos nunca viajan
adentro del producto.

**Dónde viven los skills**, porque es lo primero que todo el mundo pregunta: los
<!--count-->veinte<!--/count--> skills del sistema están en `.os/core/skills/`, un archivo cada uno, y
se llega a ellos por el resolver — no están copiados en esta carpeta, están enlazados al producto.
Los skills de un pack están en `.agents/skills/<nombre>/SKILL.md`, una carpeta por skill, y
`.claude/skills/` tiene un enlace a cada uno, que es de donde Claude Code lee los skills; el sistema
busca primero en `.agents/skills/` y cuenta una sola vez un skill que está en las dos carpetas.
Cualquier skill que escribas vos va al lado, como carpeta común en `.claude/skills/`.

> [!TIP] Para actualizar, pedile a cualquier sesión «actualizá el sistema»
> Para actualizar, pedile a cualquier sesión: **"actualizá el sistema"**. Con esa frase alcanza, y
> cubre las dos mitades de lo que está instalado — el sistema y los packs. Qué hace paso a paso
> está escrito una sola vez, en el `README.md` de la carpeta del producto bajo **Update**; este
> manual apunta ahí en vez de contarlo de nuevo, porque dos versiones del mismo procedimiento se
> separan.

## Qué podés pedir, y cómo

**El índice es el resolver, no tu memoria.** Pedís con tus palabras —"qué hay pendiente", "cerrá la
sesión", "capturá esto"— y el agente busca qué herramienta cubre esa capacidad. Dos archivos
contestan eso: el del producto, que viaja con el sistema, y el tuyo (`.system/resolver.md`), donde agregás
una fila cuando el agente habría elegido mal sin ella. Tus filas ganan.

El catálogo de abajo es el sistema mismo — las <!--count-->veinte<!--/count--> herramientas que vienen
con él. También podés invocar cualquiera por su nombre.

<!-- catalog: generated by scripts/manual-catalog.sh — do not edit by hand -->

**El núcleo** — las herramientas que hacen andar el sistema:

- **`archive`** — Mueve un documento al `archive/` del nodo para que el foco deje de cargarlo y pase a listarlo por nombre, reescribiendo todas las referencias que lo apuntaban — y lo trae de vuelta igual.
- **`bootstrap`** — Crea el brain desde cero — la skill de entrada.
- **`capture`** — Archiva lo que el operador tira al vuelo en el backlog de la iniciativa que lo consume, una vez que hay una iniciativa nombrada — nada se archiva sin clasificar.
- **`check-resolvable`** — Audita el grafo capacidad → herramienta de la raíz y reporta las tres fallas que puede tener — una herramienta que nadie rutea, un handoff que ninguna fila provee y una fila que apunta a una herramienta que no existe.
- **`close-session`** — Cierra la sesión repartiendo lo que produjo —decisiones, aprendizajes, pendientes, lo que quedó esperando, por dónde retomar— en los archivos canónicos del nodo cargado, y termina con un veredicto de cuatro partes que nombra lo que no se capturó.
- **`grill`** — Presiona los hechos detrás de una afirmación antes de que una decisión cierre — contrapregunta con un ejemplo concreto, intentos acotados, escape hatches, jerarquía de evidencia — y rutea lo que salga a las decisiones o al backlog del nodo cargado.
- **`migrate-layout`** — Lleva un cerebro con la forma vieja a la nueva —la cuenta en `account/`, la maquinaria en `.system/`, el reglamento de sesión en `AGENTS.md` y `.claude/CLAUDE.md`, los roles como skills, los índices de decisiones y aprendizajes escritos a mano al frontmatter de los archivos que enlazan, cada backlog en una iniciativa, los resolvers ocultos, `resources/` y `context/`— mostrando primero el plan completo y sin escribir nada hasta correrlo con `--apply`.
- **`migrate-root`** — Mueve el trabajo propio del operador de un brain que todavía lo tiene escrito directamente en la raíz —iniciativas, un tipo de nodo de memoria, backlog, decisiones, aprendizajes— al espacio de trabajo `personal` con el que todo brain nace hoy, creando ese espacio de trabajo primero si todavía no existe, reescribiendo el prefijo en todo lo que el sistema lee como estructura o ruteo, y listando lo que deja sin tocar para que el operador lo revise.
- **`mount-repo`** — Le da cuerpo a una iniciativa: escribe el remote en el frontmatter de la cabeza, clona el checkout afuera del brain —o, con --new, hace nacer el repo desde la plantilla del producto cuando todavía no existe— y registra la fila remote → ruta local en la tabla del entorno de la máquina.
- **`new-memory`** — Crea un tipo de nodo de memoria la primera vez que se usa —una carpeta más sus cinco líneas en `tree.md`— y le suma un nodo.
- **`new-product`** — Suma un producto a un espacio de trabajo que ya existe.
- **`new-spec`** — Convierte en una spec el trabajo de construcción concreto que salió de una conversación, adentro de specs/ del repo destino, con evals ejecutables por criterio, las decisiones separadas por quién las cierra y los efectos que escapan del sistema declarados.
- **`new-workspace`** — Suma un espacio de trabajo a un brain que ya existe.
- **`orchestrator`** — Activa, o retoma, una orquestadora — una sesión que le pasa el trabajo de cada tema a la sesión de ese tema y guarda lo que necesita recordar en un archivo oculto.
- **`recall`** — Busca en todo lo que `tree.md` alcanza — no solo lo que carga el arranque y el foco — y devuelve las entradas que coinciden, con archivo, línea, fecha y si cada una sigue vigente o fue reemplazada.
- **`rename-heads`** — Mueve un brain nacido antes de la forma única de nodo a esa forma — cada nodo pasa a ser una carpeta con su `README.md` adentro, cada iniciativa tiene su carpeta, y los documentos fechados de cada producto van a `research/` —, reescribiendo las rutas de cabeza en todo lo que el sistema lee como ruteo y listando lo que deja sin tocar.
- **`rename-workspaces`** — Mueve un brain que todavía usa el nombre anterior de la carpeta de espacios de trabajo al nombre actual, reescribiendo el prefijo en todo lo que el sistema lee como estructura o ruteo, y listando lo que deja sin tocar para que el operador lo revise.
- **`supersede`** — Escribe sobre un archivo la marca que dice qué otro archivo lo reemplazó, para que una sesión que abra el viejo sepa qué leer en su lugar, y audita las marcas de todo el brain — las que apuntan a un archivo que no está, las que cierran un ciclo y las cabezas reemplazadas que siguen leyéndose como trabajo abierto.
- **`sweep`** — Corre uno de los tres barridos globales sobre todos los espacios de trabajo más el trabajo propio de la raíz — qué hay pendiente, qué está trabado y por qué, o cómo va el roadmap — leyendo solo frontmatter.

<!-- /catalog -->

### Los packs: el oficio de arriba

Esas <!--count-->veinte<!--/count--> hacen andar el sistema. **El oficio —construir producto, y lo que
venga después— llega en packs**, y un pack se instala aparte, con su propio comando, adentro de
`.agents/skills/` de esta carpeta. **Un pack se ofrece, nunca se exige**: la instalación terminó
preguntándote si lo querías ahora o después, y si dijiste después la tarea está en tu backlog con el
comando adentro. Sumar otro, volver a poner uno, o tomar el que postergaste es un pedido a cualquier
sesión: **"instalá el pack `<nombre>`"**.

**Este manual no lista qué trae un pack, a propósito.** Cada pack viaja con su propio índice, y ese
índice llega con él — así la lista que leés es siempre la que tenés, nunca la que el manual se
acordaba. Pedí lo que querés con tus palabras: la sesión lee el índice de lo que esté instalado y te
rutea, o te dice que nada de lo instalado lo cubre.

## Una orquestadora, si querés una

**Es opcional y está apagada hasta que la pidas.** Una orquestadora es una sesión donde decidís qué
importa y desde donde se reparte el trabajo a las demás sesiones, una por tema. Para que exista no
cambia nada de esta carpeta: no aparece ningún archivo nuevo. Lo que necesita recordar (qué sesión
lleva cada tema, qué espera a qué) lo guarda en un archivo oculto que nunca tenés que abrir.

- **Para prenderla**, decí "quiero trabajar con una orquestadora". Te cuenta qué va a preparar y
  espera tu sí antes de hacerlo.
- **Para apagarla**, pedilo. Borra ese archivo oculto y nada más cambia.
- **Cómo querés que trabaje** va en `account/operator.md`, con tus palabras: lo que escribas ahí
  gana sobre las reglas que trae por defecto.
- **En la app de escritorio** funciona completa: abre una sesión por tema, le manda trabajo a cada
  una y ve cuánto contexto usa cada una. **En la terminal** funciona reducida: reparte trabajo, pero
  no puede abrir sesiones nuevas ni ver cuánto contexto tiene cada una. Al prenderse te dice en cuál
  estás.

## Trabajar con agentes: dos gates y un tramo autónomo

El trabajo pesado se delega a agentes que corren en segundo plano, mientras la sesión principal se
queda al timón — nunca se muda de carpeta ni pierde tu contexto.

- **`scout`** — lee fuentes (código, documentación, otra spec) y vuelve con una síntesis. No escribe
  nada: las herramientas con las que corre no le permiten tocar un archivo.
- **`complete-spec`** — implementa una spec donde cada criterio tiene su chequeo ejecutable.
- **`ambiguous-spec`** — implementa una spec con decisiones abiertas, donde hace falta juicio.

> [!EXAMPLE] Una spec de punta a punta: dos aprobaciones y un tramo autónomo
> El patrón de supervisión tiene **dos gates humanos y un tramo autónomo en el medio**: una
> persona aprueba la spec (**gate 1**) → el agente la implementa en una rama, nunca sobre la rama
> principal y nunca con un push → una persona lee la rama y la mergea (**gate 2**). Autonomía en
> el medio, control humano en los bordes.

## Capacidades dormidas: la capa de construcción

Este sistema no es solo para decidir: **también construye producto, y esa mitad queda dormida hasta
que la pidas.** No es un modo que se prende para todo el brain, ni algo que se instale de nuevo: se
**activa por iniciativa**, el día en que una deja de ser una decisión y pasa a ser algo que se
construye.

Cuando eso pasa, se despiertan dos capacidades:

- **`mount-repo`** — le da cuerpo a una iniciativa: apunta la cabeza al repositorio de código, deja
  el checkout afuera de tu carpeta y registra dónde quedó en esta máquina. Si el repositorio todavía
  no existe, el mismo comando lo hace nacer —con su constitución, sus carpetas y su primer commit— y
  te deja el comando para crear el remoto. A partir de ahí, esa iniciativa tiene dónde construirse.
- **`new-spec`** — convierte en spec el trabajo de construcción que salió de una conversación: qué
  tiene que ser cierto, cómo se verifica cada criterio, qué decisiones ya están cerradas y cuáles
  siguen abiertas con quién las cierra. Esa spec es lo que después implementa un agente, con los dos
  gates de arriba.

No hace falta que prepares nada hoy. Pedilo —"esta iniciativa se va a construir"— y las dos ya están
instaladas.

## Lo que el sistema nunca hace solo

- **Nada se activa por su cuenta.** La herramienta se elige por el resolver y se invoca explícito.
- **Ninguna acción irreversible corre sola.** Mandar, publicar, firmar y mergear se preparan y
  después se piden.
- **Lo que escribe la IA queda marcado**: 📌 literal, con el archivo y la línea de donde salió · 🔍
  inferencia · ❓ hueco. Lo que falta queda registrado como abierto, con quién lo cierra. Nunca se
  inventa.

## Cómo leer los recuadros

Los archivos del sistema usan pocos recuadros, cada uno con un solo significado:

- **Azul (nota):** qué es este archivo.
- **Consejo:** cómo hacer algo con una frase.
- **Amarillo (advertencia):** algo que se pierde o que no se edita, como un archivo generado o un
  documento reemplazado por otro.
- **Pregunta:** una decisión que sigue abierta.
- **Ejemplo:** un caso de punta a punta.
- **Rojo (peligro):** solo errores.
