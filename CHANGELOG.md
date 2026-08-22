# Changelog

Every published version of AI First OS, newest first. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the versions follow
[semantic versioning](https://semver.org/spec/v2.0.0.html): *major* when an already installed brain
needs a manual step to keep working, *minor* for a new capability, *patch* for a fix.

## [1.0.0] — 2026-08-21

### Added

- The brain: a plain-text folder versioned with git, built by an interview that writes who you are,
  how you write, your root resolver and the tree of paths a scan walks.
- The session contract: every session opens with a scan of what waits on you, what is in progress
  and what is queued, plus the checks, and with the startup read of the files that give it context.
- Ten skills of the system, reached through the resolver and never activated on their own:
  `bootstrap`, `new-org`, `new-product`, `sweep`, `check-resolvable`, `capture`, `close-session`,
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
