---
command: ux-research
capability: Planificar la ronda de research cualitativo o cuantitativo sobre la hipótesis más riesgosa
---

# ux-research — el Plan de Research

Tercera estación del pipeline. Diseña la ronda de research que ataca la hipótesis más riesgosa del
Discovery Brief — nunca todas a la vez — y cierra con un Plan de Research listo para pilotear.

## Cuándo se invoca

| Cuándo | Desde / hacia |
|---|---|
| El Market Brief de `market-research` ya dimensionó el mercado | Entrada desde `market-research` (`packs/product-builder/skills/market-research.md`) |
| El Plan de Research queda escrito | Salida hacia `usuarios-sinteticos` (`packs/product-builder/skills/usuarios-sinteticos.md`) — pilotea el guión antes de gastar campo real |
| Sin Market Brief previo | Invocable sola, sobre el nodo de producto cargado, con el Discovery Brief como entrada mínima |

## La entrevista

Se conduce con el método de presión de `core/skills/grill.md#método` — se cita por ruta, nunca se
copia — sobre la elección de la hipótesis, el criterio de screening y cada pregunta de la guía.

### Un objetivo por ronda

Cada ronda ataca una sola hipótesis: la más riesgosa del Discovery Brief, la misma priorización
riesgo × impacto que ya hizo `product-strategy`. Ante un pedido de "investigar todo junto", se
presiona: ¿cuál es la que, si sale mal, más cuesta? Esa es la de esta ronda; las demás esperan la
próxima.

### Screening que evita "usuarios en general"

El criterio de selección de a quién entrevistar se escribe en comportamiento verificable, nunca en
demografía sola. "Usuarios activos" no es screening; "personas que compraron en las últimas dos
semanas y abandonaron el checkout al menos una vez" sí. Ante un criterio demasiado amplio
("cualquier usuario de la app"), se devuelve con contrapregunta: ¿qué comportamiento tiene que
haber hecho o no hecho esta persona para que su respuesta sirva?

### Exploratorio → cualitativo; dimensionar → cuantitativo

La modalidad se decide según qué pregunta hace la ronda. Si la pregunta es "¿por qué pasa esto?" o
"¿qué hace la gente hoy?", cualitativo — entrevistas, pocas personas, profundidad. Si la pregunta
es "¿cuánta gente le pasa esto?" o "¿qué tan seguido?", cuantitativo — encuesta, muestra
representativa. Mezclar las dos sin decidir cuál manda produce un plan sin foco; se elige una y se
dice por qué.

### JTBD en cuatro dimensiones

Cuando la ronda explora un job-to-be-done, la guía cubre las cuatro fuerzas del cambio, no solo la
funcional:

| Dimensión | Qué busca |
|---|---|
| Empuje | Qué de la situación actual empuja a buscar algo distinto |
| Atracción | Qué de la nueva solución atrae |
| Ansiedad | Qué duda o miedo frena el cambio |
| Hábito | Qué de la solución actual pesa por costumbre, aunque no funcione bien |

Una guía que solo pregunta por la funcionalidad deseada cubre una sola de las cuatro y se devuelve
incompleta.

### Técnica madre: reconstruir la última vez real

La pregunta madre de cualquier guía no es "¿qué opinás de X?": es "contame la última vez que
[situación]" — reconstruir paso a paso qué pasó, en qué momento, con quién, qué hizo justo antes y
después. Las preguntas de opinión ("¿te gustaría que...?") se sacan de la guía salvo que sirvan
para cerrar la sesión, nunca para explorar.

### Cada pregunta atada, o se saca

Toda pregunta de la guía se ata explícitamente a una hipótesis del Discovery Brief o a una de las
cuatro dimensiones del job. Una pregunta que no se puede atar a ninguna de las dos se saca de la
guía — "por las dudas" no es un criterio de inclusión.

## El Plan de Research

Cierra escribiendo el entregable como research fechado del nodo de producto cargado, en:

```
context/<AAAA-MM-DD>-research-plan.md
```

Fechado, no se pisa. La ruta cae dentro de `content: orgs/*/products/*/context/*.md` de
`core/templates/tree.md`: no hace falta glob nuevo ni fila de resolver.

El Plan lleva estas cuatro secciones, en este orden, cada una con su encabezado literal:

```
## Objetivo de la ronda
## Criterio de screening
## Modalidad
## Guía de preguntas
```

- **Objetivo de la ronda**: la hipótesis elegida y por qué es la más riesgosa.
- **Criterio de screening**: en comportamiento verificable, nunca solo demografía.
- **Modalidad**: cualitativo o cuantitativo, con la pregunta que lo decide.
- **Guía de preguntas**: cada pregunta con la hipótesis o dimensión del job a la que está atada.

## Lo que este entregable no exige

El Plan de Research es la guía v1: todavía no se piloteó. Piloterla contra personas sintéticas —
antes de gastar el primer minuto de campo real— es trabajo de `usuarios-sinteticos`, la estación
siguiente.
