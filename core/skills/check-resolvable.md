---
command: check-resolvable
capability: Audit the routing of the root
description: Audit the root's capability-to-tool graph and report the three failures it can have — a tool nothing routes to, a handoff no row provides, and a row pointing at a tool that does not exist. Manually triggered, or hung off a cron; it exits non-zero when it finds something.
description_es: Audita el grafo capacidad → herramienta de la raíz y reporta las tres fallas que puede tener — una herramienta que nadie rutea, un handoff que ninguna fila provee y una fila que apunta a una herramienta que no existe. Se dispara a mano, o colgada de un cron; sale distinto de cero cuando encuentra algo.
---

# check-resolvable — so that no tool stays dark

It audits the root graph: capability → tool. This is the one that runs over the whole system; the
node-level one —content → where— already runs at every session start.

## How it is run

```
.os/core/lib/check-resolvable.sh --brain .
```

It exits non-zero if it found something. That is what it takes to hang it off a cron without anyone
reading the output.

## The three directions, which are three different errors

| Finding | What happened | How it is fixed |
|---|---|---|
| dark capability | The tool is installed and no row reaches it | Add the row that routes it |
| broken link | A handoff names a capability no row provides | Add the row, or fix the capability name |
| capability illusion | A row points at a tool that does not exist | Fix the path, or delete the row |

## What to do with the output

Every finding carries `file:line`. It is fixed by editing markdown, never code: the rows live in
`.os/core/resolver.md` —product origin, changed by PR in the repo— and in `resolver.md` —personal
origin, edited by the operator—.

**A dark capability of the product is not fixed in the brain.** If the missing row belongs to the
product, the right move is the PR; adding it to the personal resolver covers the symptom on one
machine only.
