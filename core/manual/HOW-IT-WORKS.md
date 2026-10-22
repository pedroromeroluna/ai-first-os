# 📘 AI First OS — how this system works

> [!NOTE] This file is the manual of the system
> It is part of the product and linked from it, so it keeps itself current: when the system is
> updated, this text is updated with it. Nothing you write lives here: whatever you edit in this
> file is overwritten by the next update. Your things live in the other files, and this manual says
> which ones.

## 💡 The idea in one line

**Your agent reads your context from files, works with you in the session, and whatever matters
stays written down** — never inside the memory of a chat.

The files are yours: plain text, in your folder, readable without this system installed. What the
system adds is where each thing goes and who reads it back.

## 🏷️ Two names, two things

- **AI First OS** is the software: the skills, the session contract, the agents. It gets installed
  and updated, and it stores nothing of yours.
- **Your brain** is this folder: your identity, your voice and your work. It is what the system
  operates, and the only part that is yours.

The analogy is an operating system and your disk: the OS gets updated; your brain is never
touched. That is why you do not "install a brain" — you install the OS, and your brain is born
once, through the interview.

## 🗂️ What you see in this folder

**Four things are visible at the root of this folder. Everything else is hidden, because only the
system reads it.** The root holds the machinery of the system and your account — never work. Your
own work is a workspace.

| In the folder | What it is | Who edits it |
|---|---|---|
| `AGENTS.md` | The rule book every session follows before it answers. It is a link to the product | Nobody: it is read-only on purpose |
| `HOW-IT-WORKS.md` | This manual, in your language. Also a link to the product | Nobody |
| `account/` | You: who you are, how you want to be answered and how you write | You |
| `workspaces/` | Your work: one folder per workspace — your own, a company, a client | You and the agent, together |

Inside `account/`:

| File | What it answers |
|---|---|
| `account/operator.md` | Who you are and how you want to be answered. **Your own rules for the agent go here** |
| `account/voice/voice.md` | How you write when you write well. The agent reads it when it is about to write something in your name, not at the start of every session |

### The rule book, and the warning at its top

`AGENTS.md` and `.claude/CLAUDE.md` are two links to the same file, so every agent harness (Claude
Code, Codex, Cursor, OpenCode) finds the rule book where it looks for it. The file opens with a
`[!WARNING]` block: it says the file is not edited, why, and that your rules go in
`account/operator.md`. The reason is simple: that file is the same for everyone who uses the system,
so editing it in your copy means your changes are lost with the next update. On an installed copy
the system also takes the write permission off it, so the editor stops you before you start.

> [!TIP] Your own rules go in account/operator.md
> **Your own rules never go in the rule book.** They go in `account/operator.md`. If this folder
> already had a rules file of your own when the system was installed, installing with `--adopt`
> appends its content to the end of `account/operator.md`, under a heading that says where it came
> from, and puts the system's link in its place. Nothing you wrote is lost.

### What is yours to edit, and what is not

- **Yours:** `account/` (both files), everything inside `workspaces/` — the heads of your
  workspaces, initiatives and products, their `resources/`, `context/` and `research/` — and any
  skill you write yourself.
