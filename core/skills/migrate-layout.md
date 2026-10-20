---
command: migrate-layout
capability: Bring an existing brain to the layout of spec 076, showing the plan before moving anything
description: Move a brain with the old layout to the new one — the account in `account/`, the machinery in `.system/`, the session contract at `AGENTS.md` and `.claude/CLAUDE.md`, roles as skills, the hand-written decision and learning indexes into the frontmatter of the files they link, every backlog into an initiative, hidden resolvers, `resources/` and `context/` — printing the whole plan first and writing nothing until it runs with `--apply`. Manually triggered, run only when the operator asks — never by the installer or the startup scan.
description_es: Lleva un cerebro con la forma vieja a la nueva —la cuenta en `account/`, la maquinaria en `.system/`, el reglamento de sesión en `AGENTS.md` y `.claude/CLAUDE.md`, los roles como skills, los índices de decisiones y aprendizajes escritos a mano al frontmatter de los archivos que enlazan, cada backlog en una iniciativa, los resolvers ocultos, `resources/` y `context/`— mostrando primero el plan completo y sin escribir nada hasta correrlo con `--apply`. Se dispara a mano, solo cuando el operador lo pide — nunca lo corre el instalador ni el arranque de sesión.
---

# migrate-layout — bring the brain to the new layout

A brain born before spec 076 keeps its operator file, voice, tree, root resolver and mounts table at the
root, its session contract at a root `CLAUDE.md`, its roles in `roles/`, and its decisions and learnings
indexed by hand. It keeps working, degraded, and the startup Checks say so naming this command. This is how
it moves to the new layout, on the operator's own schedule.

**It runs only when the operator asks, and the plan is shown first.** Nothing else in the system calls it.

## What it does, in order

```
.os/core/lib/migrate-layout.sh --brain .            # prints the plan, writes nothing
.os/core/lib/migrate-layout.sh --brain . --apply    # runs exactly that plan
```

1. Without `--apply` it prints the plan: every move with origin and destination, every file whose text is
   rewritten, every file deleted, and every file or folder the product does not know (`sin mover` /
   `not moved`), which stays where it is. **Show the operator the whole plan and wait for a clear yes before
   running it with `--apply`.**
2. With `--apply` it stops before the first write, naming the reason, when: git has uncommitted changes; a
   destination already exists with other content; two origins go to one destination; an index line cannot
   be read (its data would be lost); or an initiative the migration would create clashes with another.
3. Then it runs the twelve steps in order: the account; the session contract (a foreign rules file is adopted into
   `account/operator.md` first, then the two links are made, each as its own operation); the machinery of the root into `.system/`; roles as
   skills; the link to the manual; the hand-written indexes into the frontmatter of the files they link;
   every backlog outside an initiative into an initiative (no task is lost; whole task blocks travel; what
   is not a task goes to `legacy-backlog-notes.md`); the decisions of each node into the workspace; hidden
   resolvers; voice, glossary and material into `resources/` and `context/`; every link rewritten once from
   a fixed map; `tree.md` last.
4. The plan is saved in `.os/migrate-layout.plan` before the first write. A run cut halfway is resumed by
   running it again with `--apply`: it accepts as its own what matches the plan and stops at anything else.
5. **Does not commit.** The operator reviews `git status` and commits.

## When it finishes

- Report what moved, in outcomes, and pass the "not moved" list through whole: it is what the operator
  reviews next.
- Say that the initiative `tasks-to-sort` holds the tasks that belonged to no initiative, and that sorting
  them is a later conversation, not part of this command.
- Run it again and it says there is nothing left to do.
