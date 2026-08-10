---
command: prd
capability: Entrevistar y escribir la capa estratégica de un producto
---

# prd — la capa estratégica de un producto

Entrevista al operador y produce la definición estratégica de un producto: visión, problema,
usuarios, alcance, competidores, oportunidades, preguntas abiertas y glosario. Es la puerta de
entrada al método — de esta capa salen las specs.

**Escribe siempre en el `context/` del nodo de producto cargado del brain, nunca en el repo
cuerpo.** El repo declarado en `repo:` de la cabeza del nodo es el cuerpo: specs, decisiones
técnicas, as-built. La capa estratégica vive en la cabeza, no en el cuerpo.

La entrevista presiona con el método de `core/skills/grill.md#método`: se cita por ese encabezado,
nunca se copia. Cualquier cambio al método se hace ahí, una sola vez.

## Los archivos que produce

Van a `context/` del nodo de producto cargado. Si el nodo no tiene `context/` todavía, nace con
`README.md` primero y el resto según se completa la entrevista.

| Archivo | Qué contesta |
|---|---|
| `README.md` | Índice: qué es el producto, en qué orden se llenó cada archivo, su estado |
| `vision.md` | El sistema terminado, a dónde se llega |
| `problem.md` | Qué problema resuelve, para quién, por qué ahora, cómo se sabe si funcionó |
| `users.md` | A quién le vende, qué usa hoy en su lugar |
| `scope.md` | Qué NO hace, a quién NO le vende, restricciones duras, qué entra en la primera versión |
| `competitors.md` | Contra qué compite y en qué se diferencia |
| `opportunities.md` | Lo que podría valer la pena y todavía no se decidió |
| `open-questions.md` | Lo que falta decidir — vivo, se vacía a medida que se cierra |
| `glossary.md` | Los términos del dominio |

Ningún archivo de esta lista se escribe en el repo cuerpo. Si completar una sección obligara a
tocar el repo cuerpo o un resolver, la herramienta no lo hace: lo dice y para — es una condición de
parada de la spec que la trajo, no una decisión de esta sesión.

El árbol de KPIs no entra acá: es del brief de métricas de otra herramienta; esta skill lo
referencia si ya existe, no lo produce.

## Fase 1 — Leé lo que el brain ya sabe antes de preguntar

Antes de la primera pregunta:

1. Identificá el nodo de producto cargado y su `context/` — si no existe, se crea con esta
   entrevista.
2. Leé completos los archivos que ya tiene ese `context/`. Esto es incremental: se completa por
   etapas y nunca se pisa una sección llena sin decirlo primero.
3. Leé el contexto de la organización dueña y, si existe, research fechado que aplique.
4. Decile al operador qué leíste y **qué secciones ya podés llenar solo** con eso. Recién ahí
   arranca la entrevista, y solo sobre lo que falta — no le preguntás lo que el sistema ya tiene
   escrito.

## Fase 2 — La entrevista

Una pregunta por vez, con una línea de por qué esa sección cambia una decisión antes de cada una.
Sin esa línea la pregunta suena a burocracia.

### Las seis preguntas que fuerzan la verdad

Etapa de oportunidad y negocio, antes de tocar la solución:

1. ¿Cuál es la evidencia más fuerte de que alguien quiere esto? No interés: comportamiento.
2. ¿Con qué lo resuelven hoy? Si la respuesta es "con nada", ¿por qué viven bien sin esto?
3. Nombrame una persona concreta. Cargo, y qué le pasa si no lo resuelve.
4. ¿Cuál es la versión más chica por la que alguien pagaría esta semana?
5. ¿Qué te sorprendió mirando a alguien usarlo o intentar resolverlo?
6. En tres años, ¿esto se vuelve más necesario o menos?

### Etapa de investigación

No se inventan conclusiones: si no hay research hecho, se dice y se ofrece la herramienta de
descubrimiento que corresponda. Se pregunta por segmento, por no-target explícito, y por las
alternativas que el operador ya usa hoy.

### Etapa de solución

Antes de hablar de qué construir, se desafía la premisa: ¿es este el problema correcto? ¿qué pasa
si no se hace nada? ¿hay algo ya construido que sirva? Después sí: visión, slicing, qué NO hace con
su condición de reactivación, restricciones duras, supuestos con su condición de invalidación.

### Cómo presionar

El método de `core/skills/grill.md#método` decide cuándo contrapreguntar, cuántas vueltas, y qué
hacer con la segunda resistencia. No se repite acá: se aplica.

## Fase de alternativas, obligatoria

Antes de fijar la solución, se presentan 2 o 3 caminos, cada uno con su esfuerzo, riesgo y qué
reusa de lo que ya existe:

- **el mínimo embarcable** — la versión más chica que se puede lanzar esta semana,
- **el que mejor envejece** — la que menos retrabajo pide si el producto crece,
- **uno lateral que reencuadre el problema** — una salida que no es "más de lo mismo, más chico".

El operador elige uno. Sin esta fase el documento registra la primera idea, no la mejor.

## La regla del hueco explícito

Un hueco se escribe **solo cuando el operador decide explícitamente no contestar**, y siempre con
quién lo cierra. Un archivo lleno de huecos no es un entregable: es un fracaso disfrazado de
completitud. Si un hueco aparece porque la sección no se preguntó, no es un hueco: es trabajo sin
hacer, y se retoma la entrevista.

## Mostrá antes de escribir

Antes de tocar cualquier archivo, se muestra al operador exactamente qué se va a escribir —el
contenido, no un resumen— y se espera su ok. Se escriben solo los archivos que la entrevista tocó;
los que ya estaban completos no se pisan.

## El veredicto de cierre

Al terminar, uno de tres, siempre explícito:

- **Completo** — alcanza para escribir specs.
- **Completo con reservas** — se puede avanzar, y estas son las preguntas abiertas que quedaron.
- **Falta contexto** — qué archivo quedó sin cerrar y qué hace falta para cerrarlo.

**El gate de los mínimos**: si `glossary.md`, `scope.md` o la arquitectura del cuerpo quedan
vacíos, de ahí no salen specs todavía. Se dice explícito, no se deja que se descubra después.
