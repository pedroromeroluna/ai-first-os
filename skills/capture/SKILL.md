---
name: capture
description: File what the operator throws in mid-conversation into the right backlog —an organization's, the root's, or the inbox when it cannot be classified— without opening a discussion about it. Manually triggered; classifying is the model's job, writing is the script's.
---

# capture — file whatever shows up on the fly

What the operator throws in the middle of something else —"remember to renew the insurance"— is
filed wherever the node's resolver says, without opening a conversation. Classifying is yours;
writing is the script's.

## Before writing

**The node's resolver is already loaded**: the session start brings it. If the task belongs to
another organization, its resolver is **not** loaded and nothing is filed blind: it is loaded first,
or the answer is no. The script guards that — you pass it `--session-org` with the organization the
session is standing on.

## How it is run

```
.os/core/lib/capture.sh --brain . --session-org <session-slug> --text "<text>" \
  [--org <target-slug>] [--blocked-by <ref>] [--hold "<reason>"] [--hold-until <YYYY-MM-DD>]
.os/core/lib/capture.sh --brain . --root --text "<text>" \
  [--blocked-by <ref>] [--hold "<reason>"] [--hold-until <YYYY-MM-DD>]
```

Without `--org` and without `--root` the text goes to the root's inbox. **The inbox is transit for
what could not be classified, never a destination out of convenience**: if you know which
organization it belongs to, it goes to its backlog; if it belongs to the operator's own work —to no
organization— it goes to the root backlog with `--root`.

To write into an organization that is not the session's: load its `context.md` and its
`resolver.md`, and repeat with `--load-context`. The root never asks for it: its identity
(`operator.md`) is already loaded in any session, at any scope.

## How the destination is decided

1. **Which organization is it from, or is it the operator's own work?** If that cannot be answered
   without asking, it is not asked in the middle of something else: it goes to the inbox and that is
   said.
2. **Does it belong to an initiative?** Name it in the text between parentheses. The task lives in
   the backlog either way: the backlog is the organization node's "what is missing".
3. **Is it blocked or postponed?** `--blocked-by` with the reference blocking it; `--hold` with the
   reason and `--hold-until` with the date it resurfaces. A hold with no date is indefinitely in
   force: the task never comes back on its own.

## When it finishes

Report what was written and where, in one line. If the script says the file was born or that it
declared a glob, pass it through as is: that is the system writing itself, and it costs the operator
nothing.

If you had to decide the destination with no resolver row answering it, say so: that is a candidate
row, and the session close offers it.
