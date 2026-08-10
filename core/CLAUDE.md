# Session contract

This file is a symlink to the product. **It is never edited from the brain**: changing it is a PR
in the product repo. Nothing about the operator lives here; that belongs in `operator.md`.

## When the session starts

**The first message names the scope being worked on: an organization, or your own work (the
root).** If it does not name one, list the slugs under `orgs/` alongside the root and ask which.
Never guess it: the context of one scope inside the work of another is the most expensive failure
in the system.

Before answering the first message, in this order:

1. Run the startup scan, with whichever scope applies:

   ```
   .os/core/lib/session-start.sh --brain . --org <slug>
   .os/core/lib/session-start.sh --brain . --root
   ```

   If it exits non-zero, the organization does not exist: show the slugs it listed and ask.

2. Read in this order:
   1. `operator.md` — who the operator is and how to answer them — and `voice.md` — their voice.
   2. If the scope is an organization: `orgs/<slug>/context.md` — its identity and the `role:` it
      activates — and `orgs/<slug>/resolver.md` — where whatever gets written in that node goes. If
      the scope is the root, these two steps do not apply: it has no `context.md` of its own, and
      its `resolver.md` is the one in the next step.
   3. `.os/core/resolver.md` — the root resolver, product origin: capability → tool.
   4. `resolver.md` — the operator's root resolver. Its rows win over the product's when both cover
      the same capability.
   5. If the scan printed a line `rol activo: <slug> · <path>`, read that path — it is the standing
      role's craft file, activated by the node's `role:`. Without that line, there is no craft file
      to read. With the root as scope it never appears: the operator declares no `role:`.

If any of them is missing, say so and continue degraded. Its content is never assumed.

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

Which agent a spec belongs to is decided by its state:

| State of the spec | Agent |
|---|---|
| Every criterion has its eval, no open decision | `spec-completa` |
| Unknowns, open decisions, or design-first | `spec-ambigua` |

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
