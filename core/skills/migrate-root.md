---
command: migrate-root
capability: Move a brain's own root work into its personal workspace
description: Move the operator's own work from a brain still carrying it directly at the root — initiatives, a memory-node type, backlog, decisions, learnings — into the `personal` workspace every brain is born with today, creating that workspace first if it does not exist yet, rewriting the prefix everywhere the system reads it as structure or routing, and listing what it leaves untouched for the operator to review. Manually triggered, run only when the operator asks — never by the installer or the startup scan.
description_es: Mueve el trabajo propio del operador de un brain que todavía lo tiene escrito directamente en la raíz —iniciativas, un tipo de nodo de memoria, backlog, decisiones, aprendizajes— al espacio de trabajo `personal` con el que todo brain nace hoy, creando ese espacio de trabajo primero si todavía no existe, reescribiendo el prefijo en todo lo que el sistema lee como estructura o ruteo, y listando lo que deja sin tocar para que el operador lo revise. Se dispara a mano, solo cuando el operador lo pide — nunca lo corre el instalador ni el arranque de sesión.
---

# migrate-root — move the root's own work into the personal workspace

A brain born before spec 059 can still have its own work written directly at the root: initiatives,
a memory-node type, `backlog.md`, `decisions.md`/`decisions/`, `learnings.md`/`learnings/`. The root
keeps working exactly as before nothing forces it to change, but the session's startup Checks name
what is still there, with its count. This command is how it moves into `personal`, on the operator's
own schedule.

**It runs only when the operator asks.** Nothing else in the system calls it — not the installer,
not the startup scan. The startup scan names it when it finds root work; it never runs it.

## What it does, in order

```
.os/core/lib/migrate-root.sh --brain .
```

1. With nothing at the root to migrate and nothing left from an interrupted run, says so and exits,
   having changed nothing.
2. Stops before moving anything, naming the reason, when:
   - the `personal` workspace already exists and this migration did not create it — merging two
     workspaces is not this command's job;
   - the destination of anything it is about to move already exists;
   - a mounted repo (a row of `.system/mounts.md`) names the root path of an initiative or a memory node
     about to move. Show the operator every line it prints. Only once the operator has read them and
     decided they can stay — a repo's own history, a fixture that shares the name — run it again
     with `--mounts-reviewed`; the repo itself is never written.
3. Creates `personal` first, if it does not exist yet — the same command any workspace is created
   with.
4. Moves, one item at a time and checking each move: every initiative (with its own `backlog.md`),
   every memory node of a type the root declares, `backlog.md`, `decisions.md`, `decisions/`,
   `learnings.md` and `learnings/`. A decision's or a learning's link inside its index is relative
   to the node, so moving index and folder keeps every link correct.
5. `inbox.md` never moves: deleted only when it holds nothing but whitespace; otherwise every line is
   listed for the operator to route by hand, and the file stays.
6. Rewrites, from the moves it actually made: the root lines of `.system/tree.md` (moved to the workspace
   height), the `about:` of every head that moved, and the routing — the root resolver, the
   environment table, and every resolver and backlog under `personal`. Never another workspace's
   files, never a URL or a path that belongs to someone else.
7. **Rewrites nothing else.** Any free prose that still names a moved path is listed with its
   count, and left there. That list is the operator's, never assumed.
8. **Does not commit.** Like everything else written during a session, the close commits it.
9. A run cut halfway leaves its state in `.os/migrate-root.state`; the next run reads it and
   finishes the moves and the rewrites.

What never moves: `account/` and `.system/` (`mounts.md`, `resolver.md`, `tree.md`) — the root's own
machinery.

## When it finishes

- Report what moved and what got rewritten, in outcomes.
- Pass through the list of files left untouched, whole — it is what the operator reviews next, not
  a detail to summarize away.
- Pass through the inbox's unclassified lines, if any — they are findings, not archived.
- If `personal/backlog.md` was left outside any initiative, say that `migrate-backlogs.sh` splits it
  — the verdict names it.
- Run it twice in a row and the second run says there was nothing left to do: it is safe to repeat.
