---
command: usuarios-sinteticos
capability: Pilotear un guión de research con personas sintéticas antes de campo real
---

# usuarios-sinteticos — el Diagnóstico + Guión v2

Cuarta estación del pipeline. Pilotea el guión que armó `ux-research` contra personas sintéticas
—perfiles simulados con rasgos explícitos— antes de gastar el primer minuto de campo real. Ejemplo
genérico de dominio: una app B2B de gestión de turnos podría simular a un administrador de una
clínica chica y a uno escéptico que ya probó y abandonó una herramienta parecida.

## Cuándo se invoca

| Cuándo | Desde / hacia |
|---|---|
| El Plan de Research de `ux-research` ya tiene una guía v1 | Entrada desde `ux-research` (`packs/product-builder/skills/ux-research.md`) |
| El Diagnóstico + Guión v2 queda escrito | Salida: campo real — entrevistas con personas reales, el trabajo que retoma el operador; no es una skill de este pack |
| Después de campo real | El research completo del pipeline alimenta la capa estratégica que escribe `prd` (`packs/product-builder/skills/prd.md`) |

## La regla número uno

**Esto NO valida nada.** Abre la sesión con esta frase y la repite al cerrar: ninguna respuesta de
una persona sintética es evidencia de que algo funciona con usuarios reales. Sirve para una sola
cosa —encontrar defectos en el guión antes de gastar tiempo de campo real— y para ninguna otra. Un
Diagnóstico que se lee como si validara la hipótesis está mal escrito, sin importar cuánto se haya
repetido la regla en el texto.

## Las personas sintéticas

Se conduce con el método de presión de `core/skills/grill.md#método` — se cita por ruta, nunca se
copia — al construir cada perfil: cada rasgo que se propone se presiona por su origen antes de
entrar al perfil.

Cada persona simulada lleva sus rasgos con origen explícito, marcado uno por uno: **(evidencia)**
si sale de research real ya hecho —una entrevista, un dato de uso, algo que trae el Discovery
Brief o el Market Brief— o **(supuesto)** si es una construcción sin research atrás. Un rasgo sin
marca no entra al perfil.

**Al menos una persona escéptica**, con motivo: alguien que ya probó algo parecido y lo abandonó,
alguien con una objeción de negocio (el costo, el cambio de proceso), o alguien que directamente no
tiene el problema que la hipótesis asume. Un set de personas que solo confirman la hipótesis no
sirve para encontrar defectos: sirve para confirmarlos.

**Prohibido el "¡me encanta!" sin costo al lado.** Toda respuesta entusiasta de una persona
sintética se acompaña de su costo o su fricción: qué le cuesta, qué le preocupa, qué tendría que
dejar de hacer. Una respuesta de solo entusiasmo es la señal de que el guión está armado para
confirmar, no para aprender.

## La taxonomía de defectos de pregunta

Cada pregunta del guión v1 se revisa contra esta lista; el defecto encontrado se anota con su
reescritura al lado, nunca solo señalado:

| Defecto | Ejemplo | Reescritura |
|---|---|---|
| Pregunta líder (sugiere la respuesta) | "¿No te parece que sería útil tener un recordatorio automático?" | "¿Cómo hacés hoy para no perderte un turno?" |
| Pregunta hipotética ("¿usarías...?") | "¿Usarías una función que reprogramara turnos sola?" | "Contame la última vez que tuviste que reprogramar un turno" |
| Doble pregunta | "¿Te resulta claro el panel y rápido de usar?" | Separar en dos preguntas, una por atributo |
| Pregunta sin comportamiento detrás | "¿Qué opinás de la gestión de turnos en general?" | "¿Cuándo fue la última vez que gestionaste turnos para tu equipo?" |
| Jerga que el segmento no usa | Un término técnico interno del equipo de producto | La palabra que usa el segmento, tomada de research previo |

## El Diagnóstico + Guión v2

Cierra escribiendo el entregable como research fechado del nodo de producto cargado, en:

```
context/<AAAA-MM-DD>-diagnostico-guion.md
```

Fechado, no se pisa. La ruta cae dentro de `content: orgs/*/products/*/context/*.md` de
`core/templates/tree.md`: no hace falta glob nuevo ni fila de resolver.

El Diagnóstico lleva estas cuatro secciones, en este orden, cada una con su encabezado literal:

```
## Personas sintéticas
## Simulación
## Defectos encontrados y reescritura
## Guión v2
```

- **Personas sintéticas**: cada perfil, con sus rasgos marcados `(evidencia)` o `(supuesto)`, y la
  persona escéptica identificada como tal.
- **Simulación**: las respuestas simuladas contra el guión v1, cada entusiasmo con su costo al
  lado.
- **Defectos encontrados y reescritura**: cada defecto de la taxonomía que apareció, con su
  reescritura.
- **Guión v2**: la guía corregida, lista para campo real.

La sección **Guión v2** abre y cierra con la regla número uno escrita tal cual: "esto NO valida
nada" — antes de la primera pregunta y después de la última.

## Lo que este entregable no exige

El Diagnóstico + Guión v2 no reemplaza campo real: es el paso que reduce cuánto guión roto llega a
la primera entrevista con una persona real. La síntesis de lo que salga de campo real —
transcripciones a hallazgos— no es trabajo de esta skill.
