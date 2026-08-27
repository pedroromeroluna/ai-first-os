# Session contract

This file is a symlink to the product. **It is never edited from the brain**: changing it is a PR
in the product repo. Nothing about the operator lives here; that belongs in `operator.md`.

## When the session starts

**The first message names the scope being worked on: a workspace, or your own work (the root).**
If it does not name one, list the slugs under the workspaces folder alongside the root and ask
which. Never guess it: the context of one scope inside the work of another is the most expensive
failure in the system.

Before answering the first message, in this order:

1. Run the startup scan, with whichever scope applies:

   ```
   .os/core/lib/session-start.sh --brain . --workspace <slug>
   .os/core/lib/session-start.sh --brain . --root
   ```

   If it exits non-zero, the workspace does not exist: show the slugs it listed and ask — or the
   installation is broken (its bilingual catalog is missing), and the error message says which.

2. Run the startup read, with the same scope:

   ```
   .os/core/lib/session-read.sh --brain . --workspace <slug>
   .os/core/lib/session-read.sh --brain . --root
   ```

   It prints everything the session loads before answering, in the order it has to be read. That
   order lives in the header of `session-read.sh` and nowhere else: it is not repeated here, and
   it is not rebuilt by hand. What the read declares as not being there was not read.

If any of them is missing, say so and continue degraded. Its content is never assumed.

English is the source language of every new component of the system; Spanish exists as a
translation for what a person reads. The rule is written once, at the top of the product's
`CLAUDE.md`, and this file references it by path instead of repeating it: `.os/core/../CLAUDE.md`
from the brain (`.os/core` is a symlink to the product's `core/`, so `..` reaches the product's own
root, which is where its `CLAUDE.md` lives — the product's root is never mounted on its own).

**The scan output is the state.** It is shown exactly as it came out —four sections, always the
four— and it is not recomputed, nor completed with inferences, nor summarized. Above it goes **one**
suggested next action, and then a question.

**The body of an initiative is loaded only once the operator picks a focus.** The scan reads
frontmatter: enough to choose, not enough to work.

## How the agent speaks

**The agent speaks in outcomes, never in internal jargon.** "Node", "resolver", "glob",
"frontmatter", "canonical" and file names are the system's vocabulary: they do not appear in what
the operator is told unless they name them first. What gets reported is what was written, where,
and what changes from now on.

## Delegating the implementation of a spec

**The supervision pattern has two human gates and one autonomous stretch in the middle**: **Gate 1**
a person approves the spec → the matching agent implements it **on a branch** of the mounted repo,
never on its main branch and never with a push → **Gate 2** a person reads the branch and merges.
The brain session **supervises without changing folders**: it delegates to the agent over the
mounted repo and keeps reading the result from here.

**Every implementing agent works in its own git worktree of the mounted repo, one worktree per
agent, never in the shared checkout.** Two agents sharing a checkout is a collision waiting to
happen — the same edit window, no signal for either that the other exists.

**A branch declares itself finished in a file, never in a chat.** With a spec, that is
`status: implementada` in the archived spec; without one, the trailer `Listo-para-merge: si` in its
last commit. A clean tree and a recent commit say nothing about whether the work is done, and the
answer given by the session that wrote it dies with that session.

**Gate 2 runs `scripts/merge-if-green.sh <branch>` of the mounted repo, never a bare `git merge`.**
It refuses a branch that does not declare itself finished, merges, runs the whole eval suite over
the result, and rolls the merge back if anything turns red. The person decides the branch is ready;
the suite decides it is correct.

**Whoever merges removes the worktree and deletes the branch: cleanup is the last step of Gate 2,
never of the agent's own close.** The agent leaves its worktree standing because that is what the
person reads at the gate; once the branch is in, both the worktree and the branch are dead weight
that nothing prunes on its own.

**Before resuming or reinstructing an agent, the brain checks which agents are still alive.** A
clean tree and a "done" notification are not proof that nothing is running: a just-spawned child has
not written yet. List the live agents before acting on either signal.

**An agent that reports "another agent is implementing" delegated its own work — that is the bug,
not a status update.** The fix is to stop the child, not to launch a second implementer. Reinstructing
the parent with "do it yourself" while an unseen child is still writing is how two agents end up in
the same tree at once.

Which agent a spec belongs to is decided by its state:

| State of the spec | Agent |
|---|---|
| Every criterion has its eval, no open decision | `complete-spec` |
| Unknowns, open decisions, or design-first | `ambiguous-spec` |

A third agent, `scout`, does not implement: it reads sources —code, documentation, another spec—
and returns a synthesis. It is used before writing the spec, never to touch a repo.

The three live in the brain's `.claude/agents/`, symlinked to `.os/core/agents/`: the harness reads
them on its own, without going through the resolver. The skill that writes the spec is `new-spec`,
in the product's root resolver.

## Rules that do not depend on the session

- **Every path is relative to the brain**, which is the session's cwd.
- **Tools never activate on their own.** The index is the root resolver and invocation is explicit.
- **No irreversible action runs by itself.** Sending, publishing, signing and merging are prepared
  and then requested.
- **Whatever the AI writes is marked**: 📌 literal with `file:line` · 🔍 inference · ❓ gap.
- **Whatever is missing is recorded as open, with who closes it.** It is never invented.
- **The brain works on `main` and commits as it goes.** Every file created or edited in the brain
  during a session —a draft, a sketch, a note— is committed and pushed in the same turn it appears;
  nothing of the brain's own work waits for the close to be committed, and no draft is added to
  `.gitignore` to hide it. This is not development work: it goes through no review, so a branch or
  an uncommitted file adds nothing but confusion. **It applies to the brain only.** A mounted repo
  is code, and code follows the pattern above: a branch per spec, no push, a person merges. What
  the close finds uncommitted is another session's work in progress and is left alone.
