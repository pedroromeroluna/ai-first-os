# AI First OS

A product operating system for working with agents. One primitive —the node— repeated at every
level: every session opens with a scan of your work, you capture whatever comes up on the fly, you
close the session with a verdict of what got done and what is missing, you mount a repo onto an
initiative, you get interviewed to write specs ready to delegate. The craft on top —discovery, the
metric brief, the interview that writes a product's strategic layer— travels in packs, each one
published as its own set of skills: see **The Product Builder pack** below.

The skills are written in English. The deliverables come out in the language you work in.

This document is written for your agent to execute, not for you to follow step by step.

## Requirements

**Two requirements, checked before running anything, and neither one is optional.** An agent that
installs first and reads the error afterwards leaves you with `command not found` instead of an
answer.

| What | How the agent checks it | Where it comes from if it is missing |
|---|---|---|
| Node.js | `node --version` | The LTS installer at nodejs.org |
| git | `git --version` | macOS: `xcode-select --install` · Windows: git-scm.com |

**The agent guides; you install.** System software is never installed by the agent on its own: it
points at the official channel, waits for you to run it, and checks again.

**git has no path around it.** Every brain is versioned from the moment it exists — that is what
gives you an auditable history and updates you can undo — so nothing gets written until git is
there. Install it and say "run bootstrap" again; nothing you already answered is lost.

**Node has no path around it either.** The install brings the pack of skills down with the skills.sh
CLI —`npx`, which is part of Node— and that CLI is the only thing that installs a skill where your
harness finds it. There is no alternative download: without Node the install stops at the same place
it stops without git, and for the same reason — a system installed halfway is worse than one not
installed yet.

## Install

### Claude Code

Save this message and paste it to your agent, once:

> Install AI First OS from `github.com/pedroromeroluna/ai-first-os`. Bring the repository down to a
> fixed local folder on this machine —you will need it to update later—, run its bootstrap to build
> my brain with a short interview about who I am and which organizations I work in, and then run its
> installer to hook it into that brain. Ask me whatever the interview needs before writing anything.

You do not have to do anything else. The agent brings the repository down, installs the pack,
interviews you and hooks up the tools; you only answer the interview.

That is the full install, and it has two halves that arrive together: the session contract, the two
resolvers, the three delegation subagents and the nine skills of the system, hooked in by symlink;
and the Product Builder pack, brought down by the skills.sh CLI into `.claude/skills/` of your
brain, where your harness finds it on its own. The pack is a step of the bootstrap, not homework
for later.

The nine of the system are not published one at a time, and that is on purpose: each of them writes
into a brain, so on its own —without the session contract, the resolver and the tree of paths— it
has nowhere to write. What you can try one at a time is a pack.

## Update

Paste this to your agent:

> Update the system.

That sentence is enough, and **this is the only place that says what it does** — the manual in your
brain and the bootstrap skill point here instead of telling the story again. The tools come from two
places, so updating them has two halves and both run:

1. **The system.** The agent goes to the local folder where the repository ended up, brings down the
   newest version and runs `core/install.sh` from that folder.
2. **The pack.** The agent runs `npx skills add pedroromeroluna/ai-first-product-skills` again, which replaces the skills in
   `.claude/skills/` with the published version.

Your brain —your organizations, your decisions, your content— is not touched: the update only
refreshes the tools. And if the installer were run by mistake through the hook that is already
installed, it stops on its own with a message before writing anything.

## The catalog

Nine skills come with the system itself, in two families. **Workflow skills** run a process and
leave a deliverable: they are triggered manually, by name — the index is the resolver, never
automatic activation. **Knowledge skills** carry a method or a standing craft and are loaded as
context.

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

### Knowledge skills

None of them travels with the system: a standing craft belongs to the pack that carries it. The one
that exists today is `cpo`, in the pack below.

## The Product Builder pack

The craft of building product —discovery from a vague problem to the strategic layer, the metric
brief, the pressure interview, the standing craft of a CPO— is published as its own set of skills,
in the Agent Skills format that any harness reading that standard can install:

```
npx skills add pedroromeroluna/ai-first-product-skills
```

12 skills plus the pack's own index. **The bootstrap above already runs that command**: this
section is here for the other two cases — trying the pack before installing the system, and adding
it to a brain that was born before the pack existed.

One at a time with `--skill <name>` — for example
`npx skills add pedroromeroluna/ai-first-product-skills --skill product-strategy`.

**Trying one skill is the way to test the toolkit before trusting it with a system install.** They
work on their own, in any project, with nothing else installed: a small skill, a small blast radius,
a real deliverable. Installed that way the deliverable is a file in the current folder; installed
inside the system it lands in the node it belongs to. If what they do earns your trust, the full
install above is the system they came from.

## License

MIT. See `LICENSE`.
