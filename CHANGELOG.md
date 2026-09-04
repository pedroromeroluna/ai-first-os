# Changelog

Every published version of AI First OS, newest first. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the versions follow
[semantic versioning](https://semver.org/spec/v2.0.0.html): *major* when an already installed brain
needs a manual step to keep working, *minor* for a new capability, *patch* for a fix.

## [1.8.0] — 2026-09-04

### Changed

- The interview's fifth question is optional, and says so when it is asked. Someone who works alone,
  or who is between jobs, has no company and no client: "none" is an answer, their own work lives at
  the root of the brain, and `new-workspace` adds one the day it appears. Until now the only way past
  that question was not answering it, and the install closed by telling them to answer it again.
- The answers file the interview writes calls the workspace `workspace:`, the name you have been
  reading since workspaces replaced organisations. `org:` stops with a line saying what it is called
  now.

### Added

- `skipped:` in the answers file, one line per optional question the operator deliberately left
  empty. It is the difference between "did not answer" and "answered they have none": what was
  answered is never asked again.

## [1.7.0] — 2026-09-03

### Added

- `archive` (spec 048): archiving a document is **moving** it into the node's `archive/`. `tree.md`
  gains a third class of line, `archive:` — reached by the tree, never read as a head, and never
  loaded. The focus prints the names of what is archived under the marker `archived: <n>` and opens
  none of them, so a node's body stops growing without anything being lost: `recall` still searches
  inside archived documents and `supersede --check` still audits their marks.
- The command plans the whole batch before moving one byte —one refusal cancels the batch— moves with
  `git mv`, and then rewrites every reference to what moved, `superseded_by:` included, once and with
  the full map. `archive --unarchive --to <folder>` is the same move in reverse.
- `archive --stale` lists the documents the brain already declared replaced and still keeps outside
  `archive/`. The startup scan gains no line: age is not staleness, and the scan never opens a content
  file.

### Changed

- The rule for rewriting a path that moved —an exact token match, never by suffix— moved from
  `rename-heads.sh` into `common.sh` (`os_rw_line`/`os_rw_file`), now that two commands apply it.

## [1.6.3] — 2026-09-03

### Fixed

- `migrate-canonicals.sh` (spec 055, residual of 043/053/054): a canonical's header used to be
  everything before its first `---`, so themed sections written before that separator — the exact
  shape of one real `learnings.md` — were copied whole into the new index instead of being split,
  and a second run migrated them again. The header now always ends at the file's first `## `
  heading, regardless of where the first `---` falls; `fecha_declarada_en_header` and `migrar_archivo`
  share that one cut (`os_migrate_header_end_linea`) instead of each drawing its own line.

## [1.6.2] — 2026-09-03

### Fixed

- `migrate-canonicals.sh` (spec 054, residual of 043/053): a themed bullet wrapped across several
  lines — the shape the brain writes at 100 columns — used to migrate truncated to its first line
  only, and the index kept the rest as unmigrated bullets under the surviving heading. Every line
  indented by two or more spaces that follows a `- ` is now folded into that bullet, up to the next
  `- `, a heading, or unindented text; a sub-bullet joins its parent instead of becoming a learning
  of its own; the file's title is the bullet's first sentence, same as when it was one line. Stops
  without writing anything if a cut bullet holds a code block or a table.

## [1.6.1] — 2026-09-02

### Fixed

- `migrate-canonicals.sh` (spec 053, residuals of the 043 migrator found running it over a real
  brain): a `---`-separated block can hold more than one `## <date> · <title>` heading back to back
  and each opens its own entry; a canonical with no `---` at all migrates too, treated as one header
  plus one block from its first `## ` onward; prose before a block's first `## ` is kept once in the
  index header instead of stopping the run; the slug is capped at 80 chars in `os_slug_cap`
  (`common.sh`, shared with `close-session.sh` through `os_decision_path`/`os_learning_path`) and
  every write is checked, stopping on a name collision or a write failure instead of guessing; each
  canonical is staged in a scratch directory and moved into place with one `mkdir -p` + `mv` only
  once it split clean, so a stop midway leaves `decisions/`/`learnings/` and the index untouched.

## [1.6.0] — 2026-09-02

### Added

- Living Memory (spec 050): `recall.sh` searches everything `tree.md` reaches, not only what the
  startup and the focus load — the entry (a heading or a list item, never a whole file) as its unit,
  ranked with file and line, what replaced it always below what is current, and `--expand PATH` for
  the neighbours one jump away (`about:`, `superseded_by:`). The index is
  `.os/living-memory.sqlite`, written with `python3`'s standard-library `sqlite3` (FTS5): derived,
  discardable, never committed, reconciled on every call instead of through a hook.

## [1.5.0] — 2026-09-01

### Added

- A node declares what it is about: `about: <path relative to the brain>` in the frontmatter of a
  head names the head of the node this one is about — a product, an account, a channel, any head
  the tree reaches. The startup scan shows it in the row and reports a link that names no head.
- `focus-read.sh`: what a session loads when the operator picks one node to work on — that node's
  head, its body, and, when the head declares `about:`, the head it names together with the
  `resolver.md` beside it. One jump: the head loaded that way may declare its own `about:` and it
  is not followed.

### Fixed

- A path written with `//` is normalised to a single separator on bash 3.2. `supersede` used to
  turn `d//a.md` into `d\/a.md`, so the checks that compare paths as strings answered about a file
  that does not exist instead of the one named.

## [1.4.1] — 2026-08-31

### Fixed

- `supersede` never reports a write that did not happen. Over a file it could not write —a
  directory with no write permission, no space— it used to print that the mark was written and exit
  0 with the file untouched. Every write is checked now, including the `status: closed` of a head.
- `supersede` only marks documents the brain's tree reaches. It used to accept any existing file:
  pointed at a git config file it prepended a frontmatter block to it. A `--file` now has to end in
  `.md` and be reached by a line of `tree.md`.
- The spelling of a path is no longer a way around the checks. `./d/a.md`, `d//a.md` and `d/a.md`
  are one path, so a file can no longer be made to declare that it replaced itself, and the value
  written is always the normalised path.
- A cycle longer than the walk's bound is reported instead of passing as clean, and a chain the
  walk could not finish is refused as undecided instead of being written.
- `--check` exits non-zero over a brain whose `tree.md` it could not read, instead of reporting
  that every mark resolves. It also reports a `superseded_by:` hidden inside a frontmatter it
  cannot parse, which no reader of the system can see.
- Nothing follows a symbolic link: a link is refused instead of being replaced by a regular file,
  a path that resolves outside the brain is refused, and a file keeps the permissions it had.
- A file whose body opens with a `---` rule is refused instead of getting the key written into the
  middle of its prose. The same guard protects every writer of frontmatter.

### Changed

- Superseding a head no longer closes it in silence, and no longer closes every head. An `active`
  head with nothing depending on it is closed and the output says so. A head that is `ongoing`
  —permanent work— one that is `blocked`, and one another head declares in `depends_on:` keep their
  status: the mark is written, the reason is printed, and the command exits 3 so that the pending
  decision is never read as a plain success. Closing a head something depends on used to make that
  other head read as unblocked.

## [1.4.0] — 2026-08-31

### Added

- A file can declare that another one replaced it. `superseded_by: <path>` in the frontmatter of the
  older file names the newer one, and a session that opens the older file reads the newer one before
  using anything from it. Until now a research document from March and one from July that
  contradicts it were two equally valid files: git holds the history, and the agent reads the
  working tree.
- `supersede` writes that mark. A file with no frontmatter gets one created above its untouched
  body; a file whose frontmatter cannot be read is refused with the reason instead of being
  overwritten. When the file is the head of a node or an initiative, its `status` also goes to
  `closed`, so it leaves the lists of the session scan.
- `supersede --check` audits every mark of the brain — heads and content alike — and reports the
  ones pointing at a file that is not there, the ones closing a cycle, and the heads that were
  replaced and still read as open work. It exits non-zero when it finds something.

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
