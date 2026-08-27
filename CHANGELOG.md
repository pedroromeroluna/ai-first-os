# Changelog

Every published version of AI First OS, newest first. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the versions follow
[semantic versioning](https://semver.org/spec/v2.0.0.html): *major* when an already installed brain
needs a manual step to keep working, *minor* for a new capability, *patch* for a fix.

## [1.3.0] — 2026-08-27

### Changed

- The nine pack skills that produce a deliverable resolve their destination without naming the
  system. With no product node loaded, the file goes to the current folder and the skill says the
  path it wrote and nothing else — no `new-workspace`, no `new-product`, no session scan, and no
  mention of AI First OS. Someone who installed a single skill from a link no longer hears about a
  system they do not have.
- `prd` writes its eight strategy files into `product-context/` when no product node is loaded,
  instead of leaving `vision.md`, `problem.md`, `users.md` and the rest loose in whatever folder the
  session started in, where they could overwrite files that were already there.
- `synthetic-users` names its deliverable `<YYYY-MM-DD>-script-diagnosis.md`; it was the only one of
  the nine naming its file in Spanish.
- The pack offers its sibling skills once per session, not at the close of every deliverable.

### Added

- `new-memory`, a command that creates a memory-node type the first time it is used — the folder
  plus its five lines in `tree.md` — and adds a node to it. Two questions, what kind of thing this
  is and what this particular one is and for whom, and it writes the head of the node. Until now a
  brain could only grow the node types the system already knew.
- The spec craft records the commit of `main` the spec was written against, so the agent that
  implements it can see whether its terrain moved, and states that the spec is committed to `main`
  as soon as it is written — which is what reserves its number when two sessions write at once.
- The contract states that a branch declares itself finished in a file, never in a chat, and that
  whoever merges removes the worktree and deletes the branch.

## [1.2.0] — 2026-08-22

### Added

- `rename-heads`, a command run only at the operator's request: moves a brain born before the single
  node shape to it — every node becomes a folder with its `README.md` inside, every initiative gets
  its own folder, and each product's dated documents move from `context/` to `research/` — rewriting
  the head paths wherever the system reads them as routing, leaving URLs untouched, and listing what
  it does not touch for review.

### Changed

- One shape for every node: a folder with the name of the thing and its head `README.md` inside, at
  every height — workspace, product, initiative. The root does not change: its folder is the brain
  and its head is `operator.md`. A brain already installed keeps working with no change: the shape
  of the head is read from its own tree, never assumed, and the previous one stays valid
  indefinitely.
- A product node keeps `context/` for one meaning only —its strategic layer— and every dated
  document about it (the pack's briefs, analyses, inventories) now lives in `research/`.

## [1.1.0] — 2026-08-22

### Added

- `rename-workspaces`, a command run only at the operator's request: adopts the current name of the
  workspaces folder on a brain born before this rename, rewriting the prefix everywhere the system
  reads it as structure or routing and listing what it leaves untouched for review.

### Changed

- The isolation boundary is named **workspace** everywhere the operator reads it — the interview,
  the manual, the README — replacing "organization". A brain already installed keeps working with
  no change: the folder name is read from its own tree, never assumed, and the previous name stays
  valid indefinitely. The command that creates one is now `new-workspace`; `--org` keeps working
  everywhere, with `--workspace` as its exact synonym.

## [1.0.0] — 2026-08-21

### Added

- The brain: a plain-text folder versioned with git, built by an interview that writes who you are,
  how you write, your root resolver and the tree of paths a scan walks.
- The session contract: every session opens with a scan of what waits on you, what is in progress
  and what is queued, plus the checks, and with the startup read of the files that give it context.
- Ten skills of the system, reached through the resolver and never activated on their own:
  `bootstrap`, `new-workspace`, `new-product`, `sweep`, `check-resolvable`, `capture`, `close-session`,
  `mount-repo`, `grill` and `new-spec`.
- Organizations as the isolation boundary, with their own identity, resolver, backlog, decisions,
  learnings, initiatives and products.
- A repo mounted onto an initiative — an existing remote, or a new repository born from the
  scaffold — with its row in the environment table.
- Delegation to agents on a branch: two implementers picked by the state of the spec, plus a reader
  that never writes.
- The pack of product skills, published on its own in the Agent Skills format and offered at the
  end of the install, or installed later from the backlog.
- Install by symlink, idempotent, with git and python3 checked before anything is written; updating
  the repository refreshes every brain that points at it.
