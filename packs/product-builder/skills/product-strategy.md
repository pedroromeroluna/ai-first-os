---
command: product-strategy
capability: Definir el problema, la evidencia detrás y las hipótesis priorizadas de un producto
---

# product-strategy — el Discovery Brief

Primer eslabón del pipeline de discovery. Entrevista de forma socrática — nunca da la razón antes
de tiempo — para separar el síntoma de la causa, y cierra escribiendo el Discovery Brief: el
problema, la evidencia que lo sostiene, y hasta tres hipótesis priorizadas.

## Cuándo se invoca

| Cuándo | Desde / hacia |
|---|---|
| Arranca discovery sobre una oportunidad nueva o un problema sin research previo | Invocable sola, sobre el nodo de producto cargado |
| El Discovery Brief queda escrito | Salida hacia `market-research` (`packs/product-builder/skills/market-research.md`) — siguiente estación del pipeline |
| El gate de métrica no pasa | Handoff hacia `product-metrics` (`packs/product-builder/skills/product-metrics.md`) — construye la North Star y la métrica de la hipótesis antes de seguir |

`product-metrics` ya está instalada en este pack: el handoff es real, no la referencia colgada a
un "Product Metric Coach" que nombraba la pipeline vieja.

## La entrevista

Se conduce con el método de presión de `core/skills/grill.md#método` — se cita por ruta, nunca se
copia.

### Socrático: no da la razón

Ante una propuesta que ya viene con forma de solución ("necesitamos un panel de seguimiento",
"hay que agregar notificaciones"), la respuesta no se acepta ni se elabora: se devuelve la
contrapregunta que separa la solución del problema.

> Mal: "buena idea, ¿qué tendría ese panel?"
>
> Bien: "eso es una solución. ¿Qué problema resuelve, y de quién es ese problema?"

Se repite hasta que la respuesta nombra un problema de alguien concreto — nunca una
funcionalidad.

### Jerarquía de evidencia

Toda evidencia que sostiene el problema se clasifica con la misma jerarquía que usa `grill`:
`comportamiento > dato > dicho > supuesto`. "Varios clientes lo pidieron" (dicho) no pesa lo mismo
que "3 de cada 5 abandonan el checkout en el paso de envío" (dato) ni que una sesión grabada donde
alguien lo intenta y se traba (comportamiento). La evidencia de menor jerarquía disponible se anota
igual, con su nivel al lado — no se descarta, se etiqueta.

### El gate de métrica

**Si no hay métrica, el problema no está claro.** Antes de aceptar el problema como bien
planteado, se pregunta: ¿qué número se movería si esto se resolviera? Si no hay respuesta, o la
que aparece es una métrica vanidosa (no cambia ninguna decisión), el gate no pasa: se dice
explícito y se deriva a `product-metrics` para construirla antes de seguir. No se avanza como si el
gate hubiera pasado.

### Hipótesis, con formato fijo

Cada hipótesis se escribe con esta forma, sin excepción:

```
Creemos que [segmento] [hace X] en [momento] por [causa]; si es cierto, veremos [evidencia].
```

Ejemplo genérico (e-commerce): "Creemos que los compradores que abandonan el carrito en el paso de
envío lo hacen porque el costo aparece recién ahí; si es cierto, veremos que mostrar el costo antes
reduce el abandono en ese paso." Una hipótesis sin la cláusula "si es cierto veremos..." no es una
hipótesis: es una opinión con forma de hipótesis, y se devuelve con contrapregunta.

**Máximo 3, priorizadas por riesgo × impacto** — nunca por orden de aparición en la conversación.
Riesgo: qué tan poco se sabe si es cierto. Impacto: cuánto mueve la métrica del gate si se
confirma. Una cuarta hipótesis que aparezca se anota como hueco en el backlog, no entra a la lista.

## El Discovery Brief

Cierra escribiendo el entregable como research fechado del nodo de producto cargado, en:

```
context/<AAAA-MM-DD>-discovery-brief.md
```

Fechado, no se pisa — el mismo criterio que ya usa `docs/research/` de este repo. La ruta cae
dentro de `content: orgs/*/products/*/context/*.md` de `core/templates/tree.md`: no hace falta
glob nuevo ni fila de resolver.

El Brief lleva estas cuatro secciones, en este orden, cada una con su encabezado literal:

```
## Problema
## Evidencia
## Gate de métrica
## Hipótesis priorizadas
```

- **Problema**: el síntoma separado de la causa, de quién es y por qué ahora.
- **Evidencia**: cada pieza con su nivel de jerarquía (`comportamiento`, `dato`, `dicho` o
  `supuesto`) al lado.
- **Gate de métrica**: pasó o no pasó, y si no pasó, el handoff a `product-metrics` dejado
  explícito.
- **Hipótesis priorizadas**: hasta 3, en el formato fijo, ordenadas por riesgo × impacto con el
  porqué del orden.

## Lo que este entregable no exige

El Discovery Brief no reemplaza la capa estratégica que escribe `prd`: es research fechado, entrada
para las estaciones siguientes del pipeline, nunca el canon vivo del producto.
