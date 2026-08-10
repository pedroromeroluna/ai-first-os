---
command: new-spec
capability: Escribir una spec nueva
---

# new-spec — escribir una spec que un agente pueda implementar sin pedir opinión

De una conversación —de estrategia o de trabajo— sale trabajo de construcción concreto: "hay que
construir X", "escribí la spec de Y". El entregable de este oficio es un archivo en `specs/` del
repo destino, con el estándar de este producto, listo para el Gate 1.

## 1. Repo destino

Si no está dicho, preguntalo. Antes de escribir:

- `ls specs/` del repo → el número siguiente (`NNN` de tres dígitos, correlativo). Las specs
  archivadas en `specs/done/` cuentan para la numeración.
- Leé el `CLAUDE.md` del repo y `ARCHITECTURE.md` (si existe) → así el "Estado previo" describe el
  terreno real y no hace que el agente que implemente redescubra lo que ya está construido.
- Si el repo no tiene `specs/` todavía, ese repo no adoptó este formato. Decilo y ofrecé escribir
  igual la primera spec, creando la carpeta.

## 2. El estándar de una spec completa

Una spec está completa cuando cualquier agente puede leerla y contestar "¿pasa o no pasa?" en
cada criterio sin pedir opinión. Lo que falta de esto no se completa a criterio propio: se
pregunta.

**Frontmatter, dos campos y ninguno más:**

```
---
estado: pendiente
depende_de: []
---
```

`estado` es `pendiente | esperando Gate 1 | en curso | implementada`. `depende_de` es una lista
**en línea** de referencias a otras specs (`[]` si no depende de ninguna) — en varias líneas, un
`grep` devuelve la primera y pierde el resto. El lector reporta este campo; no lo cambia solo
porque una dependencia se cerró.

**La spec abre diciendo qué se va a hacer**: después del título, una o dos oraciones en criollo,
sin jerga del sistema, antes de cualquier detalle. Una spec que no se entiende de un vistazo no se
revisa: se aprueba a ciegas.

**Tipo y flujo**: `feature` | `verificación` (código ya escrito cuyo eval nunca corrió) |
`residuales` (bolsa de arreglos chicos que solos no justifican una spec). `requirements-first` por
default; `design-first` si hay una restricción técnica dura o viabilidad dudosa — ahí el primer
paso es el smoke test mínimo que de-riesga, no construir.

**Cada criterio de aceptación lleva un eval ejecutable.** Determinista para lo exacto (un comando,
una fila esperada, un grep); con rúbrica escrita en la spec para lo generativo (copy, tono, UX).
Un criterio sin eval es un deseo, no un criterio: o le encontrás el check, o no entra.

**Las tres clases de decisión, siempre separadas y nunca mezcladas:**

1. *Cerradas antes de delegar* → fechadas y atribuidas ("DEFINIDO por `<quién>` (Gate 1,
   `<fecha>`): … porque …"), para que no se re-litiguen.
2. *Delegadas al agente que implemente* → con **el criterio para elegir** escrito. Delegar sin
   criterio no es delegar: es omitir, y el agente la resuelve a ciegas.
3. *Condiciones de parada* → acá el agente no decide ni con criterio: para y pregunta. Van las
   contradicciones entre criterios, las decisiones que ninguna de las dos clases anteriores cubre,
   y cualquier punto donde equivocarse sale caro.

**Efectos que escapan del sistema**: un mail que llega a una persona, un cobro, un mensaje, un
post. Ningún rollback los trae de vuelta, aunque el ambiente diga "staging". Se declaran con su
contención (destinatarios de prueba, sandbox del proveedor, datos de test), o la spec dice
"ninguno" explícito.

**Fuera de alcance con condición de reactivación**: no alcanza con decir qué no entra; hay que
decir qué lo traería adentro, medible si se puede ("si el volumen supera N", "si lo pide el primer
usuario real de esto").

## 3. Entrevistá solo lo que falte

Lo que ya salió de la conversación no se vuelve a preguntar. Preguntá en tandas cortas, con un
default propuesto en cada hueco — corregir un default es más rápido que redactar desde cero.

## 4. Escribir, validar y entregar

1. Mostrá la spec completa antes de escribirla y esperá el ok.
2. Escribila en `specs/NNN-nombre-corto.md` con `estado: pendiente`.
3. Cerrá devolviendo:
   - El disparador exacto para implementarla: "implementá la spec NNN".
   - Qué agente le corresponde: `spec-completa` si cada criterio tiene su eval y no quedó ninguna
     decisión abierta; `spec-ambigua` si quedaron incógnitas, decisiones abiertas o es
     design-first.
   - Que la implementación se delega desde esta misma sesión (Agent tool) sobre el repo montado:
     no hace falta abrir una sesión aparte en esa carpeta.

Si conviene investigar antes de escribir la spec —qué hace algo hoy, cómo lo resuelve otra fuente—
usá el agente `scout`: lee y devuelve una síntesis, nunca escribe la spec por vos.
