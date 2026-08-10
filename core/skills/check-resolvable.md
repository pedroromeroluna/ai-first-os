---
command: check-resolvable
capability: Auditar el ruteo de la raíz
---

# check-resolvable — que ninguna herramienta quede oscura

Audita el grafo de la raíz: capacidad → herramienta. Es el que corre sobre todo el sistema; el del
nodo —contenido → dónde— ya corre en cada arranque de sesión.

## Cómo se corre

```
.os/core/lib/check-resolvable.sh --brain .
```

Termina con exit distinto de 0 si encontró algo. Es lo que hace falta para colgarlo de un cron sin
que nadie lea la salida.

## Las tres direcciones, que son tres errores distintos

| Hallazgo | Qué pasó | Cómo se arregla |
|---|---|---|
| capacidad oscura | La herramienta está instalada y ninguna fila la alcanza | Agregar la fila que la rutea |
| eslabón roto | Un handoff nombra una capacidad que ninguna fila provee | Agregar la fila, o corregir el nombre de la capacidad |
| ilusión de capacidad | Una fila apunta a una herramienta que no existe | Corregir la ruta, o borrar la fila |

## Qué hacer con la salida

Cada hallazgo trae `archivo:línea`. Se arregla editando markdown, nunca código: las filas viven en
`.os/core/resolver.md` —origen producto, se cambia por PR en el repo— y en `resolver.md` —origen
personal, lo edita el operador—.

**Una capacidad oscura del producto no se arregla en el brain.** Si la fila que falta es del
producto, lo que corresponde es el PR; agregarla en el resolver personal tapa el síntoma en una
máquina sola.
