---
command: capture
capability: Capturar algo al vuelo
---

# capture — archivar lo que aparece al vuelo

Lo que el operador tira en medio de otra cosa —"acordate de renovar el seguro"— se archiva donde el
resolver del nodo diga, sin abrir una conversación. Clasificar es tuyo; escribir es del script.

## Antes de escribir

**El resolver del nodo ya está cargado**: el arranque de sesión lo trae. Si la tarea es de otra
organización, su resolver **no** está cargado y no se archiva a ciegas: se carga primero o se dice
que no. Eso lo custodia el script — le pasás `--session-org` con la organización donde está parada
la sesión.

## Cómo se corre

```
.os/core/lib/capture.sh --brain . --session-org <slug-de-la-sesión> --text "<texto>" \
  [--org <slug-destino>] [--blocked-by <ref>] [--hold "<razón>"] [--hold-until <YYYY-MM-DD>]
```

Sin `--org` el texto va al inbox de la raíz. **El inbox es tránsito de lo que no se pudo clasificar,
nunca destino por comodidad**: si sabés de qué organización es, va a su backlog.

Para escribir en una organización que no es la de la sesión: cargá su `context.md` y su
`resolver.md`, y repetí con `--load-context`.

## Cómo se decide el destino

1. **¿De qué organización es?** Si no se puede contestar sin preguntar, no se pregunta en el medio de
   otra cosa: va al inbox y se dice.
2. **¿Pertenece a una iniciativa?** Nombrala en el texto entre paréntesis. La tarea vive en el
   backlog igual: el backlog es "qué falta" del nodo organización.
3. **¿Está trabada o postergada?** `--blocked-by` con la referencia que la traba; `--hold` con la
   razón y `--hold-until` con la fecha en que resurge. Un hold sin fecha es vigente indefinido: la
   tarea no vuelve sola nunca más.

## Al terminar

Reportá qué quedó escrito y dónde, en una línea. Si el script dice que el archivo nació o que declaró
un glob, pasalo tal cual: es el sistema escribiéndose solo y no le cuesta nada al operador.

Si tuviste que decidir el destino sin fila del resolver que lo contestara, decilo: esa es una fila
candidata, y el cierre de sesión la ofrece.
