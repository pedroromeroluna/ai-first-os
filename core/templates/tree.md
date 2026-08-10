# Árbol — qué rutas recorre un barrido

Dos clases de línea, cada una con su prefijo. Ningún barrido descubre el árbol ni asume
profundidad: lee estas líneas. Agregar una altura es agregar una línea acá, no tocar scripts.

- `glob:` — lo que un barrido lee como cabeza: frontmatter con `status`, `horizon`, etc.
- `content:` — lo que un barrido cuenta como alcanzado pero **nunca** lee como cabeza: la voz, un
  registro, el `context/` de un nodo de producto, el cuerpo de una iniciativa con carpeta. Sin esta
  línea, ese archivo se acusa como "ningún glob de tree.md alcanza" aunque esté bien escrito.

Los comandos que crean un nivel agregan su glob o su línea de contenido. Un archivo que ninguna de
las dos alcanza es un hallazgo del chequeo, no un caso a ignorar.

glob: operator.md
glob: resolver.md
glob: inbox.md
glob: mounts.md
glob: orgs/*/context.md
glob: orgs/*/resolver.md
glob: orgs/*/backlog.md
glob: orgs/*/decisions.md
glob: orgs/*/learnings.md
glob: orgs/*/initiatives/*.md

content: orgs/*/voice.md
content: orgs/*/records/*.md
content: orgs/*/products/*/context/*.md
content: orgs/*/initiatives/*/*.md
