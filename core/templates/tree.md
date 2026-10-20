# Tree — which paths a scan walks

Three classes of line, each with its prefix. No scan discovers the tree and none assumes depth: it
reads these lines. Adding a level is adding a line here, not touching scripts.

- `glob:` — what a scan reads as a head: frontmatter with `status`, `horizon`, and so on.
- `content:` — what a scan counts as reached but **never** reads as a head: the voice, a record, the
  `context/`, `research/` and `resources/` of a node, the body of an initiative next to its
  `README.md`, one file per decision or learning in the workspace's `decisions/` and `learnings/`
  (spec 076), the `index.md` the startup read generates, a workspace's `people/` (spec 058) — who a
  person is, never a node, and never what the scan or the focus load on their own.
  Without this line, that file gets flagged as unreached by any glob even when it is written correctly.
- `archive:` — what a scan counts as reached, never reads as a head, and **never loads**: the
  `archive/` of a node (spec 048). The focus prints the names of these files and opens none of them;
  `recall` still searches inside them and `supersede --check` still audits them. A document gets here
  because the operator ran `archive`, never on its own.

The commands that create a level add their glob or their content line. A file that neither of the
two reaches is a finding of the check, not a case to ignore.

The first `content:` line is the system's user manual, in the language of this brain: it is part of
the product, it lives at the root so it can be read from Obsidian, and it is never work.

This file lives in `.system/` with the root resolver and the mounts table: the machinery of the root.
The account (`account/`) is what the person edits.

glob: account/operator.md
glob: .system/resolver.md
glob: .system/mounts.md
glob: workspaces/*/README.md
glob: workspaces/*/.resolver.md
glob: workspaces/*/initiatives/*/README.md
glob: workspaces/*/products/*/README.md
glob: workspaces/*/products/*/.resolver.md

content: {{MANUAL}}
content: account/voice/*.md
content: account/voice/*/*.md
content: workspaces/*/context/*.md
content: workspaces/*/resources/*.md
content: workspaces/*/resources/*/*.md
content: workspaces/*/records/*.md
content: workspaces/*/people/*.md
content: workspaces/*/initiatives/*/*.md
content: workspaces/*/decisions/*.md
content: workspaces/*/learnings/*.md
content: workspaces/*/products/*/index.md
content: workspaces/*/products/*/context/*.md
content: workspaces/*/products/*/research/*.md
content: workspaces/*/products/*/resources/*.md
content: workspaces/*/products/*/resources/*/*.md

archive: workspaces/*/products/*/archive/*.md
archive: workspaces/*/initiatives/*/archive/*.md
