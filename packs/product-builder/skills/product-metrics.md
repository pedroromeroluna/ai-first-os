---
command: product-metrics
capability: Definir la North Star, el árbol de métricas y la métrica de cada hipótesis activa
---

# product-metrics — el Metric Brief

El hueco que la pipeline vieja reconocía sin llenar: `product-strategy` exige que "si no hay
métrica, el problema no está claro", pero ninguna herramienta ayudaba a construir esa métrica —
derivaba a un "Product Metric Coach" que nunca existió. Esta es esa estación: define la North Star
candidata, arma el árbol de palancas que la sostienen, y le pone número, forma de medición y valor
de hoy a cada hipótesis activa.

## Cuándo se invoca

| Cuándo | Desde / hacia |
|---|---|
| El gate de métrica de `product-strategy` no pasa ("si no hay métrica, el problema no está claro") | Entrada desde `product-strategy` (`packs/product-builder/skills/product-strategy.md`) |
| El Metric Brief queda escrito | Salida hacia `prd` (`packs/product-builder/skills/prd.md`) — el `context/` estratégico del nodo se completa con la métrica ya definida |
| Sin gate previo | Invocable sola, sobre el nodo de producto ya cargado |

Las dos estaciones vecinas ya están instaladas en este pack: nombrarlas acá es real, no inventado —
no es el caso de la vieja referencia a un "Product Metric Coach" sin spec ni dueño.

## La entrevista

Se conduce con el método de presión de `core/skills/grill.md#método` — se cita por ruta, nunca se
copia. Los cinco ingredientes (contrapregunta con ejemplo, presión acotada a 1-2 intentos, escape
hatches, jerarquía de evidencia, todo hueco se registra) se aplican tal como están descriptos ahí.

Antes de preguntar: si el nodo de producto cargado tiene research fechado de `product-strategy`
(un Discovery Brief con hipótesis), leelo — las hipótesis activas salen de ahí, no se piden de
nuevo. Si no hay research previo, se preguntan directamente.

Cuatro pasos, en este orden:

### 1. North Star candidata

Una sola métrica candidata a North Star, con el porqué en una línea: qué decisión de producto
mueve, no por qué "es importante". Ante una respuesta que no nombra una decisión ("porque mide el
éxito", "porque es la que todos miran"), grill la devuelve con contrapregunta.

### 2. Árbol de métricas

La North Star arriba, sus palancas abajo — las variables que, si se mueven, mueven la North
Star. Cada palanca lleva dónde se mide (qué evento, qué tabla, qué fuente — el dónde, nunca cómo
instrumentarlo: eso es del cuerpo del producto del usuario, no de esta herramienta). Una palanca
sin dónde-se-mide es un hueco, no un renglón completo.

### 3. Métrica por hipótesis activa

Por cada hipótesis activa (las que trae `product-strategy`, o las que se levantan acá si no hay
research previo): qué número la valida o la refuta, medido cómo, contra qué valor de hoy.

**Regla dura: sin valor con fuente no hay dato.** Un valor de hoy que el operador no puede citar
con su origen (un dashboard, una medición, un dato con fecha) no se escribe como si lo fuera: se
anota como hueco, con quién lo cierra — el mismo formato de hueco que usa `grill`. Inventar el
número para que la fila quede completa es el mismo barrido incompleto presentado como completo que
el resto del sistema prohíbe.

### 4. Antimétricas

Qué no debería empeorar mientras la North Star mejora, con el umbral que dispara la alarma —un
número o una condición verificable, nunca "si empeora mucho".

### La métrica vanidosa

Después de cada métrica propuesta (North Star, palanca o métrica de hipótesis), se aplica esta
pregunta: **¿qué decisión cambia este número, en cualquier dirección que se mueva?**

Si no hay respuesta o la respuesta es otra métrica ("cambia cómo vemos el crecimiento"), es una
métrica vanidosa: se lo dice tal cual — "esto es una métrica vanidosa: no cambia ninguna decisión"
— y se pide la decisión concreta que la métrica debería mover antes de aceptarla en el Brief. No
se descarta en silencio ni se acepta para no interrumpir la entrevista.

## El Metric Brief

Cierra escribiendo el entregable como research fechado del nodo de producto cargado, en:

```
context/<AAAA-MM-DD>-metric-brief.md
```

Fechado, no se pisa — el mismo criterio que ya usa `docs/research/` de este repo. La ruta cae
dentro de `content: orgs/*/products/*/context/*.md` de `core/templates/tree.md`: no hace falta
glob nuevo ni fila de resolver.

El Brief lleva estas cuatro secciones, en este orden, cada una con su encabezado literal:

```
## North Star candidata
## Árbol de métricas
## Métrica por hipótesis
## Antimétricas
```

- **North Star candidata**: la métrica y el porqué en una línea (qué decisión mueve).
- **Árbol de métricas**: la North Star arriba, cada palanca en una línea con su dónde-se-mide.
- **Métrica por hipótesis**: una entrada por hipótesis activa — qué número, medido cómo, valor de
  hoy o hueco con dueño.
- **Antimétricas**: cada una con su umbral de alarma.

Si la entrevista detectó una métrica vanidosa en el camino, el Brief la deja escrita igual —con la
etiqueta "(vanidosa: no cambia [la decisión que se pidió y no llegó a tener dueño, si quedó sin
cerrar])"— nunca la borra en silencio.

## Lo que este entregable no exige

El Metric Brief no crea ni pide un canónico nuevo del nodo de producto: es research fechado, se
suma a lo que ya hay, no reemplaza ni obliga a versionar de nuevo un archivo vivo del `context/`.
Si alguna vez hiciera falta un canónico de métricas (un `metrics.md` vivo que se pise), esa
decisión la aprueba el operador — no esta herramienta.
