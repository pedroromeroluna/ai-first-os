# AI First OS — cómo funciona este sistema

> **Este archivo es el manual del sistema y es parte del producto.** Está enlazado desde el
> producto, así que se mantiene solo: cuando el sistema se actualiza, este texto se actualiza con
> él. Nada de lo que escribís vive acá — lo que edites en este archivo lo pisa la próxima
> actualización. Tus cosas viven en los otros archivos, y este manual dice cuáles son.

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

## Todo es un nodo

Hay un solo primitivo, repetido a todas las alturas: el **nodo**. Tu trabajo propio es un nodo —la
raíz de esta carpeta— y cada **espacio de trabajo** —una empresa o cliente para el que trabajás; el
caso de un curso es uno más— es otro (`workspaces/<nombre>/`). Todos los nodos contestan las mismas
preguntas, y cada pregunta es un archivo:

| Archivo | Qué contesta |
|---|---|
| `operator.md` | Quién sos y cómo querés que te contesten |
| `voice.md` | Cómo escribís cuando escribís bien |
| `resolver.md` | Capacidad → herramienta: qué skill resuelve qué pedido |
| `tree.md` | Qué rutas recorre un barrido — el mapa del sistema |
| `workspaces/<nombre>/README.md` | Qué es ese espacio de trabajo y qué oficio tuyo activa |
| `workspaces/<nombre>/<tipo>/<slug>/README.md` | Qué es un nodo de memoria, para quién, y qué se sabe de él — `products/` es el único tipo que el sistema trae con herramienta propia |
| `initiatives/<slug>/README.md` | El trabajo: una cabeza por iniciativa, con su estado y su horizonte |
| `backlog.md` | Lo que falta y no es de ninguna iniciativa |
| `decisions.md` | Qué se decidió, por qué, y qué lo volvería falso |
| `learnings.md` | Qué se aprendió, incluido lo que se intentó y no cerró |
| `inbox.md` | Lo que no se pudo clasificar — nunca se tira en silencio |

**Todo nodo tiene la misma forma: una carpeta con el nombre de la cosa, y `README.md` adentro.** El
nombre aparece una sola vez —la carpeta—, la cabeza se llama siempre igual, y cualquiera que abra la
carpeta sabe por dónde empezar. La raíz es la excepción: su carpeta es esta, y su cabeza es
`operator.md`.

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
que necesita en `tree.md`— y le suma su primer nodo. El mismo comando con el mismo `--type` y otro
`--slug` suma otro nodo a un tipo que ya existe —otra cuenta, otro canal— sin líneas nuevas ni
duplicadas. `--root` hace que el tipo viva en la raíz de tu trabajo propio en vez de adentro de un
espacio de trabajo, igual que `channels/` puede vivir ahí para contenido que es tuyo, no de un
cliente.

Un tipo que el sistema trae se nombra en inglés —hoy, solo `products`—. Un tipo que inventás se
nombra como quieras: es contenido de tu brain, no un componente del sistema. Tres nombres para
arrancar, si preferís un catálogo antes que inventar uno: `products` (qué construís, para quién),
`accounts` (una relación con un cliente o una empresa), `channels` (dónde publicás). Inventar el tuyo
—cualquier cosa que sea memoria y no empuje— es igual de legítimo: la carpeta más sus líneas en
`tree.md`, y un `context/` que llenás a mano hasta que exista una herramienta propia como `prd`, si
alguna vez existe.

## El ciclo de una sesión

1. **Arranque.** Nombrás el ámbito —un espacio de trabajo, o tu trabajo propio— y el agente corre el
   **barrido** antes de contestar nada: qué espera tu decisión, qué está en curso, qué está trabado
   y por quién, qué hay en cola y qué encontraron los chequeos. Después elegís foco, y recién ahí se
   carga el cuerpo de esa iniciativa.
2. **Trabajo.** Cada pedido se rutea a su herramienta por el resolver. Nada se activa solo, y
   ninguna acción irreversible —mandar, publicar, firmar, mergear— corre sin tu sí.
3. **Captura.** Lo que aparece al vuelo se archiva donde corresponde sin cortar el hilo, y la
   respuesta dice dónde quedó.
4. **Cierre.** Dos preguntas —qué no puede perderse y qué casi funcionó— y un veredicto en cuatro
   partes: qué se archivó, qué no, qué fila podría ganar el resolver y por dónde retomar. Nunca un
   "listo" a secas: un cierre que solo dice que terminó no se distingue de uno que perdió algo.

## Dónde vive la maquinaria

Las herramientas —skills, scripts, agentes— viven en `.os/` y `.claude/`. Esas dos carpetas están
ocultas en Obsidian y se ven desde la terminal, y son **enlaces** al producto instalado: actualizar
el sistema no toca tus datos, y tus datos nunca viajan adentro del producto.

**Dónde viven los skills**, porque es lo primero que todo el mundo pregunta: los
<!--count-->trece<!--/count--> skills del sistema están en `.os/core/skills/`, un archivo cada uno, y
se llega a ellos por el resolver — no están copiados en esta carpeta, están enlazados al producto.
Los skills de un pack están en `.claude/skills/<nombre>/SKILL.md`, una carpeta por skill, que es de
donde tu harness lee los skills y por eso responden a su nombre. Cualquier skill que escribas vos va
al lado, como carpeta común en `.claude/skills/`.

Para actualizar, pedile a cualquier sesión: **"actualizá el sistema"**. Con esa frase alcanza, y
cubre las dos mitades de lo que está instalado — el sistema y los packs. Qué hace paso a paso está
escrito una sola vez, en el `README.md` de la carpeta del producto bajo **Update**; este manual
apunta ahí en vez de contarlo de nuevo, porque dos versiones del mismo procedimiento se separan.

