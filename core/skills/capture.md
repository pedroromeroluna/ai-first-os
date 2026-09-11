---
command: capture
capability: Capture something on the fly
description: File what the operator throws in mid-conversation into the backlog of the initiative that consumes it, once an initiative is named — nothing is filed unclassified. Manually triggered; classifying is the model's job, writing is the script's.
description_es: Archiva lo que el operador tira al vuelo en el backlog de la iniciativa que lo consume, una vez que hay una iniciativa nombrada — nada se archiva sin clasificar. Se dispara a mano; clasificar es del modelo y escribir es del script.
---

# capture — file whatever shows up on the fly

What the operator throws in the middle of something else —"remember to renew the insurance"— is
filed in the backlog of the initiative it belongs to, without opening a conversation. Classifying is
yours; writing is the script's.

## Before writing

**The node's resolver is already loaded**: the session start brings it. If the task belongs to
another organization, its resolver is **not** loaded and nothing is filed blind: it is loaded first,
or the answer is no. The script guards that — you pass it `--session-org` with the organization the
session is standing on.

**Nothing enters unclassified.** A task hangs from an initiative and only from there — there is no
workspace backlog, no root backlog, no inbox to fall back on. If the initiative cannot be named
without asking, it is not asked in the middle of something else and it is not filed anywhere: say so,
propose the initiative you would use —or the entity under which it is missing and would need to be
opened first— and run `capture` with `--initiative` once the operator confirms it, never before. No
command creates an initiative: if the one that fits does not exist yet, its head is written first at
`initiatives/<slug>/README.md` (or `<workspace>/initiatives/<slug>/README.md`).

## How it is run

```
.os/core/lib/capture.sh --brain . --session-org <session-slug> --text "<text>" --initiative <slug> \
  [--org <target-slug>] [--blocked-by <ref>] [--hold "<reason>"] [--hold-until <YYYY-MM-DD>]
.os/core/lib/capture.sh --brain . --root --text "<text>" --initiative <slug> \
  [--blocked-by <ref>] [--hold "<reason>"] [--hold-until <YYYY-MM-DD>]
```

`--initiative` names the initiative by its slug, relative to the scope — the same shape every other
flag already uses (`--workspace <slug>`), never a full path. Without it the script writes nothing,
anywhere, and says the initiative is missing: that is not an error to work around, it is the
contract (decision 2, spec 057).

To write into an organization that is not the session's: load its `README.md` and its
`resolver.md`, and repeat with `--load-context`. The root never asks for it: its identity
(`operator.md`) is already loaded in any session, at any scope.

## How the destination is decided

1. **Which organization is it from, or is it the operator's own work?** If that cannot be answered
   without asking, it is not asked in the middle of something else — say the same thing you would say
   for a missing initiative: it is not filed, and it waits for the operator.
2. **Which initiative does it belong to?** Its slug is `--initiative`. If more than one initiative
   could fit, ask; if none fits and one needs to be opened, propose the initiative (or the entity it
   should open under) and wait for the confirmation before running the script.
3. **Is it blocked or postponed?** `--blocked-by` with the reference blocking it; `--hold` with the
   reason and `--hold-until` with the date it resurfaces. A hold with no date is indefinitely in
   force: the task never comes back on its own.

## When it finishes

Report what was written and where, in one line. If the script says the file was born, pass it through
as is: that is the system writing itself, and it costs the operator nothing.

If you had to decide the destination with no resolver row answering it, say so: that is a candidate
row, and the session close offers it.
