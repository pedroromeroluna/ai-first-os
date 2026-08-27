# AI First OS — how this system works

> **This file is the manual of the system, and it is part of the product.** It is linked from the
> product, so it stays up to date on its own: when the system is updated, this text is updated with
> it. Nothing you write belongs here — anything you edit in this file is overwritten by the next
> update. Your things live in the other files, and this manual says which ones.

## The idea in one line

**Your agent reads your context from files, works with you in the session, and whatever matters
stays written down** — never inside the memory of a chat.

The files are yours: plain text, in your folder, readable without this system installed. What the
system adds is where each thing goes and who reads it back.

## Two names, two things

- **AI First OS** is the software: the skills, the session contract, the agents. It gets installed
  and updated, and it stores nothing of yours.
- **Your brain** is this folder: your identity, your voice and your work. It is what the system
  operates, and the only part that is yours.

The analogy is an operating system and your disk: the OS gets updated; your brain is never
touched. That is why you do not "install a brain" — you install the OS, and your brain is born
once, through the interview.

## Everything is a node

There is one single building block, repeated at every height: the **node**. Your own work is a node
—the root of this folder—, and each **workspace** —a company or client you work for; a course case
is one too— is another one (`workspaces/<name>/`). Every node answers the same questions, and each
question is a file:

| File | What it answers |
|---|---|
| `operator.md` | Who you are and how you want to be answered |
| `voice.md` | How you write when you write well |
| `resolver.md` | Capability → tool: which skill resolves which request |
| `tree.md` | Which paths a scan walks — the map of the system |
| `workspaces/<name>/README.md` | What that workspace is and which standing craft it activates |
| `workspaces/<name>/<type>/<slug>/README.md` | What a memory node is, for whom, and what is known about it — `products/` is the one type this system ships with its own tool |
| `initiatives/<slug>/README.md` | The work: one head per initiative, with its state and its horizon |
| `backlog.md` | What is missing and belongs to no initiative |
| `decisions.md` | What was decided, why, and what would make it false |
| `learnings.md` | What was learned, including what was tried and did not close |
| `inbox.md` | What could not be classified — it is never dropped in silence |

**Every node has the same shape: a folder with the name of the thing, and `README.md` inside.** The
name shows up once —the folder—, the head is always called the same, and anyone who opens the folder
knows where to start. The root is the exception: its folder is this one, and its head is
`operator.md`.

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
it needs in `tree.md` — and adds its first node. The same command with the same `--type` and a new
`--slug` adds another node to a type that already exists — sibling accounts, sibling channels — no
new tree lines, nothing duplicated. `--root` makes the type live at the root of your own work instead
of inside a workspace, the way `channels/` can live there for content that is yours, not a client's.

A type this system ships is named in English — today, only `products`. A type you invent is named
however you like: it is content of your brain, not a component of the system. Three names to start
from, if you want a catalog instead of inventing one: `products` (what you build, for whom),
`accounts` (a client or company relationship), `channels` (where you publish). Inventing your own —
anything that is memory and not push — is exactly as legitimate: the folder plus its lines in
`tree.md`, and a `context/` you fill by hand until a purpose-built tool like `prd` exists for it, if
one ever does.

## The cycle of one session

1. **Start.** You name the scope —a workspace, or your own work— and the agent runs the **scan**
   before answering anything: what is waiting on your decision, what is in progress, what is blocked
   and by whom, what is queued, and what the checks found. Then you pick a focus, and only then is
   the body of that initiative loaded.
2. **Work.** Every request is routed to its tool through the resolver. Nothing activates on its own,
   and no irreversible action —sending, publishing, signing, merging— runs without your yes.
3. **Capture.** Whatever shows up mid-conversation is filed where it belongs without cutting the
   thread, and the answer says where it went.
4. **Close.** Two questions —what cannot be lost, and what almost worked— and a verdict in four
   parts: what was filed, what was not, which row the resolver could gain, and where to resume.
   Never a plain "done": a close that only says it finished cannot be told apart from one that lost
   something.

## Where the machinery lives

The tools —skills, scripts, agents— live in `.os/` and `.claude/`. Those two folders are hidden in
Obsidian and visible from the terminal, and they are **links** to the installed product: updating
the system never touches your data, and your data never travels inside the product.

**Where the skills live**, since it is the first thing everyone asks: the
<!--count-->thirteen<!--/count--> skills of the system are in `.os/core/skills/`, one file each,
reached through the resolver — not copied into this folder, linked to the product. The skills of a
pack are in `.claude/skills/<name>/SKILL.md`, one folder per skill, which is where your harness
reads skills from and why they answer to their name. Any skill you write yourself goes next to them,
as a plain folder in `.claude/skills/`.

