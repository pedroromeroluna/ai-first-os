---
command: bootstrap
capability: Create the brain from scratch
handoff: Add an organization
description: Create the brain from scratch — the gateway skill. If AI First OS is not present it installs the complete system first, then runs a five-question interview —language first, then name, role, voice and organization— writes the minimum node structure, and leaves the brain versioned with its first commit and its remote backup resolved or pending. Manually triggered, once per brain, before any other tool.
description_es: Crea el brain desde cero — la skill de entrada. Si AI First OS no está, instala el sistema completo primero, después conduce una entrevista de cinco preguntas —idioma primero, y después nombre, rol, voz y organización—, escribe la estructura mínima de nodos y deja el brain versionado con su primer commit y su respaldo remoto resuelto o pendiente. Se dispara a mano, una vez por brain, antes que cualquier otra herramienta.
---

# bootstrap — create the brain

Interview the operator and create the minimum brain. Do not ask about scope: the building layer is
activated per initiative, not per user.

## Step 0 — preflight, then install the OS if it is missing

### The preflight

**Check the requirements before running anything.** Do not run `npx`, do not clone, do not read an
error to find out what is missing:

```
node --version
git --version
```

- **Node.js missing**: point the operator at the LTS installer on nodejs.org.
- **git missing**: macOS, `xcode-select --install`; Windows, git-scm.com.

**You guide; the operator installs.** You never install system software on your own — you name the
official channel, wait for them to run it, and check again. Anything they decline is a choice, not
an error: report it and take the branch below that matches.

**Neither requirement has a path around it, and there is no alternative branch.** If either is
missing, stop right there — point at the install channel, wait for the operator to run it, check
again. Re-running the same command once it is installed picks the interview up cleanly.

- **git has no path around it.** `bootstrap.sh` itself refuses to write anything without git.
- **Node has no path around it.** Step 1 below installs the pack with the skills.sh CLI, which runs
  on Node, and that CLI is the only thing that puts a skill where the harness finds it. Without Node
  there is no pack, and a system installed halfway is worse than one not installed yet.

### Bringing the product down

Everything below assumes the product is hooked into the brain (`.os/core` resolves). If it does
not, install it first:

1. Clone `github.com/pedroromeroluna/ai-first-os` to a fixed local folder outside the brain (the
   operator will need it to update later).
2. Run `<clone>/core/install.sh <brain-path>` — idempotent; it hooks the session contract, the
   resolvers, the subagents and the nine skills of the system by symlink. The packs are not in
   that repository: each one is published as its own set of skills, and Step 1 below installs one.
3. Continue with Step 1.

There is one way in and only one: the clone above. If `.os/core` already resolves, skip this step
entirely.

## Step 1 — install the pack

**This runs after the system is hooked in and before the interview, and it is part of the install,
not a suggestion for later.** Run it from the brain, which is where the CLI leaves the skills:

```
npx skills add pedroromeroluna/ai-first-product-skills
```

**Ask before running it and say what it does**: it downloads the CLI and the pack's skills from the
public registry, leaves them in `.claude/skills/` of the brain, and counts the install upstream.
`npx` may ask to confirm the download the first time — the operator is right here, so answer it with
them; nothing here needs a non-interactive flag.

What lands: one folder per skill under `.claude/skills/`, plus the pack's own index
(`<pack>-resolver`), which is what the session contract reads to route a request to the pack. The
harness also offers those skills natively, because that is where it looks for them.

**If it fails —no network, registry down, the operator says no— the flow does not stop.** Retry once;
if it fails again, carry the pending forward and, once the interview has created the brain, write it
into the root backlog with the exact command:

```
- [ ] Install the Product Builder pack: `npx skills add pedroromeroluna/ai-first-product-skills` from the brain folder
```

Then say it out loud when the bootstrap closes: the system works without the pack —every skill of
the system is already hooked in— and the craft on top arrives when that line gets run. A bootstrap
aborted halfway because a download failed is the worse outcome of the two.

## The interview

**Five questions, in this order. One at a time.** They are configuration, not a profile: each one
is answered in a line. Whatever the system can learn with use is not asked.

