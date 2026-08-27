---
command: new-memory
capability: Add a memory node of any type
description: Create a memory-node type the first time it is used —a folder plus its five lines in `tree.md`— and add a node to it. Two questions —what kind of thing this is, and what this particular one is, for whom— and it writes the head of the node. Manually triggered, once per type or per node.
description_es: Crea un tipo de nodo de memoria la primera vez que se usa —una carpeta más sus cinco líneas en `tree.md`— y le suma un nodo. Dos preguntas —de qué tipo de cosa se trata, y qué es esta en particular, para quién— y escribe la cabeza del nodo. Se dispara a mano, una vez por tipo o por nodo.
---

# new-memory — create a memory node, of any type

A memory node holds what something is and what is known about it. It is not an initiative — an
initiative is push: state, horizon, when it closes. A memory node can outlive every initiative built
around it, and an initiative never needs one to exist.

**The folder is the type.** `products/` is the one type this system ships with its own tool (`prd`
writes its strategic layer). Any sibling folder of nodes that hold memory instead of push works the
same way: `accounts/` for client accounts, `channels/` for content channels, or a name the operator
invents. There is no `type:` field anywhere — the path already says what kind of thing a node is.

A memory node hangs off the workspace that owns it (`workspaces/<ws>/<type>/<slug>/`), or off the
root when the type belongs to the operator's own work (`<type>/<slug>/`, with `--root`) — `channels/`
of a personal brain is a case of this.

## The interview

Two questions. Nothing else.

1. **What kind of thing is this — an existing type, or a new one?** If the type already exists,
   nothing about its tree lines is asked again; this call only names it (`--type accounts`). If it
   is new, the type is born with its first node, and its five lines land in `tree.md` the same run.
2. **What is this node, and which workspace does it belong to (or is it the operator's own work)?**
   Two or three lines — what it is and what is known, not the whole strategic layer. Skip the
   workspace half of the question if the session already has one loaded — use that. Otherwise ask,
   and never guess it: the wrong workspace is the most expensive mistake this system can make.

## What it writes

```
.os/core/lib/new-memory.sh --brain . --workspace <slug> --type <type> --name "<Name>" \
  --owner "<person>" [--identity-file <file>]
.os/core/lib/new-memory.sh --brain . --root --type <type> --name "<Name>" --owner "<person>" \
  [--identity-file <file>]
```

Leaves `<scope>/<type>/<slug>/README.md` with the identity. Nothing else: `context/`, `research/`,
`resolver.md` and `decisions.md` are born with their first piece of data, same as every other
canonical file in this system. The first time a type is used, its five lines of `tree.md` are added
—3 `glob:` (the head, `resolver.md`, `decisions.md`) and 2 `content:` (`context/*.md`,
`research/*.md`)— so every scan of the system reads it from the first node on; a second node of the
same type never duplicates those lines.

`--owner` comes from the title of `operator.md`, same as `new-workspace` and `new-product`: the node
is created by the operator, so they are the owner unless someone else runs it.

**The head never gets `role:` and never gets `repo:`.** `role:` activates a standing oficio and that
activation is per workspace, not per memory node. `repo:` is written by `mount-repo`, and `mount-repo`
gives a body to an initiative, never to a memory node: the two stay linked only by reference, never
by folder.

If the workspace named does not exist, the command refuses and lists the workspaces that do — it
never creates one on the spot. Running it twice with the same type and slug refuses the second time:
two nodes with the same identity are the operator's call, not a default. `--root` and
`--workspace`/`--org` together are an error, same as naming two different workspaces at once.

**Naming a type**: a type this product ships with (today, only `products`) is named in English. A
type the operator invents is named however they like — it is content of their brain, not a
component of the system. A recommended catalog, and what a type without its own tool means, is in
this manual, under "Memory nodes: any folder can be a type."

`new-product` is a shortcut for the one type that ships with a purpose-built tool (`prd`, which
writes its strategic layer): it is exactly `new-memory --type products`, and its own output never
changes.

## When it finishes

Report what was created, in outcomes: the node now has a place to hold what is known about it, and
—if the type is new— that every scan of the system reads it from now on.