To update, ask any session: **"update the system"**. That sentence is all you need, and it covers
both halves of what is installed — the system and the packs. What it does step by step is written
once, in the `README.md` of the product's folder under **Update**; this manual points at it instead
of telling it again, because two versions of the same procedure drift apart.

## What you can ask for, and how

**The index is the resolver, not your memory.** You ask in your own words —"what is pending", "close
the session", "capture this"— and the agent looks up which tool covers that capability. Two files
answer that: the product's, which travels with the system, and yours (`resolver.md`), where you add
a row when the agent would have chosen wrong without it. Your rows win.

The catalog below is the system itself — the <!--count-->thirteen<!--/count--> tools that come with
it. You can also invoke any of them by name.

<!-- catalog: generated by scripts/manual-catalog.sh — do not edit by hand -->

**The core** — the tools that run the system:

- **`bootstrap`** — Create the brain from scratch — the gateway skill.
- **`capture`** — File what the operator throws in mid-conversation into the right backlog —a workspace's, the root's, or the inbox when it cannot be classified— without opening a discussion about it.
- **`check-resolvable`** — Audit the root's capability-to-tool graph and report the three failures it can have — a tool nothing routes to, a handoff no row provides, and a row pointing at a tool that does not exist.
- **`close-session`** — Close a session by distributing what it produced —decisions, learnings, pending items, what stayed waiting, where to resume— into the loaded node's canonical files, and end with a four-part verdict that names what was not captured.
- **`grill`** — Pressure the facts behind a claim before a decision closes — counter-question with a concrete example, capped attempts, escape hatches, evidence hierarchy — and route what comes out to the loaded node's decisions or backlog.
- **`mount-repo`** — Give an initiative a body: write the remote into the head's frontmatter, clone the checkout outside the brain —or, with --new, give birth to the repo from the product's scaffold when it does not exist yet— and record the remote-to-local-path row in the machine's environment table.
- **`new-memory`** — Create a memory-node type the first time it is used —a folder plus its five lines in `tree.md`— and add a node to it.
- **`new-product`** — Add a product to a workspace that already exists.
- **`new-spec`** — Turn concrete build work that came out of a conversation into a spec file under the target repo's specs/, with runnable evals per criterion, decisions split by who closes them, and effects that escape the system declared.
- **`new-workspace`** — Add a workspace to an existing brain.
- **`rename-heads`** — Move a brain born before the single node shape to it — every node becomes a folder with its `README.md` inside, every initiative gets its own folder, and each product's dated documents move to `research/` — rewriting the head paths everywhere the system reads them as routing and listing what it leaves untouched.
- **`rename-workspaces`** — Move a brain still using the previous name of the workspaces folder to the current one, rewriting the prefix everywhere the system reads it as structure or routing, and listing what it leaves untouched for the operator to review.
- **`sweep`** — Run one of the three global scans over every workspace plus the root's own work — what is pending, what is blocked and why, or how the roadmap is going — reading frontmatter only.

<!-- /catalog -->

### Packs: the craft on top

Those <!--count-->thirteen<!--/count--> run the system. **The craft —building product, and whatever
comes next— arrives in packs**, and a pack is installed separately, with its own command, into
`.claude/skills/` of this folder. **A pack is offered, never required**: the install ended by asking
whether you wanted one now or later, and if you said later the task is in your backlog with the
command in it. Adding another one, putting one back, or taking the one you postponed is a single
request to any session: **"install the pack called `<name>`"**.

**This manual does not list what a pack contains, on purpose.** Every pack ships its own index, and
that index arrives with it — so the list you read is always the list you have, never the one the
manual remembered. Ask for what you want in your own words: the session reads the index of whatever
is installed and routes you there, or tells you that nothing installed covers it.

## Working with agents: two gates, one autonomous stretch

Heavy work is delegated to agents that run in the background, while the main session stays at the
helm — it never changes folders and never loses your context.

- **`scout`** — reads sources (code, documentation, another spec) and comes back with a synthesis.
  It writes nothing: the tool it runs with cannot touch a file.
- **`complete-spec`** — implements a spec where every criterion has its runnable check.
- **`ambiguous-spec`** — implements a spec with open decisions, where judgment is needed.

The supervision pattern has **two human gates and one autonomous stretch in the middle**: a person
approves the spec (**gate 1**) → the agent implements it on a branch, never on the main branch and
never with a push → a person reads the branch and merges it (**gate 2**). Autonomy in the middle,
human control at the edges.

## Dormant capabilities: the building layer

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

## What the system never does on its own

- **Nothing activates by itself.** The tool is chosen through the resolver and invoked explicitly.
- **No irreversible action runs alone.** Sending, publishing, signing and merging are prepared and
  then asked for.
- **Whatever the AI writes is marked**: 📌 literal, with the file and the line it came from · 🔍
  inference · ❓ gap. What is missing is recorded as open, with who closes it. It is never invented.
