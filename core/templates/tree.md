# Tree — which paths a scan walks

Two classes of line, each with its prefix. No scan discovers the tree and none assumes depth: it
reads these lines. Adding a level is adding a line here, not touching scripts.

- `glob:` — what a scan reads as a head: frontmatter with `status`, `horizon`, and so on.
- `content:` — what a scan counts as reached but **never** reads as a head: the voice, a record, the
  `context/` of a product node, the body of an initiative with a folder. Without this line, that
  file gets flagged as unreached by any glob even when it is written correctly.

The commands that create a level add their glob or their content line. A file that neither of the
two reaches is a finding of the check, not a case to ignore.

The first `content:` line is the system's user manual, in the language of this brain: it is part of
the product, it lives at the root so it can be read from Obsidian, and it is never work.

glob: operator.md
glob: resolver.md
glob: inbox.md
glob: mounts.md
glob: initiatives/*.md
glob: backlog.md
glob: decisions.md
glob: learnings.md
glob: workspaces/*/context.md
glob: workspaces/*/resolver.md
glob: workspaces/*/backlog.md
glob: workspaces/*/decisions.md
glob: workspaces/*/learnings.md
glob: workspaces/*/initiatives/*.md
glob: workspaces/*/products/*/context.md
glob: workspaces/*/products/*/resolver.md
glob: workspaces/*/products/*/decisions.md

content: {{MANUAL}}
content: voice.md
content: voice/*.md
content: workspaces/*/voice.md
content: workspaces/*/records/*.md
content: workspaces/*/products/*/context/*.md
content: workspaces/*/initiatives/*/*.md
