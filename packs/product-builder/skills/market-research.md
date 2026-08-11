---
command: market-research
capability: Research the market with secondary research and size the opportunity
description: Size the opportunity with secondary research only — directional TAM/SAM/SOM where every number carries its cited source and the assumption that turns it into a number for this product — and write the Market Brief as dated research of the loaded product node. Manually triggered, second station of the discovery pipeline.
description_es: Dimensiona la oportunidad solo con research secundario — TAM/SAM/SOM direccional donde cada número lleva su fuente citada y el supuesto que lo vuelve un número para este producto — y escribe el Market Brief como research fechado del nodo de producto cargado. Se dispara a mano, segunda estación del pipeline de discovery.
---

# market-research — the Market Brief

Second station of the pipeline. It researches the market with secondary research —it never talks to
users, that is the job of the following stations— and sizes the opportunity directionally, every
number with its source and its assumption next to it.

## When it is invoked

| When | From / to |
|---|---|
| The Discovery Brief from `product-strategy` already has prioritized hypotheses | Entry from `product-strategy` (`packs/product-builder/skills/product-strategy.md`) |
| The Market Brief is written | Exit toward `ux-research` (`packs/product-builder/skills/ux-research.md`) — next station of the pipeline |
| With no prior Discovery Brief | Invocable on its own, over the loaded product node, asking for the segment and the market directly |

## The research

Before searching, the pressure method of `core/skills/grill.md#method` is applied — cited by path,
never copied — to the definition of the segment and the market, and to every source proposed: the
counter-question, the pressure capped at 1-2 attempts and the recording of the gap when the second
resistance brings no data are the same as always.

### Secondary research only

It is declared explicitly at the start: "this is secondary research — it does not replace talking to
users, that is the next station". User answers are never simulated, and a data point from a
secondary source is never presented as if it were primary research.

### Directional TAM/SAM/SOM, with source and assumption

The opportunity is sized in three layers — TAM (the total market), SAM (the segment reachable with
the current business model), SOM (what is capturable within the horizon of the hypothesis being
tested) — and every number carries its cited source plus the assumption that turns it from a market
figure into a number for this product.

Generic example (B2B app): "TAM of USD 2,000M (source: industry association report, 2025) assuming
that the segment of companies with 10 to 200 employees is 15% of that market (own assumption, no
source measuring it directly)" is a complete row. A number without a source does not enter the
Brief.

**Without a source it is worthless.** A number that cannot be cited with its origin is not written
as if it could be. The source is pressured with the grill method and, if it does not appear after the
capped pressure, it is recorded as a gap with who closes it — it is never filled in with an invented
number to make the table look tidy.

### Faced with a void, say so and suggest validation

When the search finds no data for a layer or a segment, the Brief says so explicitly ("no public
source found for the SAM of [segment] in [market]") and suggests how to validate it with primary
evidence — a short survey, a pilot, an interview with someone in the industry — and never invents the
number to complete the row.

### Capped search budget, with an explicit plan

The research runs with a cap stated before starting (for example: up to 5 searches per layer, or a
fixed block of time) — not an open search until the web runs out. On hitting the cap without
resolving a row, it closes with the gap recorded and an explicit plan for how to go deeper if
needed: what to search next, with what kind of source (a paid report, an interview with an industry
expert).

## The Market Brief

It closes by writing the deliverable as dated research of the loaded product node, in:

```
context/<YYYY-MM-DD>-market-brief.md
```

Dated, never overwritten. The path falls inside `content: orgs/*/products/*/context/*.md` of
`core/templates/tree.md`: no new glob and no resolver row are needed.

The Brief carries these three sections, in this order, each with its literal heading:

```
## TAM/SAM/SOM
## Sources and assumptions
## Gaps and plan to go deeper
```

- **TAM/SAM/SOM**: the three layers, each with its number, its source and its assumption.
- **Sources and assumptions**: the detail of every cited source, separated from the assumption that
  connects it to this product.
- **Gaps and plan to go deeper**: every row without a source, with who closes it and how — never in
  silence.

## What this deliverable does not claim

The Market Brief does not replace primary research with users: it is the market-context layer that
supports the decision about which segment is worth designing the `ux-research` round for.
