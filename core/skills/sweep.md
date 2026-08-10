---
command: sweep
capability: Ver qué hay pendiente
capability: Ver qué está trabado y por qué
capability: Ver cómo viene el roadmap
---

# sweep — los tres barridos globales

Tres modos de una herramienta, no tres comandos. Contestan "¿qué tengo pendiente?", "¿qué está
trabado y por qué?" y "¿cómo viene el roadmap?" leyendo solo frontmatter, en todas las
organizaciones a la vez.

## Cómo se corre

```
.os/core/lib/sweep.sh --brain . --mode pending
.os/core/lib/sweep.sh --brain . --mode blocked
.os/core/lib/sweep.sh --brain . --mode roadmap
```

La tabla del entorno —la que mapea el remote de un nodo montado a su ruta local en esta máquina— se
lee sola desde `mounts.md`, en la raíz del brain: `--mounts <ruta>` es override y no hace falta
pasarla. Sin tabla el barrido cubre solo el brain y lo declara; con un montaje declarado y sin
clonar, lo reporta como no alcanzado y sigue. La escribe `mount-repo`.

## Qué hacer con la salida

**La salida es el estado.** Se muestra tal como salió y no se recalcula, ni se completa con
inferencias, ni se resume. Encima va una lectura de una línea y una sugerencia de próxima acción.

**Lo que aparece en "Sin clasificar" no se adivina.** Una cabeza sin `status` o sin `horizon` no
tiene estado que el barrido pueda deducir: se le ofrece al operador escribirlo, con la ruta.

**El cuerpo de una iniciativa se carga recién cuando el operador elige foco.** El barrido lee
frontmatter: alcanza para elegir y no para trabajar.
