---
command: mount-repo
capability: Mount a repo as the body of a node
description: Give an initiative a body: write the remote into the head's frontmatter, clone the checkout outside the brain, and record the remote-to-local-path row in the machine's environment table. Manually triggered, once per initiative that starts being built.
description_es: Le da cuerpo a una iniciativa: escribe el remote en el frontmatter de la cabeza, clona el checkout afuera del brain y registra la fila remote → ruta local en la tabla del entorno de la máquina. Se dispara a mano, una vez por iniciativa que empieza a construirse.
---

# mount-repo — giving a node a body

When a node starts being built, its body lives in a git repo: specs, technical decisions and
as-built. The head stays in the brain. **Deciding to build and mounting the repo are the same act**:
the head's `repo:` is what activates the building mechanics, and this command writes it.

## How it is run

```
.os/core/lib/mount-repo.sh --brain . --head orgs/<slug>/initiatives/<name>.md \
  --remote <remote> [--clone-root <absolute path>]
```

## Before running it

1. **The head already exists.** The command mounts a repo onto a head that is written; it does not
   invent one. If the node is not there yet, it is created first.
2. **The remote is the remote, never a local path.** What gets written into `repo:` travels with the
   brain to any machine; the local path is data of this one.
3. **The clone root is asked once.** It is the folder where this machine's checkouts live, outside
   the brain. It ends up written in `mounts.md` and is never asked again. **With no answer no
   default is invented**: ask and wait.

## What it does

| Act | Where |
|---|---|
| `repo: <remote>` | The head's frontmatter |
| The clone, flat and outside the brain | `<clone root>/<repo name>` |
| The `remote → local path` row | `mounts.md` at the root of the brain |

`mounts.md` **does not travel**: the command creates it with its first piece of data, declares it in
the brain's `.gitignore` and appends its glob to `tree.md`. On a new machine the table is not there
— the scans report the mount as unreachable and running `mount-repo` on the same remote rebuilds it.
That is the designed degradation, not an error.

Running it twice on the same remote neither duplicates the row nor clones again.

## When it stops

| Exit | What happened | What to do |
|---|---|---|
| 2 | The head does not exist, or its frontmatter cannot be read | Create or fix the head |
| 3 | The remote does not answer | Check the remote and the permissions |
| 4 | The head already declares **another** `repo:` | It belongs to the operator: ask which one stays |
| 5 | The clone root is missing, or falls inside the brain or inside another repo | Ask where the checkouts go |

In all five cases nothing was written. A half-mounted node is worse than an unmounted one.

## When it finishes

Report what was written and where, in one line. If the script says the table was born or that it
declared a glob, pass it through as is.

Unmounting does not exist yet: removing a mount is editing `mounts.md` and the head by hand.
