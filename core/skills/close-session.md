---
command: close-session
capability: Close the session without losing anything
handoff: Capture something on the fly
description: Close a session by distributing what it produced —decisions, learnings, pending items, what stayed waiting, where to resume— into the loaded node's canonical files, and end with a four-part verdict that names what was not captured. Manually triggered, at the end of a session.
description_es: Cierra la sesión repartiendo lo que produjo —decisiones, aprendizajes, pendientes, lo que quedó esperando, por dónde retomar— en los archivos canónicos del nodo cargado, y termina con un veredicto de cuatro partes que nombra lo que no se capturó. Se dispara a mano, al final de una sesión.
---

# close-session — closing by distributing what the session left

A session that ends leaves material that is in no file. This spreads it across the loaded node's
canonical files and ends with an honest verdict: what was captured, what was **not**, and where it
resumes.

## The two questions

Both are asked, always, in this order:

1. **What cannot be lost from this session?** Decisions, learnings and pending items come out of
   that answer.
2. **Was there anything that almost worked?** The attempt with no conclusion, the reasonable but
   wrong filing, the tool that did something close to what was asked. **This is the question nobody
   answers on their own**: when the agent does nothing it shows immediately; when it does something
   almost right, nobody reports it. It goes to the learnings marked `provisional`.

Material is never invented to fill the file. If the session left nothing of one class, that class
gets no line.

## How it is run

You write the material with whatever came out of the two questions —one key per line— and run:

```
.os/core/lib/close-session.sh --brain . --org <slug> --material <file>
.os/core/lib/close-session.sh --brain . --root --material <file>
```

`--root` closes over the root's own work — the same material, the same canonical files, without
the workspace's folder in front. It asks for neither `--session-org` nor `--load-context`: the root's
identity (`operator.md`) is already loaded in any session.

```
decision:      Title
what:          What is decided
why:           Why
replaces:      Which decision it replaces      (optional)
invalidates:   What would make it false        (optional)
learning:      Title
body:          The body
provisional:   Title
body:          The body
pending:       Text of the task
pending-from:  initiative | Text of the task
waiting:       initiative | who unblocks it
unrouted:      destination | content you filed there
not-captured:  What you could not file, and why
touched:       Path relative to the scope        a file the session edited by hand, to commit
resume:        Where the next session picks up
```

The keys are the input format the script reads: they are written exactly as shown. The script also
still accepts the old Spanish keys (`que`, `porque`, `reemplaza`, `invalidaria`, `cuerpo`,
`pending-de`, `sin-fila`, `no-capturado`, `tocado`, `retomar`) during this version — the verdict
names each old key used, once per close (spec 033), as an indented note under the header, in the
operator's language, followed by a blank line before "Captured".

`touched:` names a file the session edited directly — not through this script — that belongs in the
same commit as the rest of the close. One line per file.

**The operator's text always goes at the end of its line and is filed whole.** After the key there
is at most one structural field —an initiative, a path— ending in `|`; whatever follows is free text
and keeps all the rest, pipes included. **Never split it yourself and never strip characters from
it**: if a sentence carries a `|`, it goes through as is. One record closes when the next one
starts.

**Everything you write in the material comes from the operator, not from you.** A decision they did
not make is not a decision: it is an inference, and it goes as `not-captured` so they can see it.

`waiting:` is written when the session leaves an initiative waiting on something — a gate, a person,
a third party. The value says who unblocks it: that is what puts it at the top of the next session
start. It names an initiative that already exists: the script writes `waiting_on:` into its head and
declares it when the head is not there. No command creates one — an initiative that is missing is
written by hand at `initiatives/<slug>/README.md`, a folder with the name of the thing and its head
inside.

## The verdict

**It is shown exactly as it came out.** The five parts are fixed: captured, not captured, candidate
row, what stayed uncommitted, and the pointer to resume. **It never closes with a bare "done"**: a
close that only says it finished cannot be told apart from one that lost something.

If the verdict offers a candidate row for the resolver, you show it to the operator and write it
only if they say yes. The resolver grows by exception found; a row they did not approve is an edge
nobody is going to use.

## The close commits

Closing and committing are the same act. The close stages and commits, in the brain's own git repo,
what this script wrote plus every `touched:` that exists and is modified — never `git add -A`: a
file that is neither of those two is somebody else's session in progress, and it is named under
"Uncommitted (not from this session)" instead of being touched. Without a git repo at the brain's
root, nothing is committed and the fifth part says so. If the commit itself fails — git identity
never configured, a hook in the brain — the close does not abort or bypass anything: it says so and
what would have been committed shows up uncommitted, same as an edit from another session.
