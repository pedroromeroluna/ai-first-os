---
command: grill
capability: Presionar los hechos antes de que una decisión se cierre
---

# grill — la entrevista de presión

Dos caras. **Invocable sola**: presiona los hechos del nodo cargado y reparte lo que sale sin
inventar destino nuevo. **Método referenciable**: cualquier herramienta que entreviste cita la
sección de abajo en vez de copiarla — variar a quién apunta o qué ejemplos usa es parametrización
de quien cita, nunca una segunda copia del método.

## Método

Citá esta sección por su encabezado (`core/skills/grill.md#método`) desde cualquier herramienta que
entreviste. Los cinco ingredientes, en el orden en que se aplican:

### 1. Contrapregunta con ejemplo concreto

Ante una respuesta que no se puede falsear ("a todos les gustó", "fue exitoso", "el equipo lo tiene
claro"), la respuesta no se acepta ni se reformula: se devuelve una contrapregunta que pide el hecho
de atrás, con un ejemplo de qué contaría como buena respuesta.

> Mal: "¿podés dar más detalle?"
>
> Bien: "¿'les gustó' según qué — completaron la tarea sin ayuda, lo dijeron ellos, o lo inferiste
> vos? Una buena respuesta nombra el dato: '3 de 5 completaron sin pedir ayuda, 2 abandonaron en el
> paso 3'."

### 2. Presión acotada a 1-2 intentos

Como máximo dos vueltas de contrapregunta sobre el mismo hecho. Una tercera no saca más
información: satura al entrevistado y el método deja de ser entrevista para volverse
interrogatorio.

### 3. Escape hatches

Dos salidas, ninguna es "seguir insistiendo":

- **Segunda resistencia** — la respuesta a la segunda contrapregunta sigue sin hecho. El intento no
  se descarta ni se fuerza una tercera vuelta: el hueco se anota, con quién lo cierra, y se sigue.
- **Evidencia fuerte de entrada** — si la primera respuesta ya trae el hecho (comportamiento
  observado, dato medido), no hay contrapregunta que hacer: se confirma y se avanza.

### 4. Jerarquía de evidencia

`comportamiento > dato > dicho > supuesto`. Ante dos respuestas que compiten sobre el mismo hecho,
gana la de mayor jerarquía — un supuesto no pesa lo mismo que un comportamiento observado aunque
las dos se digan con la misma confianza.

### 5. Todo hueco se registra, nunca se rellena

Un hueco que la presión no cerró no se completa con una inferencia para que el documento quede
prolijo. Se registra como abierto, con quién lo cierra. Rellenarlo en silencio es la misma clase de
barrido incompleto presentado como completo que el resto del sistema prohíbe.

## Cara invocable

Se corre sola sobre el nodo que ya está cargado. Presiona sus hechos con el método de arriba y
reparte lo que sale entre los canónicos que ya existen — no inventa ninguno:

| Sale | Va a |
|---|---|
| Una decisión | `decisions.md` del nodo cargado — el de la organización si se está trabajando ahí, el de la raíz si el nodo cargado es el propio producto |
| Un hueco | El backlog del nodo cargado (`backlog.md` de la organización), registrado como abierto con quién lo cierra nombrado en el texto — el mismo formato de línea de texto libre y verbatim que ya usa el cierre de sesión |
| Un hueco, si el nodo de producto cargado declara su propia capa de preguntas abiertas | Esa capa (`context/open-questions.md` del nodo), en vez del backlog |

Los tres destinos existen antes de esta herramienta. Si presionar un hecho llevara a escribir en
un destino que no está en esta tabla, `grill` no lo inventa: lo dice y para — esa fila la agrega el
operador, no la sesión.