## Qué podés pedir, y cómo

**El índice es el resolver, no tu memoria.** Pedís con tus palabras —"qué hay pendiente", "cerrá la
sesión", "capturá esto"— y el agente busca qué herramienta cubre esa capacidad. Dos archivos
contestan eso: el del producto, que viaja con el sistema, y el tuyo (`resolver.md`), donde agregás
una fila cuando el agente habría elegido mal sin ella. Tus filas ganan.

El catálogo de abajo es el sistema mismo — las <!--count-->trece<!--/count--> herramientas que vienen
con él. También podés invocar cualquiera por su nombre.

<!-- catalog: generated by scripts/manual-catalog.sh — do not edit by hand -->

**El núcleo** — las herramientas que hacen andar el sistema:

- **`bootstrap`** — Crea el brain desde cero — la skill de entrada.
- **`capture`** — Archiva lo que el operador tira al vuelo en el backlog que corresponde —el de un espacio de trabajo, el de la raíz, o el inbox cuando no se puede clasificar— sin abrir una discusión al respecto.
- **`check-resolvable`** — Audita el grafo capacidad → herramienta de la raíz y reporta las tres fallas que puede tener — una herramienta que nadie rutea, un handoff que ninguna fila provee y una fila que apunta a una herramienta que no existe.
- **`close-session`** — Cierra la sesión repartiendo lo que produjo —decisiones, aprendizajes, pendientes, lo que quedó esperando, por dónde retomar— en los archivos canónicos del nodo cargado, y termina con un veredicto de cuatro partes que nombra lo que no se capturó.
- **`grill`** — Presiona los hechos detrás de una afirmación antes de que una decisión cierre — contrapregunta con un ejemplo concreto, intentos acotados, escape hatches, jerarquía de evidencia — y rutea lo que salga a las decisiones o al backlog del nodo cargado.
- **`mount-repo`** — Le da cuerpo a una iniciativa: escribe el remote en el frontmatter de la cabeza, clona el checkout afuera del brain —o, con --new, hace nacer el repo desde la plantilla del producto cuando todavía no existe— y registra la fila remote → ruta local en la tabla del entorno de la máquina.
- **`new-memory`** — Crea un tipo de nodo de memoria la primera vez que se usa —una carpeta más sus cinco líneas en `tree.md`— y le suma un nodo.
- **`new-product`** — Suma un producto a un espacio de trabajo que ya existe.
- **`new-spec`** — Convierte en una spec el trabajo de construcción concreto que salió de una conversación, adentro de specs/ del repo destino, con evals ejecutables por criterio, las decisiones separadas por quién las cierra y los efectos que escapan del sistema declarados.
- **`new-workspace`** — Suma un espacio de trabajo a un brain que ya existe.
- **`rename-heads`** — Mueve un brain nacido antes de la forma única de nodo a esa forma — cada nodo pasa a ser una carpeta con su `README.md` adentro, cada iniciativa tiene su carpeta, y los documentos fechados de cada producto van a `research/` —, reescribiendo las rutas de cabeza en todo lo que el sistema lee como ruteo y listando lo que deja sin tocar.
- **`rename-workspaces`** — Mueve un brain que todavía usa el nombre anterior de la carpeta de espacios de trabajo al nombre actual, reescribiendo el prefijo en todo lo que el sistema lee como estructura o ruteo, y listando lo que deja sin tocar para que el operador lo revise.
- **`sweep`** — Corre uno de los tres barridos globales sobre todos los espacios de trabajo más el trabajo propio de la raíz — qué hay pendiente, qué está trabado y por qué, o cómo va el roadmap — leyendo solo frontmatter.

<!-- /catalog -->

### Los packs: el oficio de arriba

Esas <!--count-->trece<!--/count--> hacen andar el sistema. **El oficio —construir producto, y lo que
venga después— llega en packs**, y un pack se instala aparte, con su propio comando, adentro de
`.claude/skills/` de esta carpeta. **Un pack se ofrece, nunca se exige**: la instalación terminó
preguntándote si lo querías ahora o después, y si dijiste después la tarea está en tu backlog con el
comando adentro. Sumar otro, volver a poner uno, o tomar el que postergaste es un pedido a cualquier
sesión: **"instalá el pack `<nombre>`"**.

**Este manual no lista qué trae un pack, a propósito.** Cada pack viaja con su propio índice, y ese
índice llega con él — así la lista que leés es siempre la que tenés, nunca la que el manual se
acordaba. Pedí lo que querés con tus palabras: la sesión lee el índice de lo que esté instalado y te
rutea, o te dice que nada de lo instalado lo cubre.

## Trabajar con agentes: dos gates y un tramo autónomo

El trabajo pesado se delega a agentes que corren en segundo plano, mientras la sesión principal se
queda al timón — nunca se muda de carpeta ni pierde tu contexto.

- **`scout`** — lee fuentes (código, documentación, otra spec) y vuelve con una síntesis. No escribe
  nada: las herramientas con las que corre no le permiten tocar un archivo.
- **`complete-spec`** — implementa una spec donde cada criterio tiene su chequeo ejecutable.
- **`ambiguous-spec`** — implementa una spec con decisiones abiertas, donde hace falta juicio.

El patrón de supervisión tiene **dos gates humanos y un tramo autónomo en el medio**: una persona
aprueba la spec (**gate 1**) → el agente la implementa en una rama, nunca sobre la rama principal y
nunca con un push → una persona lee la rama y la mergea (**gate 2**). Autonomía en el medio, control
humano en los bordes.

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
