# Changelog

Every published version of AI First OS, newest first. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the versions follow
[semantic versioning](https://semver.org/spec/v2.0.0.html): *major* when an already installed brain
needs a manual step to keep working, *minor* for a new capability, *patch* for a fix.

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
