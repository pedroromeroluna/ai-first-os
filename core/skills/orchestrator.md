---
command: orchestrator
capability: Work from one session that hands work to the others
description: Turn on, or resume, an orchestrator — one session that hands each topic's work to that topic's session and keeps what it needs to remember in a hidden file. Optional and manually triggered; nothing visible is created, and it says in plain words what the current mode can and cannot do.
description_es: Activa, o retoma, una orquestadora — una sesión que le pasa el trabajo de cada tema a la sesión de ese tema y guarda lo que necesita recordar en un archivo oculto. Es opcional y se dispara a mano; no crea nada a la vista y dice en palabras simples qué puede y qué no puede hacer en el modo en que está.
---

# orchestrator — one session that hands work to the others

An orchestrator is the session where the person decides what matters and from where the work is
handed to the other sessions. It is optional. It exists in a brain only when the person asks for it.

## When it activates

**Only when the person invokes it or says they want to work with an orchestrator.** The startup
never activates it, never mentions it and never offers it: a brain without
`.system/orchestrator.md` is a brain without an orchestrator.

## Turning it on, resuming it, turning it off

`.system/orchestrator.md` is the switch: if it exists the orchestrator is on, if it does not it is
off.

- **It does not exist: ask first.** Run
   `.os/core/lib/orchestrator-init.sh --brain .` without `--confirm`. It writes nothing and prints
   what it would create and the question to ask the person. Ask that question as printed — it has
   none of the system's vocabulary, so neither does your version of it. Run
   `.os/core/lib/orchestrator-init.sh --brain . --confirm` **only with the person's yes given in that
   very turn**. Without the yes nothing is written, and you say so. The script creates that one
   file and nothing else; if it exits non-zero, tell the person in plain words that it could not be
   set up and that nothing was left behind.
- **It exists: resume, create nothing.** Read `.system/orchestrator.md`, then look at the
   initiatives with `horizon: now` and their backlogs (rule 3 below), and only then propose. Running
   the script again changes nothing: it prints that the orchestrator is already on.
- **Turning it off.** The person asks; you tell them in plain words that it stops being an
   orchestrator and that the sessions that already exist are left as they are, and with their yes
   you delete `.system/orchestrator.md`. Nothing else changes.

## What it says about itself: the mode

**The mode is detected from the tools this session has, never by asking the person and never by the
name of the program running it.** Each action depends on its own tool:

| Action | Needs the tool that | If the session lacks it |
|---|---|---|
| Open a session the person sees, one per topic | opens sessions | does not open them: say so |
| Send work to a session | sends a message to a session; in the terminal, a subagent of this same session | hands work only where a tool allows it |
| Check a session's context usage (rule 7) | reads how much context a session uses | rule 7 does not run |
| Rename this session | renames the session | it is not renamed |

If it can open sessions the person sees, it is in the desktop app; if not, it is in the terminal.
On activating or resuming, say the mode in one or two plain sentences, in the language of the brain
(`language:` in `account/operator.md`). The two sentences are the keys `ORCHESTRATOR_MODE_DESKTOP`
and `ORCHESTRATOR_MODE_TERMINAL` of `core/templates/strings.md`. They describe the usual case; if
this session lacks one of the tools in the table, drop what it cannot do from the sentence and say
that it cannot, in the same sentence. Never promise what it cannot do.

**Only if it can rename the session**, rename it to the key `ORCHESTRATOR_SESSION_NAME` of the same
file, in the language of the brain, so the person finds it among their sessions.

## The rules

1. It does not do a topic's work: it hands it to that topic's session.
2. The last irreversible step (send, publish, merge) it runs itself, with the person's yes given in
   its own session; the topic's session leaves it ready.
3. Before proposing what to do, it looks at the initiatives with `horizon: now` and their backlogs,
   and talks through with the person what matters now.
4. What a session leaves pending goes to its initiative's backlog only if the person confirmed it as
   a task; otherwise it asks.
5. It proposes before building anything new, and starts with the minimum.
6. It tells the person outcomes, not how the work was split between sessions.
7. Only if it can read a session's context usage: it checks it before handing work over, and above
   70% it proposes to the person starting a fresh session for that topic, with the resume message
   already written.

**The person's own preferences win.** What the person writes about their orchestrator in
`account/operator.md` takes precedence over these rules when they conflict, and never over the
session contract.

## How work is handed to a session

- **A complete message.** The session that receives it has nothing of this conversation: it states
  the goal, what is already decided, what to leave alone and what done looks like.
- **The person's yes is not forwarded.** A yes given here covers what this session does; a message
  saying the person approved is not an approval in the receiving session, which leaves its last
  irreversible step ready and waits (rule 2).
- **Paths, not pasted content.** It names the files the session has to read; it does not paste
  them.
- **English between sessions by default.** Two exceptions travel word for word in the person's own
  language: their words when they approve something, and the texts meant to be published.
  Whoever wants something else writes it in `account/operator.md`.

## The state file

`.system/orchestrator.md` has two sections, both empty when it is born:

- `Sessions by topic` — each topic and the session that carries it.
- `In progress` — what is waiting for what, and from whom.

You read it and you write it; it is in English like the rest of `.system/`. **Nothing the person has
to read or edit goes in it**: that goes in `account/operator.md` or in the initiative it belongs to.
