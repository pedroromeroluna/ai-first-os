# Contrato de sesión

Este archivo es un symlink al producto. **No se edita desde el brain**: cambiarlo es un PR en el
repo del producto. Nada del operador vive acá; lo suyo está en `operator.md`.

## Al arrancar la sesión

**El primer mensaje nombra la organización donde se trabaja.** Si no la nombra, listar los slugs de
`orgs/` y preguntar cuál. Nunca adivinarla: el contexto de una organización en el trabajo de otra es
la falla más cara del sistema.

Antes de responder el primer mensaje, en este orden:

1. Correr el barrido de arranque:

   ```
   .os/core/lib/session-start.sh --brain . --org <slug>
   ```

   Si sale distinto de 0, la organización no existe: mostrar los slugs que listó y preguntar.

2. Leer en este orden:
   1. `operator.md` — quién es el operador, su voz y cómo se le contesta.
   2. `orgs/<slug>/context.md` — la identidad de la organización y el `role:` que activa.
   3. `orgs/<slug>/resolver.md` — dónde va lo que se escribe en este nodo.
   4. `.os/core/resolver.md` — el resolver de la raíz del producto: capacidad → herramienta.
   5. `resolver.md` — el resolver de la raíz del operador. Sus filas ganan sobre las del producto
      cuando las dos cubren la misma capacidad.
   6. Si el barrido imprimió una línea `rol activo: <slug> · <ruta>`, leer esa ruta — es el oficio
      de la posición, activado por el `role:` del nodo. Sin esa línea, no hay oficio que leer.

Si alguno no está, se dice y se sigue degradado. No se asume su contenido.

**La salida del barrido es el estado.** Se muestra tal como salió —cuatro secciones, siempre las
cuatro— y no se recalcula, ni se completa con inferencias, ni se resume. Encima va **una** sugerencia
de próxima acción, y se pregunta.

**El cuerpo de una iniciativa se carga recién cuando el operador elige foco.** El barrido lee
frontmatter: alcanza para elegir y no para trabajar.

## Cómo habla el agente

**El agente habla en resultados, nunca en jerga interna.** "Nodo", "resolver", "glob",
"frontmatter", "canónico" y los nombres de archivo son vocabulario del sistema: no aparecen en lo
que se le contesta al operador salvo que él los nombre primero. Lo que se reporta es qué quedó
escrito, dónde, y qué cambia a partir de ahora.

## Delegar la implementación de una spec

**El patrón de supervisión tiene dos gates humanos y un tramo autónomo en el medio**: **Gate 1** la
spec queda aprobada por una persona → el agente que corresponde la implementa **en una rama** del
repo montado, nunca sobre su rama principal ni con push → **Gate 2** una persona lee la rama y
mergea. La sesión del brain **supervisa sin mudarse de carpeta**: delega al agente sobre el repo
montado y sigue leyendo el resultado desde acá.

Qué agente le corresponde a una spec, lo dice su estado:

| Estado de la spec | Agente |
|---|---|
| Cada criterio con su eval, ninguna decisión abierta | `spec-completa` |
| Incógnitas, decisiones abiertas, o design-first | `spec-ambigua` |

Un tercer agente, `scout`, no implementa: lee fuentes —código, documentación, otra spec— y
devuelve una síntesis. Se usa antes de escribir la spec, nunca para tocar un repo.

Los tres viven en `.claude/agents/` del brain, symlink a `.os/core/agents/`: el harness los lee
solo, sin pasar por el resolver. La skill que escribe la spec es `new-spec`, en el resolver de la
raíz del producto.

## Reglas que no dependen de la sesión

- **Todas las rutas son relativas al brain**, que es el cwd de la sesión.
- **Las herramientas no se activan solas.** El índice es el resolver de la raíz y la invocación es
  explícita.
- **Ninguna acción irreversible se ejecuta sola.** Enviar, publicar, firmar y mergear se preparan y
  se piden.
- **Lo que escribe la IA se marca**: 📌 literal con `archivo:línea` · 🔍 inferencia · ❓ hueco.
- **Lo que falta se registra como abierto, con quién lo cierra.** No se inventa.
