---
command: sweep
capability: See what is pending
capability: See what is blocked and why
capability: See how the roadmap is going
description: Run one of the three global scans over every workspace plus the root's own work — what is pending, what is blocked and why, or how the roadmap is going — reading frontmatter only. Manually triggered; the mode is an argument, not a separate command.
description_es: Corre uno de los tres barridos globales sobre todos los espacios de trabajo más el trabajo propio de la raíz — qué hay pendiente, qué está trabado y por qué, o cómo va el roadmap — leyendo solo frontmatter. Se dispara a mano; el modo es un argumento, no un comando aparte.
---

# sweep — the three global scans

Three modes of one tool, not three commands. They answer "what do I have pending?", "what is blocked
and why?" and "how is the roadmap going?" reading frontmatter only, across every organization at
once — and the root's own work along with them, grouped separately.

## How it is run

```
.os/core/lib/sweep.sh --brain . --mode pending
.os/core/lib/sweep.sh --brain . --mode blocked
.os/core/lib/sweep.sh --brain . --mode roadmap
```

The environment table —the one mapping a mounted node's remote to its local path on this machine—
is read on its own from `mounts.md`, at the root of the brain: `--mounts <path>` is an override and
does not need to be passed. With no table the scan covers the brain only and says so; with a mount
declared and not cloned, it reports it as unreachable and continues. `mount-repo` writes it.

## What to do with the output

**The output is the state.** It is shown exactly as it came out and it is not recomputed, nor
completed with inferences, nor summarized. Above it goes a one-line reading and a suggested next
action.

**Whatever shows up under "Sin clasificar" is never guessed.** A head without `status` or without
`horizon` has no state the scan can deduce: the operator is offered the chance to write it, with the
path.

**The body of an initiative is loaded only once the operator picks a focus.** The scan reads
frontmatter: enough to choose, not enough to work.
