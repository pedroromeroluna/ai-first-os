---
command: new-spec
capability: Write a new spec
description: Turn concrete build work that came out of a conversation into a spec file under the target repo's specs/, with runnable evals per criterion, decisions split by who closes them, and effects that escape the system declared. Manually triggered, before delegating implementation to an agent.
---

# new-spec — writing a spec an agent can implement without asking for an opinion

Out of a conversation —strategy or work— comes concrete build work: "we have to build X", "write the
spec for Y". The deliverable of this craft is a file under `specs/` of the target repo, in this
product's standard, ready for Gate 1.

## 1. Target repo

If it was not stated, ask for it. Before writing:

- `ls specs/` of the repo → the next number (`NNN`, three digits, consecutive). Specs archived in
  `specs/done/` count for the numbering.
- Read the repo's `CLAUDE.md` and `ARCHITECTURE.md` (if it exists) → that way "Prior state"
  describes the real terrain and does not make the implementing agent rediscover what is already
  built.
- If the repo has no `specs/` yet, that repo has not adopted this format. Say so and offer to write
  the first spec anyway, creating the folder.

## 2. The standard of a complete spec

A spec is complete when any agent can read it and answer "does it pass or not?" on every criterion
without asking for an opinion. Whatever is missing from this is not filled in at your own discretion:
it is asked.

**Frontmatter, two fields and no more:**

```
---
estado: pendiente
depende_de: []
---
```

`estado` is `pendiente | esperando Gate 1 | en curso | implementada`. `depende_de` is an **inline**
list of references to other specs (`[]` if it depends on none) — spread over several lines, a `grep`
returns the first and loses the rest. The reader reports this field; it does not change it just
because a dependency closed.

**The spec opens by saying what is going to be done**: after the title, one or two plain sentences,
free of system jargon, before any detail. A spec that cannot be understood at a glance does not get
reviewed: it gets approved blind.

**Type and flow**: `feature` | `verification` (code already written whose eval never ran) |
`residuals` (a bag of small fixes that alone do not justify a spec). `requirements-first` by
default; `design-first` if there is a hard technical constraint or dubious feasibility — there the
first step is the minimum smoke test that de-risks, not building.

**Every acceptance criterion carries a runnable eval.** Deterministic for the exact ones (a command,
an expected row, a grep); with a rubric written into the spec for the generative ones (copy, tone,
UX). A criterion without an eval is a wish, not a criterion: either you find its check, or it does
not go in.

**The three classes of decision, always separated and never mixed:**

1. *Closed before delegating* → dated and attributed ("DECIDED by `<who>` (Gate 1, `<date>`): … because
   …"), so they do not get re-litigated.
2. *Delegated to the implementing agent* → with **the criterion for choosing** written down.
   Delegating without a criterion is not delegating: it is omitting, and the agent settles it blind.
3. *Stopping conditions* → here the agent does not decide even with a criterion: it stops and asks.
   These cover contradictions between criteria, decisions neither of the two previous classes
   covers, and any point where being wrong is expensive.

**Effects that escape the system**: an email that reaches a person, a charge, a message, a post. No
rollback brings them back, even when the environment says "staging". They are declared with their
containment (test recipients, provider sandbox, test data), or the spec says "none" explicitly.

**Out of scope with a reactivation condition**: it is not enough to say what does not go in; you have
to say what would bring it in, measurable where possible ("if volume goes over N", "if the first
real user of this asks for it").

## 3. Interview only what is missing

Whatever already came out of the conversation is not asked again. Ask in short batches, with a
proposed default at every gap — correcting a default is faster than drafting from scratch.

## 4. Write, validate and deliver

1. Show the complete spec before writing it and wait for the go-ahead.
2. Write it in `specs/NNN-short-name.md` with `estado: pendiente`.
3. Close by returning:
   - The exact trigger to implement it: "implement spec NNN".
   - Which agent it belongs to: `spec-completa` if every criterion has its eval and no decision was
     left open; `spec-ambigua` if unknowns or open decisions remain, or it is design-first.
   - That implementation is delegated from this same session (Agent tool) over the mounted repo:
     there is no need to open a separate session in that folder.

If it is worth researching before writing the spec —what something does today, how another source
solves it— use the `scout` agent: it reads and returns a synthesis, it never writes the spec for you.
