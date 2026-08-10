---
name: bootstrap
description: Create the brain from scratch — the gateway skill. If AI First OS is not present it installs the complete system first, then interviews the operator with five questions and writes the minimum node structure — identity, voice, root resolver, the tree of paths a scan walks, and one folder per organization. Manually triggered, once per brain, before any other tool.
---

# bootstrap — create the brain

Interview the operator and create the minimum brain. Do not ask about scope: the building layer is
activated per initiative, not per user.

## Step 0 — install the OS if it is missing

Everything below assumes the product is hooked into the brain (`.os/core` resolves). If it does
not — you were installed standalone, e.g. from skills.sh — install it first:

1. Clone `github.com/pedroromeroluna/ai-first-os` to a fixed local folder outside the brain (the
   operator will need it to update later).
2. Run `<clone>/core/install.sh <brain-path>` — idempotent; it hooks the session contract, the
   resolvers, the subagents and all sixteen skills by symlink.
3. Continue with the interview below.

If `.os/core` already resolves, skip this step entirely.

## The interview

Five questions. One at a time, and do not move on until you have the answer.

1. **What is your name?**
2. **Profile**: what you do, what you are on today, what you decide.
3. **Voice**: how you write when you write well — language, register, words you do not use.
4. **How you want to be answered**: what you expect from an agent. Length, order, what annoys you.
5. **Your organizations**: where you work. For the typical case —one person, one employer— that is
   one. For each one ask **what it does** and **what you do there**; the role is written by the
   system.

Return the answers summarized and wait for approval before writing anything.

## What it writes

Build an answers file and run the deterministic part:

```
.os/core/lib/bootstrap.sh --brain . --answers <file>
```

Format of the answers file, one key per line:

```
name: <name>
profile: <one item>
voice: <one item>
reply: <one item>
org: <Name> | <role> | <owner> | <identity file>
```

`profile`, `voice`, `reply` and `org` repeat. In `org`, the owner and the identity file are
optional: with no owner the operator is used, and with no identity a placeholder text is left.

The result is `operator.md`, `voice.md`, `resolver.md`, `tree.md` and one folder per organization.
`voice.md` is the operator's voice — it used to live in a section of `operator.md`, and from now on
it is its own file: one identity, two questions, never the same sentence in both. Nothing else: the
inbox, the root's own work (initiatives, backlog, decisions, learnings) and the environment table
are born with their first piece of data, like any node.

**It runs once per brain.** If the root pieces already exist, the script stops instead of rewriting
them. Adding an organization to a brain that already exists is `new-org`'s job.

## When it finishes

- Show the tree created and what each file answers, in outcomes and not in canonical names.
- If the identity cap warning appears, pass it through as is: the operator chooses the way out.
- If the script reports `sin dato:` or `sin crear:`, pass it through whole and ask again for what is
  missing. A gap nobody names is a gap nobody fills.
- Handoff: if the operator wants to add another organization, the **add an organization** capability
  is needed. If it is not available, say so and continue.
