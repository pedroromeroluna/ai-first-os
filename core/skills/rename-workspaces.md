---
command: rename-workspaces
capability: Rename the workspaces folder of an existing brain
description: Move a brain still using the previous name of the workspaces folder to the current one, rewriting the prefix everywhere the system reads it as structure or routing, and listing what it leaves untouched for the operator to review. Manually triggered, run only when the operator asks — never by the installer or the startup scan.
description_es: Mueve un brain que todavía usa el nombre anterior de la carpeta de espacios de trabajo al nombre actual, reescribiendo el prefijo en todo lo que el sistema lee como estructura o ruteo, y listando lo que deja sin tocar para que el operador lo revise. Se dispara a mano, solo cuando el operador lo pide — nunca lo corre el instalador ni el arranque de sesión.
---

# rename-workspaces — adopt the current name of the workspaces folder

A brain born before this rename keeps its folder under the previous name and keeps working exactly
as before: nothing forces it to change. This command is how it adopts the current name, on the
operator's own schedule.

**It runs only when the operator asks.** Nothing else in the system calls it — not the installer,
not the startup scan. `install.sh` prints one line the first time it hooks up a brain still on the
previous name, naming this command; it never runs it.

## What it does, in order

```
.os/core/lib/rename-workspaces.sh --brain .
```

1. Checks the layout is valid and is the previous one. With the two folders at once, or with the
   tree declaring one and the disk only carrying the other, it refuses and touches nothing — same
   check every other command in the system runs first. With nothing to rename (the brain already
   uses the current name), it says so and exits, having changed nothing.
2. Moves the folder to its current name — `git mv` when the brain is a git repo, so the index
   records it as a rename; a plain move otherwise.
3. Rewrites the previous prefix to the current one in every file the system reads as structure or
   routing: the tree, the root resolver, each workspace's resolver, the root backlog and each
   workspace's backlog, and the environment table.
4. **Rewrites nothing else.** Decisions, contexts, initiatives, any free prose the operator wrote —
   it lists every `.md` file that still carries the previous prefix, with how many times, and
   leaves it there. That list is the operator's, never assumed.
5. **Does not commit.** Like everything else written during a session, the close commits it.

## When it finishes

- Report what moved and what got rewritten, in outcomes.
- Pass through the list of files left untouched, whole — it is what the operator reviews next, not
  a detail to summarize away.
- Run it twice in a row and the second run says there was nothing left to do: it is safe to repeat.
