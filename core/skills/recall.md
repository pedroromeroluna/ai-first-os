---
command: recall
capability: Search everything the tree reaches for a lateral question
description: Search over every file `tree.md` reaches — not only what the startup scan and the focus load — and return the entries that match, with file, line, date and whether each is current or replaced. Expand one result to its neighbours: what it is about, what is about it, what replaced it, what it replaced. Runs on a derived, discardable index that reconciles itself on every call. Manually triggered, and the session runs it on its own before any `grep` for a lateral question.
description_es: Busca en todo lo que `tree.md` alcanza — no solo lo que carga el arranque y el foco — y devuelve las entradas que coinciden, con archivo, línea, fecha y si cada una sigue vigente o fue reemplazada. Expande un resultado a sus vecinos: de qué trata, quién trata de él, qué lo reemplazó, a qué reemplazó. Corre sobre un índice derivado y descartable que se reconcilia solo en cada llamada. Se dispara a mano, y la sesión lo corre por su cuenta antes de cualquier `grep` ante una pregunta lateral.
---

# recall — Living Memory finds what the focus does not load

The startup scan and the focus read only ever open what a fixed list already names. A decision
written in July exists, but nothing finds it unless somebody guesses the word it was written with
and greps by hand over a thousand files. `recall` searches everything the tree reaches instead.

## How it is run

```
.os/core/lib/recall.sh --brain . --workspace <slug> "<query>"
.os/core/lib/recall.sh --brain . --root "<query>"
.os/core/lib/recall.sh --brain . --all "<query>" --limit 10
.os/core/lib/recall.sh --brain . --expand <path>
```

`--workspace` (`--org` is an exact synonym) searches only under that workspace's folder. `--root`
searches only what the tree reaches outside the workspaces folder. `--all` searches everywhere the
tree reaches, in every workspace and the root together. Exactly one of the three is required — none
of them is a default, so crossing the session's own scope is always a choice made out loud. `--limit`
defaults to 5.

## What it prints

```
scope: acme · 3 hits · 412 files indexed
workspaces/acme/decisions.md:88 · 2026-07-11 · current · 2026-07-11 · the coupon lives in the Sheet · the promotion lives in the Sheet as its own row, never as a discount code the checkout applies on its own...
```

One row per result, in relevance order: the file and the line the match starts at, the date, whether
it is `current` or `superseded → <path that replaced it>`, the entry's heading (or list item), and
up to 200 characters of the match in context. A file that was replaced never outranks one that is
current, however strong its match. No results prints one line saying so.

## What it indexes

Every entry — a heading and its body up to the next one, or, for a file whose body is nothing but
top-level list items (`backlog.md`, `inbox.md`, any canonical list of the system), one entry per
item. The frontmatter block is never part of an entry. The index lives at
`.os/living-memory.sqlite`, inside the brain: derived, discardable, and never committed. There is no
hook — every call compares what `tree.md` reaches against what is stored, by size and mtime first
and by content hash only when those changed, before it searches.

## `--expand`: the neighbours one jump away

```
.os/core/lib/recall.sh --brain . --expand workspaces/acme/products/kit/README.md
```

Prints the head this file's `about:` names, the files whose `about:` names this one, the file this
one's `superseded_by:` names, and the files whose `superseded_by:` names this one — one line each,
`<relation> · <path> · <title>`. One jump: what a neighbour itself declares is never followed.

## What it does not do

It does not read meaning across two matches, and it does not follow a chain of more than one jump.
Two `current` results that contradict each other are for the session to notice and report, never
for this command to resolve on its own.
