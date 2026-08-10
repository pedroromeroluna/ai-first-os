---
command: market-research
capability: Investigar el mercado con research secundario y dimensionar la oportunidad
---

# market-research — el Market Brief

Segunda estación del pipeline. Investiga el mercado con research secundario —nunca habla con
usuarios, eso es trabajo de las estaciones siguientes— y dimensiona la oportunidad de forma
direccional, cada número con su fuente y su supuesto al lado.

## Cuándo se invoca

| Cuándo | Desde / hacia |
|---|---|
| El Discovery Brief de `product-strategy` ya tiene hipótesis priorizadas | Entrada desde `product-strategy` (`packs/product-builder/skills/product-strategy.md`) |
| El Market Brief queda escrito | Salida hacia `ux-research` (`packs/product-builder/skills/ux-research.md`) — siguiente estación del pipeline |
| Sin Discovery Brief previo | Invocable sola, sobre el nodo de producto cargado, preguntando el segmento y el mercado directamente |

## La investigación

Antes de buscar, se aplica el método de presión de `core/skills/grill.md#método` — se cita por
ruta, nunca se copia — sobre la definición del segmento y del mercado, y sobre cada fuente que se
propone: la contrapregunta, la presión acotada a 1-2 intentos y el registro del hueco cuando la
segunda resistencia no trae el dato son los mismos de siempre.

### Solo research secundario

Se declara explícito al arrancar: "esto es research secundario — no reemplaza hablar con
usuarios, esa es la estación siguiente". Nunca se simulan respuestas de usuarios ni se presenta un
dato de una fuente secundaria como si fuera research primario.

### TAM/SAM/SOM direccional, con fuente y supuesto

Se dimensiona la oportunidad en tres capas — TAM (el mercado total), SAM (el segmento alcanzable
con el modelo de negocio actual), SOM (lo capturable en el horizonte de la hipótesis que se está
probando) — y cada número lleva su fuente citada más el supuesto que lo convierte de un dato de
mercado en un número de este producto.

Ejemplo genérico (app B2B): "TAM de USD 2.000M (fuente: informe de la cámara del sector, 2025)
asumiendo que el segmento de empresas de 10 a 200 empleados es el 15% de ese mercado (supuesto
propio, sin fuente que lo mida directo)" es una fila completa. Un número sin fuente no entra al
Brief.

**Sin fuente no sirve.** Un número que no se puede citar con su origen no se escribe como si lo
fuera. Se presiona la fuente con el método de grill y, si no aparece tras la presión acotada, se
registra como hueco con quién lo cierra — nunca se completa con un número inventado para que la
tabla quede prolija.

### Ante el vacío, se dice y se sugiere validación

Cuando la búsqueda no encuentra dato para una capa o un segmento, el Brief lo dice explícito ("no
se encontró fuente pública para el SAM de [segmento] en [mercado]") y sugiere cómo validarlo con
evidencia primaria — una encuesta acotada, un piloto, una entrevista con alguien del rubro — nunca
inventa el número para completar la fila.

### Presupuesto de búsqueda acotado, con plan explícito

La investigación corre con un tope dicho antes de arrancar (por ejemplo: hasta 5 búsquedas por
capa, o un bloque de tiempo fijo) — no una búsqueda abierta hasta agotar la web. Al llegar al tope
sin resolver una fila, se cierra con el hueco anotado y un plan explícito de cómo profundizar si
hiciera falta: qué buscar después, con qué tipo de fuente (un informe pago, una entrevista con un
experto del rubro).

## El Market Brief

Cierra escribiendo el entregable como research fechado del nodo de producto cargado, en:

```
context/<AAAA-MM-DD>-market-brief.md
```

Fechado, no se pisa. La ruta cae dentro de `content: orgs/*/products/*/context/*.md` de
`core/templates/tree.md`: no hace falta glob nuevo ni fila de resolver.

El Brief lleva estas tres secciones, en este orden, cada una con su encabezado literal:

```
## TAM/SAM/SOM
## Fuentes y supuestos
## Huecos y plan para profundizar
```

- **TAM/SAM/SOM**: las tres capas, cada una con su número, su fuente y su supuesto.
- **Fuentes y supuestos**: el detalle de cada fuente citada, separado del supuesto que la conecta
  con este producto.
- **Huecos y plan para profundizar**: cada fila sin fuente, con quién la cierra y cómo — nunca en
  silencio.

## Lo que este entregable no exige

El Market Brief no reemplaza research primario con usuarios: es la capa de contexto de mercado que
sostiene la decisión de para qué segmento vale la pena diseñar la ronda de `ux-research`.