1. **Language.** The only question asked in two languages, because it is the one that decides the
   rest:
   > What language do you want to work in — English or Spanish? / ¿En qué idioma querés trabajar
   > — inglés o español?

   **Everything after this comes out in the language chosen**: the four questions that follow, the
   files that get written, and the session from here on. Today the system writes `en` and `es`.
2. **Your name.**
3. **Your role**, in one line (example: "Senior PM at a fintech").
4. **Your voice**: tone, and words you would never use. **Optional** — say so when asking: if the
   operator does not know, "later" is an answer and the file says it is pending.
5. **Your organization**: where you work and what it does. For the typical case —one person, one
   employer— that is one. Ask **what it does** and **what you do there**. What you do there is a
   title — identity, written to the body of `context.md`, never to `role:`. `role:` activates an
   oficio from the pack (today: `cpo`) and is born empty; filling it in is a separate, deliberate
   step, not part of this interview.

**"How do you want to be answered" is not asked.** `operator.md` is born with a default —the answer
first, short, no process narration— marked as a section that is learned with use. It gets corrected
the first time an answer misses.

Return the answers summarized and wait for approval before writing anything.

## What it writes

Build an answers file and run the deterministic part:

```
.os/core/lib/bootstrap.sh --brain . --answers <file>
```

Format of the answers file, one key per line:

```
language: en|es
name: <name>
profile: <the role, one line>
voice: <one item>
org: <Name> | <title> | <owner> | <identity file>
```

`voice` and `org` repeat. `language` first: with no `language` the brain is written in English and
the script declares the gap. In `org`, the owner and the identity file are optional: with no owner
the operator is used, and with no identity a placeholder text is left. The title is never `role:` —
see the interview above.

The result is `operator.md`, `voice.md`, `resolver.md`, `tree.md`, the system manual at the root of
the brain —`HOW-IT-WORKS.md` or `COMO-FUNCIONA.md`, in the chosen language— and one folder per
organization.
`voice.md` is the operator's voice — one identity, two questions, never the same sentence in both.
Nothing else: the inbox, the root's own work (initiatives, backlog, decisions, learnings) and the
environment table are born with their first piece of data, like any node.

**It runs once per brain.** If the root pieces already exist, the script stops instead of rewriting
them. Adding an organization to a brain that already exists is `new-org`'s job.

## The backup, in two halves

**Local, always, with no account and no question**: the same script closes the bootstrap with
`git init` and the first commit. Nothing to ask; a brain with no history loses work silently. git is
guaranteed present by the preflight in Step 0 — there is no unversioned brain to describe here.

**Remote, right after**, and it never runs alone:

```
.os/core/lib/remote-backup.sh --brain .
```

- With `gh` authenticated it prints the offer and the exact `gh repo create` command. **Ask the
  operator and run it only with their yes**: it leaves a repository in their account, which escapes
  the system.
- Without `gh`, it leaves the guided task in the root backlog: create the account at github.com
  —**the operator creates it, never the agent**—, run `gh auth login`, and any later session
  finishes the rest by running the same script.

Synced folders (iCloud, Drive) are not offered as backup: the system runs on symlinks and those
folders break them.

## When it finishes

- Show the tree created and what each file answers, in outcomes and not in canonical names.
- **Point at the manual**: the brain was born with the manual of the system at its root, in the
  operator's language, and it stays up to date on its own because it is linked to the product. It is
  where the operator finds what they can ask for. A brain created before the manual existed gets it
  by running `.os/core/lib/manual-link.sh --brain .`.
- If the identity cap warning appears, pass it through as is: the operator chooses the way out.
- If the script reports `sin dato:` or `sin crear:`, pass it through whole and ask again for what is
  missing. A gap nobody names is a gap nobody fills.
- Say whether the brain is versioned and whether the remote is resolved or pending.
- **Say whether the pack landed.** If Step 1 succeeded, name what it added and that the harness
  offers it directly. If it did not, say the pending line is in the root backlog and that everything
  else works without it.
- **How the operator updates all of this is written once**, in the repository's `README.md` under
  **Update**, and is not restated here. Point at it; do not retell it.
- Handoff: if the operator wants to add another organization, the **add an organization** capability
  is needed. If it is not available, say so and continue.
