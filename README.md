# AI First OS

Un sistema operativo de producto para trabajar con agentes. Un mismo primitivo —el nodo— repetido
a todas las alturas: arranca cada sesión con un barrido de tu trabajo, capturás lo que se te
ocurre al vuelo, cerrás la sesión con un veredicto de qué quedó hecho y qué falta, montás un repo
sobre una iniciativa, entrevistás para escribir specs listas para delegar. El pack de Product
Management suma la entrevista que escribe la capa estratégica de un producto (`prd`) y el Metric
Brief (`product-metrics`).

Este documento está escrito para que lo ejecute tu agente, no para que lo leas paso a paso vos.

## Instalar

Guardá este mensaje y pegáselo a tu agente, una sola vez:

> Instalá AI First OS desde `github.com/pedroromeroluna/ai-first-os`. Traé el repositorio a una
> carpeta local fija de esta máquina —la vas a necesitar para actualizar más adelante—, corré su
> bootstrap para armar mi brain con una entrevista corta sobre quién soy y en qué organizaciones
> trabajo, y después corré su instalador para engancharlo a este brain. Preguntame lo que haga
> falta de la entrevista antes de escribir nada.

No hace falta que hagas nada más. El agente trae el repositorio, te entrevista y engancha las
herramientas; vos solo contestás la entrevista.

## Actualizar

Pegale a tu agente:

> Actualizá el sistema.

Con esa frase alcanza. El agente va a la carpeta local donde quedó el repositorio, trae la
versión más nueva y corre el instalador **desde esa carpeta** — nunca desde el enganche que ya
quedó instalado en tu brain. Correr el instalador desde el enganche instalado produce hoy un
enganche circular que rompe la instalación en vez de actualizarla; correrlo desde la carpeta
donde vive el repositorio es el camino que funciona. Tu brain —tus organizaciones, tus decisiones,
tu contenido— no se toca: la actualización solo refresca las herramientas que quedaron
enganchadas.

## Qué instala

- El arranque de sesión: un barrido de qué espera tu decisión, qué está en curso, qué hay en cola
  y qué falla, antes de que el agente conteste tu primer mensaje.
- `capture`: clasificar al vuelo lo que se te ocurre.
- `close-session`: cerrar la sesión con un veredicto de cuatro partes — capturado, no capturado,
  fila candidata para el resolver, para retomar.
- `mount-repo`: darle cuerpo de repo a una iniciativa.
- `grill`: una entrevista de presión, invocable sola o citada por otra herramienta.
- `new-spec`: escribir una spec lista para delegar a un agente.
- El pack de Product Management: `prd` (la entrevista que escribe la capa estratégica de un
  producto) y `product-metrics` (el Metric Brief: North Star, árbol de métricas, métrica por
  hipótesis, antimétricas).

## Licencia

MIT. Ver `LICENSE`.
