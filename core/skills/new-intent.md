---
command: new-intent
capability: Write a new intent
description: Turn an idea that came out of a conversation into a one-page intent file under the target repo's intents/, for a person to accept or reject before any spec exists. Manually triggered, before new-spec.
description_es: Convierte en una intención de una página, adentro de intents/ del repo destino, una idea que salió de una conversación, para que una persona la acepte o la rechace antes de que exista una spec. Se dispara a mano, antes de new-spec.
---

# new-intent — one page a person accepts or rejects before the spec

An intent says what is going to change and why, in words a person who does not read specs can decide.
It comes before `new-spec`: a rejected idea costs one page, not a whole spec. An intent may yield several specs, or none.

## 1. Target repo

- No mounted repo: stop and offer `mount-repo`. An intent lives in a repo, next to `specs/`.
- If the repo has no `intents/`, create it with an `intents/.gitkeep`.
- The number is the highest `NNN` in `intents/*.md` plus one, three digits, starting at `001`. It is independent of the numbers of the specs.
- `intents/` is flat and is never archived.

## 2. The template

The file is `intents/NNN-short-name.md`. The frontmatter is in English; the body is written in the language of the conversation, section titles included. This template is the source:

```
---
status: pending
---

# NNN · <title>

## Problem

## Desired outcome

## Who and what it affects

## Constraints

## Open questions
```

Interview only what is missing, with a proposed default at every gap. The intent stays on one page: no checks and no state of the code, that belongs to the spec.

## 3. Status

`status` is `pending | accepted | rejected`. A `rejected` intent carries `reason: <text>` in the same frontmatter and is kept, never deleted.

The status changes only on the person's explicit accept or reject in that turn. The AI records it, with the reason when rejected, and never sets `accepted` on its own initiative. There is no separate accept command.

## 4. Deliver

1. Show the complete intent before writing it and wait for the go-ahead.
2. Write it with `status: pending` and commit it to `main` of the target repo right away, as `new-spec` does: committing reserves the number.
3. Ask the person to accept or reject it. Record the decision (`status: accepted`, or `status: rejected` with `reason:`) and have it committed to `main` of the target repo right away, before `new-spec`. On accept, the next step is `new-spec`, which names the intent in the `intent:` field of the spec's frontmatter.