- **Not yours:** `AGENTS.md`, `HOW-IT-WORKS.md` and `.claude/CLAUDE.md` (links to the product),
  `.os/` (links to the product's tools) and every **generated file**.
- **Edited rarely, and with care:** `.system/`. It is the machinery the root needs to work:
  `tree.md` (the map of the paths a scan walks), `resolver.md` (the table of capabilities and the
  tool that resolves each one; your rows win over the product's) and, on a machine that mounts repos,
  `mounts.md` (the environment table: which repos are mounted, and where). It is hidden because
  nobody needs to open it in a normal day: the system reads it, and the commands that create
  something (a workspace, a product) add their own lines to it.

### Generated files

A **generated file** is one the system writes for you and rewrites on its own. Its frontmatter says
`generated: true`, and the header under it says which files it is built from. Every one opens with a
title and a line under it that say what it is and what you will find in it, such as «Index of
<name>». The `index.md` of a product, a course, a channel or an account is one: after that title it
has a table of its initiatives in progress, with their status, their horizon and a **Tasks** column,
the closed initiatives in a second table, and then tables of the decisions (the key ones first), the
learnings and the documents in its `context/`, `research/` and `resources/` folders. The name of
each initiative links to its `README.md`, where you see what it is about, and the Tasks column links
to its `backlog.md` and says how many tasks are open. To tick a task, open the product's `index.md`,
click the number in the Tasks column and tick the task in `backlog.md`: that file is yours to edit,
the index is not. An initiative has no index of its own: its documents sit next to its `README.md`.
**Do not edit the generated files**: your edit disappears at the next session start. Edit the
source — the initiative, the decision, the learning or the document — and the index follows. A
generated file is not committed to git: every copy of the brain builds its own.

### How a session starts

1. You name the workspace you are working on.
2. The agent runs the **scan** and the **startup read** before answering: first `account/operator.md`,
   then the head of the workspace and its own table of tools, its glossary and its map of contexts
   if it has them, its key decisions, and the tables of tools of the system and of the root. It does
   not load your voice: it reads it when it writes something in your name.
3. You pick a focus, and only then is the body of that initiative or product loaded.

The details of each step are in the cycle of one session, further down.

**Your own work is a workspace, `personal`** — the one every brain is born with, alongside any
company or client you add later. There is one single building block, repeated at every height for
every workspace: the **node**. Every node answers the same questions, and each question is a file:

| File | What it answers |
|---|---|
| `workspaces/<name>/README.md` | What that workspace is and which standing craft it activates |
| `workspaces/<name>/<type>/<slug>/README.md` | What a memory node is, for whom, and what is known about it — `products/` is the one type this system ships with its own tool |
| `workspaces/<name>/people/<slug>.md` | Who a person is, their organization and title, their contact and how it is best to deal with them — content of the workspace, never a node: the scan never reads it |
| `workspaces/<name>/initiatives/<slug>/README.md` | The work: one head per initiative, with its state, its horizon, and optionally `about:` naming the product, course, channel or account it is about — one, or several as `[<path>, <path>]` |
| `workspaces/<name>/initiatives/<slug>/backlog.md` | That initiative's own tasks, and only that initiative's — every task lives in an initiative; the tasks of a product with no project of its own go to its standing initiative |
| `workspaces/<name>/decisions/<date>-<slug>.md` | One decision per file, with why and what would make it false, and `about:` when it is about a product, a course, a channel or an account; `decisions/index.md` lists them all, generated |
| `workspaces/<name>/learnings/<slug>.md` | One learning per file, including what was tried and did not close; `learnings/index.md` lists them all, generated |

**Every node has the same shape: a folder with the name of the thing, and `README.md` inside.** The
name shows up once —the folder—, the head is always called the same, and anyone who opens the folder
knows where to start.

**A brain that predates this shape can still have work written directly at its root.**
`migrate-root.sh` moves it into `workspaces/personal`, creating that workspace first if it is not
there yet — run once, at your request, never on its own.

**A memory node is memory, an initiative is push.** A memory node holds what it is, who it is for
and what is known about it; an initiative holds its state, its horizon and when it closes. A memory
node can outlive every initiative built around it, and an initiative never needs one to exist.

A file is born the first time it has something real to hold. An empty file is not structure: it is
noise that has to be read every session.

### Memory nodes: any folder can be a type

**The folder is the type.** There is no `type:` field anywhere — the path already says what kind of
thing a node is. `products/` is the one type this system ships with its own tool (`prd`, which writes
its strategic layer). Any sibling folder of nodes that hold memory instead of push works exactly the
same way: `accounts/` for client accounts, `channels/` for the channels you publish through, or a
name you invent.

`new-memory --type <type>` creates a type the first time you use it — the folder plus the five lines
it needs in `.system/tree.md` — and adds its first node. The same command with the same `--type` and a new
`--slug` adds another node to a type that already exists — sibling accounts, sibling channels — no
new tree lines, nothing duplicated. A type that is yours, not a client's, lives inside your own
workspace (`personal`) — the root itself never holds one, since it is machinery only.

A type this system ships is named in English — today, only `products`. A type you invent is named
however you like: it is content of your brain, not a component of the system. Three names to start
from, if you want a catalog instead of inventing one: `products` (what you build, for whom),
`accounts` (a client or company relationship), `channels` (where you publish). Inventing your own —
anything that is memory and not push — is exactly as legitimate: the folder plus its lines in
`.system/tree.md`, and a `context/` you fill by hand until a purpose-built tool like `prd` exists for it, if
one ever does.

### People, and the relationship that mentions them

A person is never a node. `workspaces/<name>/people/<slug>.md` is content, the same class as a
workspace's `resources/voice.md` or a product's `research/`: the tree reaches it and counts it, and neither the
scan nor a focus opens it unless the session names it by path. Who someone is, who they work for and
their title, how to reach them, and how it is best to deal with them all live in that one file, written by
hand from `core/templates/person.md` — no command creates it, and a person's frontmatter is never
checked against a fixed list: an extra key is not a finding, and this manual does not promise it is.

**What ties a person to a node is a line in the node itself, never a field on the person.** The same
person can decide one initiative and sit on the workspace's own team at the same time, and writing
both relationships on the person's file would keep two copies in sync by hand instead of one. The line
carries the person's path in backticks, their role, and since when:

`` `people/<slug>.md` · <role> · since <date> ``

Nothing parses it on its own — a check that opened every initiative's body to verify a path would undo
the reason the scan stays fast — and it is written at three heights, each its own section:

- **Stakeholders of an initiative** — its own `## Stakeholders` section, for whoever decides on or is
  affected by that one piece of work.
- **Stakeholders of an entity** — the same section on a product's, an account's or a channel's head,
  for whoever is a stakeholder of the thing itself, not of one initiative built around it.
- **Team of the workspace** — a `## Team` section on the workspace's own head, for whoever is part of
  it on a standing basis, tied to no initiative.

## 🔄 The cycle of one session

> [!EXAMPLE] One session from start to end
> 1. **Start.** You name the workspace — your own work is `personal`, the one every brain is born with
>    — and the agent runs the **scan** before answering anything: what is waiting on your decision,
>    what is in progress, what is blocked and by whom, what is queued, and what the checks found. Then
>    you pick a focus, and only then is the body of that initiative loaded.
> 2. **Work.** Every request is routed to its tool through the resolver. Nothing activates on its own,
>    and no irreversible action —sending, publishing, signing, merging— runs without your yes.
> 3. **Capture.** Whatever shows up mid-conversation is filed where it belongs without cutting the
>    thread, and the answer says where it went.
> 4. **Close.** Two questions —what cannot be lost, and what almost worked— and a verdict in four
>    parts: what was filed, what was not, which row the resolver could gain, and where to resume.
>    Never a plain "done": a close that only says it finished cannot be told apart from one that lost
>    something.

## 🧠 Living Memory: finding what the focus does not load

The scan and the focus only ever load a fixed list of files, plus one jump through `about:`. A
decision written months ago in another workspace is real, but nothing surfaces it on its own — until
you, or the agent on your behalf, ask `recall` for it.

`recall` searches every file the tree reaches, split into entries — a heading and its body, or one
list item, never a whole file at a time — and returns the closest matches with their file, line and
date, current work ahead of anything a file says replaced it. `recall --expand <path>` shows a
result's immediate neighbours: what it is about, what is about it, what replaced it, what it
replaced.

**It finds, it does not decide.** Two results that are both current and say different things are
handed to you as a contradiction to resolve, never quietly picked between. And it is disposable: what
it searches is a small file it rebuilds from your own files on its own, never something you write to
or back up.

## ⚙️ Where the machinery lives

The tools —skills, scripts, agents— live in `.os/`, `.claude/` and `.agents/`. Those folders are
hidden in Obsidian and visible from the terminal, and what the system puts in them is a **link** to
the installed product: updating the system never touches your data, and your data never travels
inside the product.

**Where the skills live**, since it is the first thing everyone asks: the
<!--count-->twenty<!--/count--> skills of the system are in `.os/core/skills/`, one file each,
reached through the resolver — not copied into this folder, linked to the product. The skills of a
pack are in `.agents/skills/<name>/SKILL.md`, one folder per skill, and `.claude/skills/` holds a
link to each one, which is where Claude Code reads skills from; the system looks in `.agents/skills/`
first and counts a skill that is in both folders once. Any skill you write yourself goes next to
them, as a plain folder in `.claude/skills/`.

> [!TIP] To update, ask any session to "update the system"
> To update, ask any session: **"update the system"**. That sentence is all you need, and it
> covers both halves of what is installed — the system and the packs. What it does step by step is
> written once, in the `README.md` of the product's folder under **Update**; this manual points at
> it instead of telling it again, because two versions of the same procedure drift apart.

## 🧰 Requirements

**`git` is required; Python 3 is recommended.** The system installs without Python and says so when it
does. Without Python 3, two things do not work:

- **Connecting a code repository** (`mount-repo`).
- **Living Memory search** (`recall`). The AI searches the files as plain text instead: it cannot put
  the current version of a document above a replaced one, open the exact section, or follow what a
  document is about or what replaced it.

To get them, install Python from python.org: the system finds it as `python3`, `python` or `py -3`.
Nothing needs to be reinstalled.

## 💬 What you can ask for, and how

**The index is the resolver, not your memory.** You ask in your own words —"what is pending", "close
the session", "capture this"— and the agent looks up which tool covers that capability. Two files
answer that: the product's, which travels with the system, and yours (`.system/resolver.md`), where you add
a row when the agent would have chosen wrong without it. Your rows win.

The catalog below is the system itself — the <!--count-->twenty<!--/count--> tools that come with
it. You can also invoke any of them by name.

<!-- catalog: generated by scripts/manual-catalog.sh — do not edit by hand -->

**The core** — the tools that run the system:

- **`archive`** — Move a document into the node's `archive/` so the focus stops loading it and starts listing it by name, rewriting every reference that pointed at it — and bring it back the same way.
- **`bootstrap`** — Create the brain from scratch — the gateway skill.
- **`capture`** — File what the operator throws in mid-conversation into the backlog of the initiative that consumes it, once an initiative is named — nothing is filed unclassified.
- **`check-resolvable`** — Audit the root's capability-to-tool graph and report the three failures it can have — a tool nothing routes to, a handoff no row provides, and a row pointing at a tool that does not exist.
- **`close-session`** — Close a session by distributing what it produced —decisions, learnings, pending items, what stayed waiting, where to resume— into the loaded node's canonical files, and end with a four-part verdict that names what was not captured.
- **`grill`** — Pressure the facts behind a claim before a decision closes — counter-question with a concrete example, capped attempts, escape hatches, evidence hierarchy — and route what comes out to the loaded node's decisions or backlog.
- **`migrate-layout`** — Move a brain with the old layout to the new one — the account in `account/`, the machinery in `.system/`, the session contract at `AGENTS.md` and `.claude/CLAUDE.md`, roles as skills, the hand-written decision and learning indexes into the frontmatter of the files they link, every backlog into an initiative, hidden resolvers, `resources/` and `context/` — printing the whole plan first and writing nothing until it runs with `--apply`.
- **`migrate-root`** — Move the operator's own work from a brain still carrying it directly at the root — initiatives, a memory-node type, backlog, decisions, learnings — into the `personal` workspace every brain is born with today, creating that workspace first if it does not exist yet, rewriting the prefix everywhere the system reads it as structure or routing, and listing what it leaves untouched for the operator to review.
- **`mount-repo`** — Give an initiative a body: write the remote into the head's frontmatter, clone the checkout outside the brain —or, with --new, give birth to the repo from the product's scaffold when it does not exist yet— and record the remote-to-local-path row in the machine's environment table.
- **`new-memory`** — Create a memory-node type the first time it is used —a folder plus its five lines in `tree.md`— and add a node to it.
- **`new-product`** — Add a product to a workspace that already exists.
- **`new-spec`** — Turn concrete build work that came out of a conversation into a spec file under the target repo's specs/, with runnable evals per criterion, decisions split by who closes them, and effects that escape the system declared.
- **`new-workspace`** — Add a workspace to an existing brain.
- **`orchestrator`** — Turn on, or resume, an orchestrator — one session that hands each topic's work to that topic's session and keeps what it needs to remember in a hidden file.
- **`recall`** — Search over every file `tree.md` reaches — not only what the startup scan and the focus load — and return the entries that match, with file, line, date and whether each is current or replaced.
- **`rename-heads`** — Move a brain born before the single node shape to it — every node becomes a folder with its `README.md` inside, every initiative gets its own folder, and each product's dated documents move to `research/` — rewriting the head paths everywhere the system reads them as routing and listing what it leaves untouched.
- **`rename-workspaces`** — Move a brain still using the previous name of the workspaces folder to the current one, rewriting the prefix everywhere the system reads it as structure or routing, and listing what it leaves untouched for the operator to review.
- **`supersede`** — Write on a file the mark that says which other file replaced it, so a session that opens the old one knows what to read instead, and audit the marks of the whole brain — the ones that point at a file that is not there, the ones that close a cycle, and the heads that were replaced and still read as open work.
- **`sweep`** — Run one of the three global scans over every workspace plus the root's own work — what is pending, what is blocked and why, or how the roadmap is going — reading frontmatter only.

<!-- /catalog -->

### Packs: the craft on top

Those <!--count-->twenty<!--/count--> run the system. **The craft —building product, and whatever
comes next— arrives in packs**, and a pack is installed separately, with its own command, into
`.agents/skills/` of this folder. **A pack is offered, never required**: the install ended by asking
whether you wanted one now or later, and if you said later the task is in your backlog with the
command in it. Adding another one, putting one back, or taking the one you postponed is a single
request to any session: **"install the pack called `<name>`"**.

**This manual does not list what a pack contains, on purpose.** Every pack ships its own index, and
that index arrives with it — so the list you read is always the list you have, never the one the
manual remembered. Ask for what you want in your own words: the session reads the index of whatever
is installed and routes you there, or tells you that nothing installed covers it.

## 🎛️ An orchestrator, if you want one

**Optional, and off until you ask.** An orchestrator is one session where you decide what matters
and from which the work is handed to the other sessions, one per topic. Nothing in this folder
changes for it to exist: no new file shows up. What it needs to remember (which session carries
each topic, what is waiting for what) it keeps in a hidden file that you never have to open.

- **To turn it on**, say "I want to work with an orchestrator". It tells you what it will set up
  and waits for your yes before doing it.
- **To turn it off**, ask for it. It deletes that hidden file and nothing else changes.
- **How you want it to work** goes in `account/operator.md`, in your own words: what you write there
  wins over the orchestrator's default rules.
- **In the desktop app** it works fully: it opens one session per topic, sends work to each and sees
  how much context each is using. **In the terminal** it works reduced: it hands work out, but it
  cannot open new sessions or see how much context each one is using. It tells you which one you are
  in when it turns on.

## 🚦 Working with agents: two gates, one autonomous stretch

Heavy work is delegated to agents that run in the background, while the main session stays at the
helm — it never changes folders and never loses your context.

- **`scout`** — reads sources (code, documentation, another spec) and comes back with a synthesis.
  It writes nothing: the tool it runs with cannot touch a file.
- **`complete-spec`** — implements a spec where every criterion has its runnable check.
- **`ambiguous-spec`** — implements a spec with open decisions, where judgment is needed.

> [!EXAMPLE] One spec from start to end: two approvals and one autonomous stretch
> The supervision pattern has **two human gates and one autonomous stretch in the middle**: a
> person approves the spec (**gate 1**) → the agent implements it on a branch, never on the main
> branch and never with a push → a person reads the branch and merges it (**gate 2**). Autonomy in
> the middle, human control at the edges.

## 🛠️ Dormant capabilities: the building layer

This system is not only for deciding: **it also builds product, and that half stays asleep until you
ask for it.** It is not a mode you turn on for the whole brain, nor something you install again: it
**activates per initiative**, the day one of them stops being a decision and starts being something
built.

When that happens, two capabilities wake up:

- **`mount-repo`** — gives an initiative a body: it points the head at the code repository, leaves
  the checkout outside your folder, and records where it landed on this machine. If the repository
  does not exist yet, the same command gives birth to it —with its constitution, its folders and its
  first commit— and hands you the command to create the remote. From there, that initiative has
  somewhere to build.
- **`new-spec`** — turns build work that came out of a conversation into a spec: what has to be
  true, how each criterion gets checked, which decisions are already closed and which ones are
  still open with who closes them. That spec is what an agent then implements, with the two gates
  above.

You do not need to prepare anything today. Ask for it —"this initiative is going to be built"— and
the two are already installed.

## 🛑 What the system never does on its own

- **Nothing activates by itself.** The tool is chosen through the resolver and invoked explicitly.
- **No irreversible action runs alone.** Sending, publishing, signing and merging are prepared and
  then asked for.
- **Whatever the AI writes is marked**: 📌 literal, with the file and the line it came from · 🔍
  inference · ❓ gap. What is missing is recorded as open, with who closes it. It is never invented.

## 🧭 How to read the callouts

The system's files use few callouts, each with one meaning only:

- **Blue (note):** what this file is.
- **Tip:** how to do something with one sentence.
- **Yellow (warning):** something that gets lost or must not be edited, like a generated file or a
  document another one replaced.
- **Question:** a decision that is still open.
- **Example:** one case from start to end.
- **Red (danger):** errors only.
