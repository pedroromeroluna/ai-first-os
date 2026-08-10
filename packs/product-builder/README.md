# Pack — product-builder

The craft of building product: discovery, specs, delegation to agents, mounting repos.

A pack duplicates nothing from `core/`: it references it by path. If a tool here needed a variant of
one in `core/`, the variation is parameterization or the split is wrong.

`install.sh` hooks each pack into `.os/packs/<pack>` of the brain.

## What is inside

`skills/` — the tools of the craft, one per file, with the command name as the file name.

- `product-strategy.md` (`command: product-strategy`) — a socratic interview that separates the
  symptom from the cause, applies the metric gate and prioritizes up to 3 hypotheses. Writes the
  Discovery Brief. First link of the discovery pipeline.
- `market-research.md` (`command: market-research`) — secondary research, directional TAM/SAM/SOM
  with source and assumption. Writes the Market Brief.
- `ux-research.md` (`command: ux-research`) — designs the research round (one hypothesis per round,
  qualitative or quantitative) on the riskiest hypothesis. Writes the Research Plan.
- `synthetic-users.md` (`command: synthetic-users`) — pilots the script against synthetic
  personas before real fieldwork, with the rule that it validates nothing. Writes the Diagnosis +
  Script v2.
- `prd.md` (`command: prd`) — interviews and writes the strategic layer of a product (vision,
  problem, users, scope, competitors, opportunities, open questions, glossary) in the `context/` of
  its node in the brain. Last link of the pipeline: out of that layer come the specs that `new-spec`
  builds (`core/skills/new-spec.md`).
- `product-metrics.md` (`command: product-metrics`) — the metrics station; see the pipeline below.
- `cpo.md` (`command: cpo`) — the first standing role of the pack: the generic strategic answer of a
  CPO, in four steps. Invocable by hand, or activated by `role: cpo` in the `context.md` of an
  organization (spec 009) — the match between `role:` and `command:` is case-insensitive (spec 014).
  Business data never travels inside the file: it is taken from the node that activates it.

None of them registers for automatic activation by the harness. The index is the resolver: the
pack's skills declare their row in this pack's `resolver.md` (spec 017), which `check-resolvable`
reads as one more origin alongside core's and the operator's.

## Discovery pipeline (state)

```
product-strategy → market-research → ux-research → synthetic-users → real fieldwork → prd
                 \_ (if the metric gate does not pass) → product-metrics ─┘
```

The four discovery stations (`product-strategy`, `market-research`, `ux-research`,
`synthetic-users`, spec personal-os#012) are implemented, each writing its deliverable as dated
research of the product node (Discovery Brief, Market Brief, Research Plan, Diagnosis + Script v2).
`product-metrics` (spec personal-os#015) builds the North Star, the metric tree and the metric per
hypothesis when the gate of `product-strategy` ("with no metric, the problem is not clear") does not
pass. After real fieldwork —real interviews, outside this pack— the complete research feeds `prd`,
which closes the pipeline by writing the strategic layer.
