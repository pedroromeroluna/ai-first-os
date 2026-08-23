---
command: mount-repo
capability: Mount a repo as the body of a node, or give birth to it if it does not exist yet
description: Give an initiative a body: write the remote into the head's frontmatter, clone the checkout outside the brain —or, with --new, give birth to the repo from the product's scaffold when it does not exist yet— and record the remote-to-local-path row in the machine's environment table. Manually triggered, once per initiative that starts being built.
description_es: Le da cuerpo a una iniciativa: escribe el remote en el frontmatter de la cabeza, clona el checkout afuera del brain —o, con --new, hace nacer el repo desde la plantilla del producto cuando todavía no existe— y registra la fila remote → ruta local en la tabla del entorno de la máquina. Se dispara a mano, una vez por iniciativa que empieza a construirse.
---

# mount-repo — giving a node a body

When a node starts being built, its body lives in a git repo: specs, technical decisions and
as-built. The head stays in the brain. **Deciding to build and mounting the repo are the same act**:
the head's `repo:` is what activates the building mechanics, and this command writes it.

## How it is run

```
.os/core/lib/mount-repo.sh --brain . --head workspaces/<workspace>/initiatives/<slug>/README.md \
  --remote <remote> [--clone-root <absolute path>] [--new]
```

## Before running it

1. **The head already exists.** The command mounts a repo onto a head that is written; it does not
   invent one. If the node is not there yet, it is created first — a folder with the name of the
   initiative and its `initiatives/<slug>/README.md` inside. On a brain that still keeps its heads in
   the previous shape, the head is where that brain has it (see `rename-heads`).
2. **The remote is the remote, never a local path.** What gets written into `repo:` travels with the
   brain to any machine; the local path is data of this one.
3. **The clone root is asked once.** It is the folder where this machine's checkouts live, outside
   the brain. It ends up written in `mounts.md` and is never asked again. **With no answer no
   default is invented**: ask and wait.

## What it does

| Act | Where |
|---|---|
| `repo: <remote>` | The head's frontmatter |
| The clone, flat and outside the brain | `<clone root>/<repo name>` |
| The `remote → local path` row | `mounts.md` at the root of the brain |
| The checkout authorized for the harness | `permissions.additionalDirectories` in `.claude/settings.local.json` |
| With `--new`: the repo born from the product's scaffold, its first commit on `main` and `origin` declared | `<clone root>/<repo name>`, in the clone's place |

**`--new` is for a repo that does not exist yet**: instead of cloning, it writes the scaffold
—`CLAUDE.md` with the two gates and the Definition of Done, `.claude/settings.json` denying the
agents `git push` and `gh pr merge`, `ARCHITECTURE.md`, `decisions.md`, `learnings/`,
`docs/postmortems/`, `docs/research/`, `specs/done/`, `evals/run.sh`—, commits it and points
`origin` at the remote. The prose comes out in the brain's language.

**`--new` reads "the remote does not answer" as "it does not exist yet".** A private repo that does
exist and answers with an authentication error reads the same from here: if credentials are what is
missing, `--new` is not the way — fix the access and mount it with the plain command, or the head
ends up pointing at a repo that was born next to the one that was already there.

**The remote is not created and nothing is pushed.** That escapes the system: the command closes by
printing two commands for the operator to run — `gh repo create <owner>/<name> --private` if `gh` is
authenticated and the remote is a GitHub one, or creating it at the provider by hand if it is not,
and then `git -C '<path>' push -u origin main`. The owner comes from the remote itself, never from
whoever is authenticated, and the creation never carries `--source`/`--push`: over a checkout that
already declares `origin`, that combination fails and does not push. The repo lives locally, mounted
and complete, until the operator runs them.

**Running `--new` twice is safe.** Over a repo already born at `<clone root>/<repo name>` with that
`origin`, it does not give birth again: it says so and completes the other four acts. That is what
makes a birth interrupted halfway resumable — the same command, again.

Mounting and authorizing are the same act: the checkout stops needing a permission prompt file by
file for whoever works on it next, **from the next session of the harness on** — a settings file
already loaded when the session started does not pick up a mid-session edit.

`mounts.md` **does not travel**: the command creates it with its first piece of data, declares it in
the brain's `.gitignore` and appends its glob to `tree.md`. On a new machine the table is not there
— the scans report the mount as unreachable and running `mount-repo` on the same remote rebuilds it.
That is the designed degradation, not an error. `.claude/settings.local.json` follows the same rule
for what does not travel: the command declares it in `.gitignore` too, next to `mounts.md`.

Running it twice on the same remote neither duplicates the row nor clones again.

## When it stops

| Exit | What happened | What to do |
|---|---|---|
| 2 | The head does not exist, or its frontmatter cannot be read | Create or fix the head |
| 3 | The remote does not answer | Check the remote and the permissions; if the repo does not exist yet, `--new` |
| 4 | The head already declares **another** `repo:` | It belongs to the operator: ask which one stays |
| 5 | The clone root is missing, or falls inside the brain or inside another repo; with `--new`, the destination is taken by something that is not this remote's repo, or `mounts.md` points this remote outside the clone root | Ask where the checkouts go; a destination or a row that is already there belongs to the operator |
| 6 | `python3` is missing — hard requirement of the product, next to `git` | Install it (macOS: `xcode-select --install`, the same command that brings git; Windows: python.org; Linux: the distro's package manager) and re-run |
| 7 | `--new` on a remote that **does** answer | There is nothing to create: mount it without `--new` |
| 8 | `--new`: the birth failed — the message names why | What the command had created gets removed, or it says what was left behind; fix what the message names and run it again |

In all eight cases nothing was written. A half-mounted node is worse than an unmounted one.

## When it finishes

Report what was written and where, in one line. If the script says the table was born or that it
declared a glob, pass it through as is.

Unmounting does not exist yet: removing a mount is editing `mounts.md` and the head by hand.
