---
command: archive
capability: Move a document out of what a focus loads, without losing it
description: Move a document into the node's `archive/` so the focus stops loading it and starts listing it by name, rewriting every reference that pointed at it — and bring it back the same way. It also lists the documents the brain already declared out of date and still keeps outside `archive/`. Manually triggered.
description_es: Mueve un documento al `archive/` del nodo para que el foco deje de cargarlo y pase a listarlo por nombre, reescribiendo todas las referencias que lo apuntaban — y lo trae de vuelta igual. También lista los documentos que el brain ya declaró fuera de vigencia y sigue teniendo fuera de `archive/`. Se dispara a mano.
---

# archive — archiving a document is moving it

The body of a node only grows. A piece of research from July that nobody reads any more costs the
same to load as the brief that is current. The answer is not a key that says "old": it is the folder
the document sits in.

## How it is run

```
.os/core/lib/archive.sh --brain . --file <path> [--file <path> …]
.os/core/lib/archive.sh --brain . --file <path> [--file <path> …] --unarchive --to <folder>
.os/core/lib/archive.sh --brain . --stale
```

Every path is relative to the brain. `--unarchive` needs `--to`, because the folder a document came
from is recorded nowhere: the move keeps the bytes and the name, and nothing else.

## What it does

| Step | What happens |
|---|---|
| The plan | Every file is checked and its destination computed before one byte moves |
| The moves | `<node>/<folder>/<name>.md` → `<node>/archive/<name>.md`, with `git mv` in a git brain |
| The references | Every file the tree reaches is rewritten, once, with the map of everything that moved |

The document is moved, never rewritten: same bytes, same name, same date in the name. A file **is**
rewritten when it carries a reference to something else that moved — that is the third step, and the
output names every file it touched.

## What changes after it

| Before | After |
|---|---|
| The focus loads the document | The focus prints its name under `archived:` and opens none of it |
| `recall` finds it | `recall` finds it |
| `supersede --check` audits it | `supersede --check` audits it |
| The scan counts it as reached | The scan counts it as reached |

A document that stopped being loaded and also stopped being findable would be lost, not archived.

## What it refuses

| Refusal | Why |
|---|---|
| a path that is not `.md`, or that no line of `tree.md` reaches | The command moves documents of the brain; anything else is a file this system does not govern |
| an absolute path, a `..`, or one that resolves outside the brain | Every path is a path of this brain |
| a symbolic link | A link is never followed |
| a file that does not live inside a node | There is no `archive/` next to it |
| a file already archived, or —with `--unarchive`— one that is not | Nothing to move |
| a destination that already exists | Choosing which of the two wins is not a script's call |
| a destination no `archive:` line of the tree reaches | An archived file the tree does not reach is invisible to the audit and to `recall` |
| the same file named twice in one batch | Two plans for one path |

**One refusal cancels the whole batch**: nothing moves, and the output says so. A batch half applied,
with half its references rewritten, is a state the operator would have to reconstruct by hand.

If a move fails after the plan passed —a folder with no write permission— the batch stops there. What
moved stays moved with its references rewritten, what did not is exactly where it was, the output
lists both, and re-running the same command finishes the job. Nothing is rolled back: a rollback is a
second write that can fail too.

## What `--stale` reports

One line per document that carries a `superseded_by:` and still lives outside `archive/` — the brain
already said it was replaced, and it is still being loaded. It writes nothing and exits non-zero when
it found something.

There is no line about this in the session scan, on purpose. Age is not staleness: a brief from July
can be the most current document a node has, and a scan line with a threshold would come back every
session without leading to a decision. The scan also reads the frontmatter of heads and never opens a
content file, so it would count half of them.

## On a brain that already existed

`tree.md` is what declares where an `archive/` is legitimate, and a brain born before this command
does not have those lines. The first run says so, naming the destination no line reaches; adding them
is the same one-line step every other height of this system takes:

```
archive: workspaces/*/products/*/archive/*.md
archive: workspaces/*/initiatives/*/archive/*.md
archive: initiatives/*/archive/*.md
```

## What it does not do

It does not decide that a document is done. Deciding is the operator's. It also does not commit: the
session commits, like everything else it writes.
