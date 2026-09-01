---
command: supersede
capability: Mark a file as replaced by another
description: Write on a file the mark that says which other file replaced it, so a session that opens the old one knows what to read instead, and audit the marks of the whole brain — the ones that point at a file that is not there, the ones that close a cycle, and the heads that were replaced and still read as open work. Manually triggered.
description_es: Escribe sobre un archivo la marca que dice qué otro archivo lo reemplazó, para que una sesión que abra el viejo sepa qué leer en su lugar, y audita las marcas de todo el brain — las que apuntan a un archivo que no está, las que cierran un ciclo y las cabezas reemplazadas que siguen leyéndose como trabajo abierto. Se dispara a mano.
---

# supersede — a file declares what replaced it

A research document from March and one from July that contradicts it are two files a session reads
as equally current. Git does not settle it: the agent reads the working tree, never the history. The
answer is one line in the older file, naming the newer one.

## How it is run

```
.os/core/lib/supersede.sh --brain . --file <old path> --by <new path>
.os/core/lib/supersede.sh --brain . --check
```

Both paths are relative to the brain. The mark goes on the file that **was** replaced and points
forward; the rule itself lives in `.os/core/CLAUDE.md`, and this file does not restate it.

## What it writes

One key in the frontmatter of the old file:

```
superseded_by: workspaces/acme/products/kit/research/2026-07-11-kit.md
```

A file that has no frontmatter at all gets a three-line block created above its body, untouched. A
file whose frontmatter cannot be read —no closing `---`, or past the bound— is refused with the
reason: writing over it would corrupt it in silence.

## What it refuses

| Refusal | Why |
|---|---|
| a path that is not `.md`, or that no line of `tree.md` reaches | The mark goes on documents of the brain; anything else is a file this system does not govern |
| an absolute path, a `..`, or one that resolves outside the brain | Every path of the mark is a path of this brain |
| a symbolic link | Mark the file it points at, by its own path |
| a body that opens with a `---` that is not a frontmatter | The key would land in the middle of the prose |
| a file it cannot write | A write that did not happen never reports success |
| a `--by` that leads back to `--file`, or a chain it could not finish | A cycle hangs whoever follows it, and undecided is not the same as clean |

## What happens to a head

When the file is the head of a node or an initiative and its `status` is `active` with nothing
depending on it, the status also goes to `closed` — and the output says so. Three heads are left as
they are, with the mark written, the reason printed and exit code 3:

| State of the head | Why it stays open |
|---|---|
| `ongoing` | Permanent work does not end because a document was replaced |
| `blocked` | Closing it drops what it is waiting for without anyone reading it |
| another head declares it in `depends_on:` | A closed dependency reads as satisfied, and that other head would show as unblocked by nobody |

In those three the decision is the operator's: close it by hand, or re-point what depends on it.

## What `--check` reports

| Finding | What to do |
|---|---|
| points at nothing | Fix the path, or drop the key |
| points at itself | Drop the key |
| cycle | Two files, or twenty, lead back to the first; decide which one is current and drop the other keys |
| chain undecided | The chain is longer than the walk's bound; read it by hand |
| mark inside an unreadable frontmatter | Close the frontmatter, or the mark exists for nobody |
| open head | Its `status` is `active` after the mark; close it |

It exits non-zero when it found something and writes nothing, which is what it takes to hang it off
a cron. Over a brain whose `tree.md` it could not read it exits non-zero too, instead of reporting
that everything resolves.

## What it does not do

It does not decide that a document is stale. Deciding is the operator's; this command records the
decision where the next session will read it.

There is no line about this in the session scan, on purpose: the scan reads the head of every node
and never opens a content file, and the documents this mark exists for are content. A startup line
would count half of them. The audit above covers both.
