---
command: mount-repo
capability: Montar un repo como cuerpo de un nodo
---

# mount-repo — darle cuerpo a un nodo

Cuando un nodo pasa a construirse, su cuerpo vive en un repo git: specs, decisiones técnicas y
as-built. En el brain queda la cabeza. **Decidir construir y montar el repo son el mismo acto**: el
`repo:` de la cabeza es lo que activa la mecánica de construcción, y lo escribe este comando.

## Cómo se corre

```
.os/core/lib/mount-repo.sh --brain . --head orgs/<slug>/initiatives/<nombre>.md \
  --remote <remote> [--clone-root <ruta absoluta>]
```

## Antes de correrlo

1. **La cabeza ya existe.** El comando monta un repo sobre una cabeza escrita; no la inventa. Si el
   nodo todavía no está, primero se crea.
2. **El remote es el remote, nunca una ruta local.** Lo que se escribe en `repo:` viaja con el brain
   a cualquier máquina; la ruta local es dato de esta.
3. **La raíz de clonado se pregunta una sola vez.** Es la carpeta donde viven los checkouts de esta
   máquina, fuera del brain. Queda escrita en `mounts.md` y no se vuelve a preguntar. **Sin
   respuesta no se inventa un default**: preguntá y esperá.

## Qué hace

| Acto | Dónde |
|---|---|
| `repo: <remote>` | El frontmatter de la cabeza |
| El clon, plano y fuera del brain | `<raíz de clonado>/<nombre del repo>` |
| La fila `remote → ruta local` | `mounts.md` de la raíz del brain |

`mounts.md` **no viaja**: el comando lo crea con su primer dato, lo declara en el `.gitignore` del
brain y appendea su glob a `tree.md`. En una máquina nueva la tabla no está — los barridos reportan
el montaje como no alcanzado y correr `mount-repo` sobre el mismo remote la reconstruye. Esa es la
degradación diseñada, no un error.

Correrlo dos veces sobre el mismo remote no duplica la fila ni vuelve a clonar.

## Cuándo frena

| Exit | Qué pasó | Qué hacer |
|---|---|---|
| 2 | La cabeza no existe, o su frontmatter no se puede leer | Crear o arreglar la cabeza |
| 3 | El remote no responde | Verificar el remote y los permisos |
| 4 | La cabeza ya declara **otro** `repo:` | Es del operador: preguntarle cuál queda |
| 5 | La raíz de clonado falta, o cae adentro del brain o de otro repo | Preguntar dónde van los checkouts |

En los cinco casos no se escribió nada. Un nodo montado a medias es peor que uno sin montar.

## Al terminar

Reportá qué quedó escrito y dónde, en una línea. Si el script dice que la tabla nació o que declaró
un glob, pasalo tal cual.

El desmonte no existe todavía: sacar un montaje es editar `mounts.md` y la cabeza a mano.
