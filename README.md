# AI First OS

A product operating system for working with agents. One primitive —the node— repeated at every
level: every session opens with a scan of your work, you capture whatever comes up on the fly, you
close the session with a verdict of what got done and what is missing, you mount a repo onto an
initiative, you get interviewed to write specs ready to delegate. The Product Management pack adds
the discovery pipeline, the metric brief and the interview that writes a product's strategic layer.

The skills are written in English. The deliverables come out in the language you work in.

This document is written for your agent to execute, not for you to follow step by step.

## Requirements

**Two requirements, checked before running anything.** An agent that installs first and reads the
error afterwards leaves you with `command not found` instead of an answer.

| What | How the agent checks it | Where it comes from if it is missing |
|---|---|---|
| Node.js | `node --version` | The LTS installer at nodejs.org |
| git | `git --version` | macOS: `xcode-select --install` · Windows: git-scm.com |

**The agent guides; you install.** System software is never installed by the agent on its own: it
points at the official channel, waits for you to run it, and checks again.

**A missing git does not block the install.** The brain still gets created — the local versioning is
left as a pending task in your root backlog, with the install guidance inside it, and any later
session finishes it.

**If you refuse to install Node** — and only then — there is a path that needs neither Node nor git.
It brings the repository down as a tarball with `curl`, which is already on macOS and on current
Windows:

```
curl -L https://github.com/pedroromeroluna/ai-first-os/archive/refs/heads/main.tar.gz | tar xz
```

Then `ai-first-os-main/core/install.sh <brain-path>`, and the interview follows as usual. Its cost,
said before it is used: installed this way the system does not count in skills.sh, and the copy is a
plain folder rather than a checkout, so updating it means downloading the tarball again — see
**Update** below.

## Install

### Claude Code

Save this message and paste it to your agent, once:

> Install AI First OS from `github.com/pedroromeroluna/ai-first-os`. Bring the repository down to a
> fixed local folder on this machine —you will need it to update later—, run its bootstrap to build
> my brain with a short interview about who I am and which organizations I work in, and then run its
> installer to hook it into that brain. Ask me whatever the interview needs before writing anything.

You do not have to do anything else. The agent brings the repository down, interviews you and hooks
up the tools; you only answer the interview.

That is the full install: the session contract, the two resolvers, the three delegation subagents
and all sixteen skills, hooked in by symlink.

### Other harnesses

Every skill is also published in the Agent Skills format, one folder per skill under `skills/`, so
any harness that reads that standard can install them one at a time:

```
npx skills add pedroromeroluna/ai-first-os --skill <name>
```

Use the name from the catalog below — for example `npx skills add pedroromeroluna/ai-first-os
--skill new-spec`. Installed this way you get the skill on its own, without the session contract or
the resolver: the skills that write into a brain expect that structure to exist, so the full install
above is the one that gives you the system rather than the pieces.

The exception is `bootstrap` — the gateway skill. Installed on its own it builds everything: if the
OS is not present, it brings the repository down, hooks it in, and then interviews you to create
your brain. One command is a complete install:

```
npx skills add pedroromeroluna/ai-first-os --skill bootstrap
```

Then tell your agent: "run bootstrap".

## Update

Paste this to your agent:

> Update the system.

That sentence is enough. The agent goes to the local folder where the repository ended up, brings
down the newest version and runs the installer from that folder. Your brain —your organizations,
your decisions, your content— is not touched: the update only refreshes the tools that were hooked
in. And if the installer were run by mistake through the hook that is already installed, it stops on
its own with a message before writing anything.

**The tarball copy updates differently, and this is the only place that says how**: it has no
checkout to pull from, so the agent downloads the tarball again into the same fixed folder,
replacing it, and runs `core/install.sh` from there. Everything else is identical — your brain is
still untouched.

## The catalog

Sixteen skills, in two families. **Workflow skills** run a process and leave a deliverable: they are
triggered manually, by name — in the full install the index is the resolver, never automatic
activation. **Knowledge skills** carry a method or a standing craft and are loaded as context.

### Workflow skills

| Name | What it does |
|---|---|
| `bootstrap` | Creates the brain from scratch: identity, voice, root resolver, the tree of paths a scan walks, one folder per organization |
| `new-org` | Adds an organization — the isolation boundary — with its identity, its resolver and its initiatives |
| `sweep` | The three global scans: what is pending, what is blocked and why, how the roadmap is going |
| `check-resolvable` | Audits the capability-to-tool graph and reports dark tools, broken links and rows pointing nowhere |
| `capture` | Files what you throw in mid-conversation into the right backlog, without opening a discussion |
| `close-session` | Closes the session with a four-part verdict: captured, not captured, candidate resolver row, where to resume |
| `mount-repo` | Gives an initiative a body: the remote in the head, the checkout outside the brain, the row in the environment table |
| `grill` | The pressure interview: counter-question with a concrete example, capped attempts, escape hatches, evidence hierarchy |
| `new-spec` | Writes a spec an agent can implement without asking for an opinion — one runnable eval per criterion |
| `product-strategy` | The Discovery Brief: symptom separated from cause, graded evidence, metric gate, up to three prioritized hypotheses |
| `market-research` | The Market Brief: directional TAM/SAM/SOM, every number with its source and its assumption |
| `ux-research` | The Research Plan: one round against the riskiest hypothesis, behavioral screening, a guide where every question is tied |
| `synthetic-users` | The Diagnosis + Script v2: pilots the guide against synthetic personas before spending real fieldwork |
| `product-metrics` | The Metric Brief: candidate North Star, metric tree, one metric per active hypothesis, antimetrics |
| `prd` | Interviews and writes the strategic layer of a product: vision, problem, users, scope, competitors, glossary |

### Knowledge skills

| Name | What it does |
|---|---|
| `cpo` | The standing craft of a Chief Product Officer: every strategic question answered in four steps, under four golden rules |

## License

MIT. See `LICENSE`.
