# AI First OS

Latest version and what changed in it: [Releases](https://github.com/pedroromeroluna/ai-first-os/releases) · [CHANGELOG.md](CHANGELOG.md).

A product operating system for working with agents. One primitive —the node— repeated at every
level: every session opens with a scan of your work, you capture whatever comes up on the fly, you
close the session with a verdict of what got done and what is missing, you mount a repo onto an
initiative, you get interviewed to write specs ready to delegate. The craft on top —discovery, the
metric brief, the interview that writes a product's strategic layer— travels in packs, each one
published as its own set of skills: see **The AI First Product Skills pack** below.

The skills are written in English. The deliverables come out in the language you work in.

This document is written for your agent to execute, not for you to follow step by step.

## Requirements

**Installing the system takes two things: git and python3.** They are checked before anything runs
— an agent that installs first and reads the error afterwards leaves you with `command not found`
instead of an answer.

| What | When it is needed | How the agent checks it | Where it comes from if it is missing |
|---|---|---|---|
| git | To install the system | `git --version` | macOS: `xcode-select --install` · Windows: git-scm.com |
| python3 | To install the system — `mount-repo` uses it to authorize a checkout for the agent | `python3 --version` | macOS: `xcode-select --install` (same command as git) · Windows: python.org · Linux: your distro's package manager |
| Node.js | Only for the pack of skills, offered at the end of the install | `node --version` | The LTS installer at nodejs.org |

**The agent guides; you install.** System software is never installed by the agent on its own: it
points at the official channel, waits for you to run it, and checks again.

**git has no path around it, and neither does python3.** Every brain is versioned from the moment
it exists — that is what gives you an auditable history and updates you can undo — and mounting a
repo needs python3 to authorize it for the agent, so nothing gets written until both are there.
Install what is missing and say "run bootstrap" again; nothing you already answered is lost.

**Node is not a requirement of the system, and the install never runs `npx`.** It belongs to one
optional step at the very end: the pack of skills, which travels through the skills.sh CLI —`npx`,
which is part of Node—. Without Node the system installs completely anyway; the pack stays as a task
in your backlog with the exact command in it, and you run it the day you want the craft on top.

## Install

### Claude Code

Save this message and paste it to your agent, once:

> Install AI First OS from `github.com/pedroromeroluna/ai-first-os`. Bring the repository down to a
> fixed local folder on this machine —you will need it to update later—, run its bootstrap to build
> my brain with a short interview about who I am and which workspaces I work in, and then run its
> installer to hook it into that brain. Ask me whatever the interview needs before writing anything.

You do not have to do anything else. The agent brings the repository down, interviews you and hooks
up the tools; you only answer the interview.

That is the full install: the session contract, the two resolvers, the three delegation subagents
and the eleven skills of the system, hooked in by symlink. Nothing is downloaded from a registry and
nothing asks you to confirm an install in the middle.

**The pack comes at the end, as a question with two answers.** With the brain already built, the
agent offers the AI First Product Skills pack —the craft on top— and you take it now or later. Now: it needs
Node, and the download asks you to confirm once. Later: the exact command stays as a task in your
backlog, and any session runs it the day you want it. Either way the system is already yours.

The eleven of the system are not published one at a time, and that is on purpose: each of them writes
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
2. **The pack**, if you installed it. The agent runs
   `npx skills add pedroromeroluna/ai-first-product-skills` again, which replaces the skills in `.claude/skills/` with the
   published version. With no pack installed there is nothing to refresh, and this half is skipped.

Your brain —your workspaces, your decisions, your content— is not touched: the update only
refreshes the tools. And if the installer were run by mistake through the hook that is already
installed, it stops on its own with a message before writing anything.

## Layout

This is what the install leaves you with once the interview is answered: a folder —your brain—
versioned with git, that every session opens by scanning. Everything in it is a plain text file
you can read in any editor. The tools are not copied in: they are symlinks to the repository you
brought down, so an update refreshes every brain that points at it.

```
my-brain/
├── CLAUDE.md                    # Symlink to the session contract: what the agent does at every start
├── HOW-IT-WORKS.md              # The user manual, symlinked in your language (COMO-FUNCIONA.md in Spanish)
├── operator.md                  # Who you are and how you want to be answered — written by the interview
├── voice.md                     # How you write, so what the agent drafts in your name sounds like you
├── resolver.md                  # Your root resolver: capability → tool; its rows win over the product's
├── tree.md                      # Which paths a scan walks — a level of the system is a line here
├── backlog.md                   # Your own tasks, one line each, in priority order (born on first capture)
├── inbox.md                     # Transit for what could not be filed yet — never a destination
├── mounts.md                    # Which repos are mounted onto which initiatives (born on first mount-repo)
├── decisions.md                 # Your own decisions: what, why, and what would invalidate them
├── learnings.md                 # Live: updated or deleted, never archived
├── initiatives/<slug>/README.md # Your own initiatives, one folder each, with status/horizon/owner up top
├── workspaces/                  # One folder per workspace — the isolation boundary
│   └── <workspace>/
│       ├── README.md            # Its identity, and the `role:` it activates (cpo, cto)
│       ├── resolver.md          # Where whatever gets written in this workspace goes
│       ├── backlog.md           # Its tasks
│       ├── decisions.md         # Its decisions
│       ├── learnings.md         # Its learnings
│       ├── initiatives/         # Its initiatives, one folder each with its `README.md` inside
│       └── <type>/<slug>/       # A memory node of any declared type — products/ is the one this system ships with its own tool
│           └── README.md        # Born with `new-memory --type <type>` (`new-product` is its `products` shortcut); `context/` and `research/` are filled by whatever tool the type has, or by hand
├── .os/
│   ├── core -> …/ai-first-os/core        # The chassis by symlink: the eleven system skills in core/skills/, the shell in core/lib/
│   └── packs/<pack> -> …                 # Each installed pack, by symlink
└── .claude/
    ├── agents/                  # complete-spec, ambiguous-spec, scout — one symlink each
    └── skills/                  # The pack's skills, left here by `npx skills add`
```

The interview writes `operator.md`, `voice.md`, `resolver.md`, `tree.md` and one `workspaces/<slug>/`
per workspace you named. The rest is born the first time it is needed: `backlog.md` on the first
capture, `mounts.md` on the first mounted repo, `decisions.md` and `learnings.md` when there is
something to record.

**Where the skills live.** The eleven skills of the system are not copied into your brain: they live
in `.os/core/skills/`, a symlink to the `core/` of the repository you brought down, and the agent
reaches them through the resolver. The skills of the pack are what `npx skills add` installs: one
folder per skill under `.claude/skills/<name>/SKILL.md` — the place your harness reads skills from,
which is why they show up as `/cpo`, `/prd` and so on — plus `product-builder-resolver`, the pack's
index. Your own skills, if you write any, go next to them as plain folders in `.claude/skills/`.

## The catalog

Eleven skills come with the system itself, in two families. **Workflow skills** run a process and
leave a deliverable: they are triggered manually, by name — the index is the resolver, never
automatic activation. **Knowledge skills** carry a method or a standing craft and are loaded as
context.

### Workflow skills

| Name | What it does |
|---|---|
| `bootstrap` | Creates the brain from scratch: identity, voice, root resolver, the tree of paths a scan walks, one folder per workspace |
| `new-workspace` | Adds a workspace — the isolation boundary — with its identity, its resolver and its initiatives |
| `new-product` | Adds a product to a workspace — memory: what it is, for whom, what is known — with its identity |
| `new-memory` | Creates a memory-node type the first time it is used —a folder plus its five lines in `tree.md`— and adds a node to it; `--root` for a type of the operator's own work |
| `sweep` | The three global scans: what is pending, what is blocked and why, how the roadmap is going |
| `check-resolvable` | Audits the capability-to-tool graph and reports dark tools, broken links and rows pointing nowhere |
| `capture` | Files what you throw in mid-conversation into the right backlog, without opening a discussion |
| `close-session` | Closes the session with a four-part verdict: captured, not captured, candidate resolver row, where to resume |
| `mount-repo` | Gives an initiative a body: the remote in the head, the checkout outside the brain (or the repo born from the scaffold, with `--new`), the row in the environment table |
| `grill` | The pressure interview: counter-question with a concrete example, capped attempts, escape hatches, evidence hierarchy |
| `new-spec` | Writes a spec an agent can implement without asking for an opinion — one runnable eval per criterion |
| `rename-workspaces` | Adopts the current name of the workspaces folder on a brain born before it, run only when the operator asks |
| `rename-heads` | Adopts the single node shape —a folder with its `README.md` inside— on a brain born before it, run only when the operator asks |

### Knowledge skills

None of them travels with the system: a standing craft belongs to the pack that carries it. Two
exist today, both in the pack below: `cpo`, the standing craft of a Chief Product Officer, and
`cto`, the standing craft of a Chief Technology Officer, written for a builder who directs an agent
but cannot read a diff. `cto` never opines on models, prices or capabilities from memory: it
verifies the state of the art live before answering, so it stays current with the latest in AI
without anyone editing the file.

## The AI First Product Skills pack

The craft of building product —discovery from a vague problem to the strategic layer, the metric
brief, the pressure interview, the standing crafts of a CPO and a CTO— is published as its own set
of skills, in the Agent Skills format that any harness reading that standard can install:

```
npx skills add pedroromeroluna/ai-first-product-skills
```

11 skills plus the pack's own index. **The bootstrap above offers that command at its close**,
and leaves it in your backlog if you take it later: this section is here for the other two cases —
trying the pack before installing the system, and adding it to a brain that was born before the pack
existed.

One at a time with `--skill <name>` — for example
`npx skills add pedroromeroluna/ai-first-product-skills --skill product-strategy`.

**Trying one skill is the way to test the toolkit before trusting it with a system install.** They
work on their own, in any project, with nothing else installed: a small skill, a small blast radius,
a real deliverable. Installed that way the deliverable is a file in the current folder; installed
inside the system it lands in the node it belongs to. If what they do earns your trust, the full
install above is the system they came from.

## License

MIT. See `LICENSE`.
