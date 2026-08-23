---
command: new-workspace
capability: Add a workspace
description: Add a workspace to an existing brain. Two questions —what the workspace is, and what the operator does there— and it writes the node with its identity, its empty resolver and its initiatives folder. Manually triggered, once per workspace.
description_es: Suma un espacio de trabajo a un brain que ya existe. Dos preguntas —qué es el espacio de trabajo y qué hace el operador ahí— y escribe el nodo con su identidad, su resolver vacío y su carpeta de iniciativas. Se dispara a mano, una vez por espacio de trabajo.
---

# new-workspace — create a workspace

A workspace is each company or client you work for; a course case is one too. It is the isolation
boundary. Creating it on day 40 leaves exactly the same result as declaring it on day 1.

## The interview

Two questions. Nothing else.

1. **What is this workspace?** What it does, for whom and how it makes money. Three or four
   lines.
2. **What do you do here?** The answer is a title — identity, written to the body of the head,
   never to `role:`. Write it down in the operator's own words —"I'm the one who decides product"—
   without translating it into anything. `role:` is a different field: it activates an oficio from
   the pack (today: `cpo`) and is born empty. Filling it in is a separate, deliberate step — this
   interview never sets it.

## What it writes

```
.os/core/lib/new-workspace.sh --brain . --name "<Name>" --role "" --title "<title>" --owner "<person>" \
  [--identity-file <file>]
```

Leaves `workspaces/<slug>/` with its head `README.md`, a `resolver.md` with no rows and an empty
`initiatives/` — on a brain that still carries the previous name of that folder, or the previous
shape of the head, it lands there instead (see `rename-workspaces` and `rename-heads` to adopt the
current ones). Nothing else: whatever only stores content
is born with its first piece of data.

`--owner` comes from the title of `operator.md`: the workspace is created by the operator, so
they are the owner. If the brain does not have it yet —or the workspace is run by someone else—
ask who it is and do not deduce it. `--role` and `--owner` are mandatory because the command writes
them: the operator neither sees those fields nor has to remember they exist. `--role` is passed
empty by this interview; naming an oficio slug there is the deliberate step described above, done
later and outside of it. `--title` carries the answer to question 2 and is optional — with none, the
body's title line is left blank.

The identity comes in through `--identity-file`. You write it with what the operator answered,
without inventing what they did not say: whatever is missing is marked as a gap.

## When it finishes

- Report what was created, in outcomes: what can be written there and what each file answers.
- If the identity cap warning appears, pass it through as is: summarizing or splitting is the
  operator's call.
