---
command: rename-heads
capability: Adopt the single node shape in an existing brain
description: Move a brain born before the single node shape to it — every node becomes a folder with its `README.md` inside, every initiative gets its own folder, and each product's dated documents move to `research/` — rewriting the head paths everywhere the system reads them as routing and listing what it leaves untouched. Manually triggered, run only when the operator asks — never by the installer or the startup scan.
description_es: Mueve un brain nacido antes de la forma única de nodo a esa forma — cada nodo pasa a ser una carpeta con su `README.md` adentro, cada iniciativa tiene su carpeta, y los documentos fechados de cada producto van a `research/` —, reescribiendo las rutas de cabeza en todo lo que el sistema lee como ruteo y listando lo que deja sin tocar. Se dispara a mano, solo cuando el operador lo pide — nunca lo corre el instalador ni el arranque de sesión.
---

# rename-heads — adopt the single node shape

Every node is a folder with the name of the thing, and its head inside, called `README.md`. A brain
born before that keeps its previous shape and keeps working exactly as before: the shape is read
from the brain's own tree, and nothing forces it to change. This command is how it adopts the
current shape, on the operator's own schedule.

**It runs only when the operator asks.** Nothing else in the system calls it — not the installer,
not the startup scan.

## What it does, in order

```
.os/core/lib/rename-heads.sh --brain .
```

1. Reads the shape from the tree, at both heights that declare heads — the workspace and the
   initiatives. If both already declare `README.md`, it says there is nothing to do and exits,
   having changed nothing. A brain with one height in each shape is not an error: it is a brain
   half-migrated, and this command finishes the height that is still in the previous shape.
2. Plans every move before making any — the heads, the initiatives, the dated documents — and
   refuses if anything is already sitting at a destination: `x.md` next to `x/README.md`, the
   previous head next to a `README.md` in the same folder, or a `research/` that already carries a
   dated document with the same name. It names each pair and touches nothing, not one file: which
   one stays is the operator's, never a guess.
3. Moves the head of every workspace and every product to `README.md`.
4. Moves the head of every initiative to `initiatives/<slug>/README.md`, creating the folder or
   entering the one that already exists — a body that was already there stays where it is.
5. Moves each product's dated documents (`YYYY-MM-DD-*.md`) from `context/` to `research/`, so
   `context/` keeps one meaning: the product's strategic layer.
6. Rewrites the head paths in what the system reads as structure or routing — the resolvers, the
   backlogs, the decisions, the environment table and the heads themselves — **only where the text
   matches exactly a path this run moved**, or that same path written relative to the node that owns
   the file. Never by suffix: a path under `docs/` that ends the same way but is nobody's head is
   left alone, and so is a URL carrying the same path inside — with a scheme or in `user@host:path`
   form. A `#anchor`, a trailing `:line`, and a leading `./` are split off and put back.
   **A bare name — no slash at all — is never resolved against the folder of the file that names
   it**: inside a node's folder, `README.md` written on its own is prose about some other repo far
   more often than a reference to that node's head, and rewriting it touched text nobody moved.
7. Rewrites the tree last: while it still declares the previous shape, a run cut in the middle
   still knows what the head was called and the next run finishes on its own.
8. **Rewrites nothing else.** It lists every `.md` file that still names a head in the previous
   shape, with how many times, and leaves it there. That list is the operator's, never assumed.
9. **Does not commit.** Like everything else written during a session, the close commits it.

Every move is a `git mv` when the brain is a git repo, so the index records it as a rename, and a
`mv -n` otherwise — never one that can overwrite.

**Two known limits, both of which fail by not rewriting:**

- A path with spaces inside is not rewritten: the text is split into tokens by space. It shows up in
  the list of step 8, and is reviewed by hand.
- A head named by its bare file name is not rewritten either, on purpose: see above.
- A reference that names a head without being a path —free prose, a half-written path, a link whose
  text differs from its target— is not rewritten either. That is the same list.

If the tree declares no head at all, the command says so and exits without touching anything: it
does not guess what a node is in a brain it cannot read.

## When it finishes

- Report what moved and what got rewritten, in outcomes.
- Pass through the list of files left untouched, whole — it is what the operator reviews next, not
  a detail to summarize away.
- Run it twice in a row and the second run says there was nothing left to do: it is safe to repeat.
