# Pack resolver — origin: product-builder

Capability → tool, the same format as the core resolver. This file travels with the pack: every
skill in the pack declares its row here, never in the core resolver (which belongs to the chassis)
nor in the operator's. `check-resolvable` reads it as one more origin when the pack is installed.

| Capability | Tool | Path |
|---|---|---|
| Define the problem, the evidence behind it and the prioritized hypotheses of a product | `product-strategy` | `.os/packs/product-builder/skills/product-strategy.md` |
| Research the market with secondary research and size the opportunity | `market-research` | `.os/packs/product-builder/skills/market-research.md` |
| Plan the qualitative or quantitative research round on the riskiest hypothesis | `ux-research` | `.os/packs/product-builder/skills/ux-research.md` |
| Pilot a research script with synthetic personas before real fieldwork | `synthetic-users` | `.os/packs/product-builder/skills/synthetic-users.md` |
| Define the North Star, the metric tree and the metric of each active hypothesis | `product-metrics` | `.os/packs/product-builder/skills/product-metrics.md` |
| Interview and write the strategic layer of a product | `prd` | `.os/packs/product-builder/skills/prd.md` |
| Act as standing CPO over the product of an organization | `cpo` | `.os/packs/product-builder/skills/cpo.md` |
