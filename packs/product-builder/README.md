# Pack — product-builder

El oficio de construir producto: descubrimiento, specs, delegación a agentes, montaje de repos.

Un pack no duplica nada de `core/`: lo referencia por ruta. Si una herramienta de acá necesita
variar una de `core/`, la variación es parametrización o la separación está mal.

`install.sh` engancha cada pack en `.os/packs/<pack>` del brain.

## Qué hay adentro

`skills/` — las herramientas del oficio, una por archivo, con el nombre del comando como nombre de
archivo.

- `product-strategy.md` (`command: product-strategy`) — entrevista socrática que separa el
  síntoma de la causa, aplica el gate de métrica y prioriza hasta 3 hipótesis. Escribe el Discovery
  Brief. Primer eslabón del pipeline de discovery.
- `market-research.md` (`command: market-research`) — research secundario, TAM/SAM/SOM
  direccional con fuente y supuesto. Escribe el Market Brief.
- `ux-research.md` (`command: ux-research`) — diseña la ronda de research (una hipótesis por
  ronda, cualitativo o cuantitativo) sobre la hipótesis más riesgosa. Escribe el Plan de Research.
- `usuarios-sinteticos.md` (`command: usuarios-sinteticos`) — pilotea el guión contra personas
  sintéticas antes de campo real, con la regla de que no valida nada. Escribe el Diagnóstico +
  Guión v2.
- `prd.md` (`command: prd`) — entrevista y escribe la capa estratégica de un producto (visión,
  problema, usuarios, alcance, competidores, oportunidades, preguntas abiertas, glosario) en el
  `context/` de su nodo del brain. Último eslabón del pipeline: de esa capa salen las specs
  que arma `new-spec` (`core/skills/new-spec.md`).
- `product-metrics.md` (`command: product-metrics`) — la estación de métricas; ver el pipeline
  abajo.
- `cpo.md` (`command: cpo`) — el primer oficio de posición del pack: la respuesta estratégica
  genérica de un CPO, en cuatro pasos. Invocable a mano, o activado por `role: cpo` en el
  `context.md` de una organización (spec 009) — la coincidencia entre `role:` y `command:` no
  depende de mayúsculas (spec 014). Los datos del negocio nunca viajan en el archivo: los toma del
  nodo que lo activa.

Ninguna se registra para activación automática del harness. El índice es el resolver: las skills
del pack declaran su fila en `resolver.md` de este pack (spec 017), que `check-resolvable` lee
como un origen más junto al de core y al del operador.

## Pipeline de discovery (estado)

```
product-strategy → market-research → ux-research → usuarios-sinteticos → campo real → prd
                 \_ (si el gate de métrica no pasa) → product-metrics ─┘
```

Las cuatro estaciones de discovery (`product-strategy`, `market-research`, `ux-research`,
`usuarios-sinteticos`, spec personal-os#012) ya están implementadas, cada una escribiendo su
entregable como research fechado del nodo de producto (Discovery Brief, Market Brief, Plan de
Research, Diagnóstico + Guión v2). `product-metrics` (spec personal-os#015) construye la North
Star, el árbol de métricas y la métrica por hipótesis cuando el gate de `product-strategy` ("si no
hay métrica, el problema no está claro") no pasa. Después de campo real —entrevistas reales, fuera
de este pack— el research completo alimenta `prd`, que cierra el pipeline escribiendo la capa
estratégica.
