---
command: ux-research
capability: Plan the qualitative or quantitative research round on the riskiest hypothesis
description: Design one research round against the single riskiest hypothesis — behavioral screening, one modality chosen on purpose, a guide whose every question is tied to a hypothesis or a job dimension — and write the Research Plan as dated research of the loaded product node. Manually triggered, third station of the discovery pipeline.
description_es: Diseña una ronda de research contra la única hipótesis más riesgosa — screening por comportamiento, una modalidad elegida a propósito, un guión donde cada pregunta cuelga de una hipótesis o de una dimensión del job — y escribe el Plan de Research como research fechado del nodo de producto cargado. Se dispara a mano, tercera estación del pipeline de discovery.
---

# ux-research — the Research Plan

Third station of the pipeline. It designs the research round that attacks the riskiest hypothesis of
the Discovery Brief — never all of them at once — and closes with a Research Plan ready to pilot.

## When it is invoked

| When | From / to |
|---|---|
| The Market Brief from `market-research` already sized the market | Entry from `market-research` (`packs/product-builder/skills/market-research.md`) |
| The Research Plan is written | Exit toward `synthetic-users` (`packs/product-builder/skills/synthetic-users.md`) — pilots the script before spending real fieldwork |
| With no prior Market Brief | Invocable on its own, over the loaded product node, with the Discovery Brief as the minimum input |

## The interview

It is run with the pressure method of `core/skills/grill.md#method` — cited by path, never copied —
over the choice of hypothesis, the screening criterion and every question in the guide.

### One objective per round

Each round attacks a single hypothesis: the riskiest one in the Discovery Brief, the same risk ×
impact prioritization `product-strategy` already did. Faced with a request to "research everything
together", pressure is applied: which is the one that costs the most if it turns out wrong? That one
belongs to this round; the others wait for the next.

### Screening that avoids "users in general"

The criterion for who gets interviewed is written in verifiable behavior, never in demographics
alone. "Active users" is not screening; "people who bought in the last two weeks and abandoned
checkout at least once" is. Faced with a criterion that is too broad ("any user of the app"), it is
returned with a counter-question: what behavior must this person have done or not done for their
answer to be useful?

### Exploratory → qualitative; sizing → quantitative

The modality is decided by what question the round asks. If the question is "why does this happen?"
or "what do people do today?", qualitative — interviews, few people, depth. If the question is "how
many people does this happen to?" or "how often?", quantitative — survey, representative sample.
Mixing the two without deciding which one leads produces a plan without focus; one is chosen and the
reason is stated.

### JTBD in four dimensions

When the round explores a job-to-be-done, the guide covers the four forces of change, not just the
functional one:

| Dimension | What it looks for |
|---|---|
| Push | What about the current situation pushes toward looking for something different |
| Pull | What about the new solution attracts |
| Anxiety | What doubt or fear holds the change back |
| Habit | What about the current solution weighs by habit, even when it does not work well |

A guide that only asks about the desired feature covers one of the four and is returned incomplete.

### Master technique: reconstruct the last real time

The master question of any guide is not "what do you think of X?": it is "tell me about the last time
[situation]" — reconstructing step by step what happened, at what moment, with whom, what they did
right before and right after. Opinion questions ("would you like it if...?") are taken out of the
guide unless they serve to close the session, never to explore.

### Every question tied, or it comes out

Every question in the guide is tied explicitly to a hypothesis from the Discovery Brief or to one of
the four job dimensions. A question that cannot be tied to either is taken out of the guide — "just
in case" is not an inclusion criterion.

## The Research Plan

It closes by writing the deliverable as dated research of the loaded product node, in:

```
context/<YYYY-MM-DD>-research-plan.md
```

Dated, never overwritten. The path falls inside `content: orgs/*/products/*/context/*.md` of
`core/templates/tree.md`: no new glob and no resolver row are needed.

The Plan carries these four sections, in this order, each with its literal heading:

```
## Objective of the round
## Screening criterion
## Modality
## Question guide
```

- **Objective of the round**: the chosen hypothesis and why it is the riskiest.
- **Screening criterion**: in verifiable behavior, never demographics alone.
- **Modality**: qualitative or quantitative, with the question that decides it.
- **Question guide**: every question with the hypothesis or job dimension it is tied to.

## What this deliverable does not claim

The Research Plan is the v1 guide: it has not been piloted yet. Piloting it against synthetic
personas —before spending the first minute of real fieldwork— is the job of `synthetic-users`,
the next station.
