---
command: new-product
capability: Add a product
description: Add a product to a workspace that already exists. Two questions —what the product is, and for whom— and it writes the head of the node. Manually triggered, once per product.
description_es: Suma un producto a un espacio de trabajo que ya existe. Dos preguntas —qué es el producto y para quién— y escribe la cabeza del nodo. Se dispara a mano, una vez por producto.
---

# new-product — create a product

A product is memory: what it is, for whom, what is known about it. It is not an initiative — an
initiative is push: state, horizon, when it closes. A product can outlive every initiative built for
it, and an initiative never needs a product to exist.

The product hangs off the organization that owns it, never off the root:
`workspaces/<org>/products/<slug>/`.

## The interview

Two questions. Nothing else.

1. **What is this product, and who is it for?** Two or three lines — what it is and its user, not
   the whole strategic layer. The deep version of that layer (vision, problem, users, scope,
   competitors) is a different tool's job (`prd`), run afterwards, over the node this creates.
2. **Which organization does it belong to?** Skip this question if the session already has one
   loaded — use that. Otherwise ask, and never guess it: the wrong organization is the most
   expensive mistake this system can make.

## What it writes

```
.os/core/lib/new-product.sh --brain . --org <slug> --name "<Name>" --owner "<person>" \
  [--identity-file <file>]
```

Leaves `workspaces/<org>/products/<slug>/README.md` with the identity. Nothing else: `context/`
(the strategic layer `prd` writes), `research/` (every dated document about the product — briefs,
analyses, inventories), `resolver.md` and `decisions.md` are born with their first piece of data,
same as every other canonical file in this system.

`--owner` comes from the title of `operator.md`, same as `new-workspace`: the product is created by
the operator, so they are the owner unless someone else runs it.

**The head never gets `role:` and never gets `repo:`.** `role:` activates a standing oficio and that
activation is per organization, not per product — a `role:` on a product's head would be a promise
nothing reads. `repo:` is written by `mount-repo`, and `mount-repo` gives a body to an initiative,
never to a product: the two stay linked only by reference, never by folder.

If the organization named does not exist, the command refuses and lists the organizations that do —
it never creates one on the spot. Running it twice with the same name refuses the second time: two
products with the same identity are the operator's call, not a default.

## When it finishes

Report what was created, in outcomes: the product now has a place to hold what is known about it,
and any of the pack's discovery tools can be pointed at it.
