#!/usr/bin/env python3
"""Overview: what is waiting for the person, as My Wiki's first screen (spec 062).

Internal. `my_wiki_build.py` imports it and hands it what it already read; this file opens two
things nobody else in the product opens — the Claude Code session logs and nothing more — and
returns one dictionary. It never writes: not to the brain, not to a session (C7).

WHAT A SESSION IS, AND WHAT IT IS NOT. Claude Code keeps one `.jsonl` per session under
`~/.claude/projects/<the brain's path, punctuation turned into dashes>/`. Every line is one record.
The records this file uses are four, and it ignores the rest:

  `user` / `assistant`   a turn, with `message.content` and `timestamp`
  `ai-title`             the title the app gave the session
  `custom-title`         the title the person gave it, which wins over the other one

THE FILE'S OWN mtime IS NOT ITS AGE. A backup or a sync touches every log at once; measured over a
real brain, most files carried an mtime days newer than their last record. The age of a session is
the timestamp of its last turn, and only that.

THERE IS NO RECORD OF THE PERSON HAVING READ A SESSION. It was looked for, in the logs, in their
sidecar files and in the app's own state, and it does not exist (spec 062, design-first). So an
answered turn and a read turn cannot be told apart, and this file does not pretend otherwise: a
session whose last turn is the agent's and does not ask anything comes out as `finished · unread`
WITH `unreadByDefault` set, and the page says on the screen that it is showing it for lack of the
datum, never as a fact about what the person read.
"""

import datetime
import json
import os
import re

# The delimiters of a pending question. A turn that ends in one is asking; the closing markdown a
# sentence may drag behind it (a bold marker, a quote, a bracket) is not part of the sentence.
TRAILING = " \t\r\n*`_\"')]}»”"
# A question that is asking for the approval of a spec is a Gate 1, not a question like any other:
# it is the one the supervision pattern of `CLAUDE.md` names, and it reads differently on the page.
GATE1_HINT = re.compile(r"\bgate ?-?1\b", re.IGNORECASE)
# What the session's first message writes to name the scope it works on, in both languages.
FOCUS_LEAD = re.compile(r"\b(?:foco|focus)\b[: ]+([^\n,.;]{2,60})", re.IGNORECASE)
WORD = re.compile(r"[a-z0-9][a-z0-9-]{2,}")
# A turn the harness injected rather than the person typing it: a command's output, a task
# notification, a system reminder. It is not the person answering, and it never opens a session.
INJECTED = ("<", "[Request interrupted", "Caveat:")


def _text(message):
    content = (message or {}).get("content")
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "".join(b.get("text", "") for b in content
                       if isinstance(b, dict) and b.get("type") == "text")
    return ""


def _stamp(value):
    if not value:
        return None
    try:
        return datetime.datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        return None


def _age(now, when):
    """How long ago, as a number and the unit it is counted in. The page puts the word on it."""
    minutes = int(max(0, (now - when).total_seconds()) // 60)
    if minutes < 60:
        return {"n": minutes, "unit": "min"}
    if minutes < 60 * 24:
        return {"n": minutes // 60, "unit": "h"}
    return {"n": minutes // (60 * 24), "unit": "d"}


def _tail(text, cap=220):
    """The last sentence of a turn: what the agent is actually asking, never the whole answer."""
    clean = " ".join(text.strip().split())
    if len(clean) <= cap:
        return clean
    cut = clean[-cap:]
    for sep in (". ", "? ", "! ", "— ", "· "):
        i = cut.find(sep)
        if 0 <= i < cap - 40:
            return cut[i + len(sep):]
    return "…" + cut


# ------------------------------------------------------------------ one session, read once
def read_session(path):
    """The four things a session says: its title, its first message, its last turn of each side.

    The file is opened once, read forward and never written. A line that is not JSON is skipped:
    a log the app is writing right now can end mid-line, and that is not a failure of this page.
    """
    title = ""
    first = ""
    last_user = None
    last_agent = None
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line.startswith("{"):
                    continue
                try:
                    rec = json.loads(line)
                except ValueError:
                    continue
                kind = rec.get("type")
                if kind == "ai-title" and not title:
                    title = rec.get("aiTitle") or ""
                    continue
                if kind == "custom-title":
                    title = rec.get("customTitle") or rec.get("title") or title
                    continue
                if kind not in ("user", "assistant") or rec.get("isSidechain"):
                    continue
                body = _text(rec.get("message")).strip()
                if not body:
                    continue
                when = _stamp(rec.get("timestamp"))
                if kind == "user":
                    if rec.get("isMeta") or body.startswith(INJECTED):
                        continue
                    if not first:
                        first = body
                    if when:
                        last_user = when
                elif when:
                    last_agent = (when, body)
    except OSError:
        return None
    if last_agent is None and not first:
        return None
    return {"title": title, "first": first, "user": last_user, "agent": last_agent}


# ------------------------------------------------------------------ the focus of a session (C3)
class Focus(object):
    """What the first message of a session names, resolved against the pages of the brain.

    The rule is the startup's: the first message names the scope, and inside it the node. A message
    that names a path the wiki has a page for wins; with no path, a slug of a node —the folder that
    gives the node its identity— names it. Neither, and the session is grouped under *no focus*:
    visible, never guessed.
    """

    def __init__(self, pages, wsdir, head_file):
        self.by_path = pages
        self.by_slug = {}
        for path, page in pages.items():
            if page["kind"] not in ("entity", "initiative", "workspace"):
                continue
            base = os.path.basename(path)
            slug = os.path.basename(os.path.dirname(path)) if base == head_file \
                else os.path.splitext(base)[0]
            slug = slug.lower()
            # An entity loses to an initiative of the same name on purpose: the initiative is the
            # stretch of work being done, and that is what a session is opened on.
            if slug not in self.by_slug or page["kind"] == "initiative":
                self.by_slug[slug] = path

    def of(self, message):
        if not message:
            return ""
        head = message[:600]
        for path in self.by_path:
            if path in head:
                # A document is not a focus: the focus is the node it belongs to. A session opened
                # on a research file is a session about the initiative that holds it.
                page = self.by_path[path]
                if page["kind"] in ("entity", "initiative", "workspace"):
                    return path
                owner = page.get("owner") or ""
                if owner in self.by_path:
                    return owner
                return self._slug(head) or ""
        lead = FOCUS_LEAD.search(head)
        if lead:
            hit = self._slug(lead.group(1))
            if hit:
                return hit
        return self._slug(head) or ""

    def _slug(self, text):
        best = ""
        for word in WORD.findall(text.lower()):
            path = self.by_slug.get(word)
            if path and (not best or len(word) > len(best[0])):
                best = (word, path)
        return best[1] if best else ""

    def label(self, path, pages):
        """`Entity › Initiative`: what the node is about, and then the node. One jump, never a
        chain — the same reach the focus read has."""
        page = pages.get(path)
        if not page:
            return ""
        parent = pages.get(page.get("about") or "")
        if parent:
            return parent["title"] + " › " + page["title"]
        return page["title"]


# ------------------------------------------------------------------ threads (C2, C3, C8)
def threads(sessions_dir, now, days, pages, wsdir, head_file):
    focus = Focus(pages, wsdir, head_file)
    window = now - datetime.timedelta(days=days)
    rows = []
    try:
        names = sorted(os.listdir(sessions_dir))
    except OSError:
        return None, rows
    for name in names:
        if not name.endswith(".jsonl"):
            continue
        got = read_session(os.path.join(sessions_dir, name))
        if not got or not got["agent"]:
            continue
        when, body = got["agent"]
        if when < window:
            continue
        # The person spoke last: the turn is theirs, and nothing is waiting for them here. This is
        # the case the criterion asks to leave out.
        if got["user"] and got["user"] > when:
            continue
        asking = body.rstrip(TRAILING).endswith("?")
        if asking:
            label = "gate1" if GATE1_HINT.search(body[-400:]) else "asks"
        else:
            label = "unread"
        path = focus.of(got["first"])
        rows.append({
            "id": name[:-6],
            "title": got["title"] or _tail(got["first"], 60),
            "says": _tail(body),
            "label": label,
            "unreadByDefault": label == "unread",
            "at": when.isoformat(),
            "age": _age(now, when),
            "focus": path,
            "focusLabel": focus.label(path, pages) if path else "",
            "ws": pages[path]["ws"] if path else "",
        })
    rows.sort(key=lambda r: r["at"], reverse=True)
    groups, order = {}, []
    for row in rows:
        key = row["focus"]
        if key not in groups:
            groups[key] = {"focus": key, "label": row["focusLabel"], "threads": []}
            order.append(key)
        groups[key]["threads"].append(row)
    # *No focus* goes last: it is the leftover, never the headline.
    named = [k for k in order if k]
    return len(names), [groups[k] for k in named + [k for k in order if not k]]


# ------------------------------------------------------------------ gates (C4)
def gates(rows, today):
    out = []
    for line in rows:
        cells = line.split("\t")
        if len(cells) < 5:
            continue
        when = cells[4].strip()
        out.append({
            "gate": cells[0].strip(),
            "repo": cells[1].strip(),
            "spec": cells[2].strip(),
            "title": cells[3].strip(),
            "date": when,
            "branch": cells[5].strip() if len(cells) > 5 else "",
            "days": _days_between(when, today),
        })
    out.sort(key=lambda g: (g["gate"], -(g["days"] if g["days"] is not None else -1), g["spec"]))
    return out


def _days_between(when, today):
    a, b = _date(when), _date(today)
    if not a or not b:
        return None
    return (b - a).days


def _date(value):
    try:
        return datetime.date.fromisoformat(str(value)[:10])
    except (ValueError, TypeError):
        return None


# ------------------------------------------------------------------ waiting on others (C5)
def waiting(pages, ws, today, operator):
    """The `waiting_on:` of the workspace's live initiatives that is not the operator.

    WHO COUNTS AS THE OPERATOR IS THE STARTUP'S RULE, not a second one: the literal `operador`, a
    `gate-*`, or the operator's own name. Anything else is somebody else, and that is what this
    block is for — a gate is already its own block above.
    """
    op = (operator or "").strip().lower()
    rows = []
    for path, page in pages.items():
        if page["kind"] != "initiative" or page["ws"] != ws:
            continue
        fm = page["fm"]
        if (fm.get("status") or "").strip().lower() in ("closed", "cerrada", "cerrado"):
            continue
        who = (fm.get("waiting_on") or "").strip()
        low = who.lower()
        if not who or low == "operador" or low.startswith("gate-") or (op and low == op):
            continue
        rows.append({
            "who": who,
            "path": path,
            "title": page["title"],
            "reason": (fm.get("blocked") or "").strip(),
            "days": _days_between(fm.get("updated", ""), today),
        })
    # Longest wait first: this block exists to surface the one that went stale, and a wait of a
    # month is the one that needs a person, not the one from yesterday.
    rows.sort(key=lambda r: (-(r["days"] if r["days"] is not None else -1), r["title"]))
    return rows


# ------------------------------------------------------------------ this week (C6)
def week(pages, ws, today, span):
    start = _date(today)
    if not start:
        return []
    end = start + datetime.timedelta(days=span)
    rows = []
    for path, page in pages.items():
        if page["ws"] != ws:
            continue
        owner = pages.get(page.get("owner") or "") or page
        if owner["kind"] not in ("initiative", "entity", "workspace"):
            continue
        for section in page["sections"]:
            if section["form"] != "tasks":
                continue
            for item in section["items"]:
                if item.get("done"):
                    continue
                day = _date(item.get("date", ""))
                if not day or day < start or day > end:
                    continue
                text = item.get("text", "").strip()
                reason = ""
                if " · " in text:
                    text, _, reason = text.partition(" · ")
                rows.append({
                    "text": text.strip(),
                    "reason": reason.strip(),
                    "date": day.isoformat(),
                    "days": (day - start).days,
                    "path": owner["path"],
                    "node": owner["title"],
                })
    rows.sort(key=lambda r: (r["date"], r["node"], r["text"]))
    return rows


# ------------------------------------------------------------------ the block the page receives
def build(pages, workspaces, wsdir, head_file, options, gate_rows):
    now = _stamp(options.get("now")) or datetime.datetime.now(datetime.timezone.utc)
    if now.tzinfo is None:
        now = now.replace(tzinfo=datetime.timezone.utc)
    today = options.get("today") or now.date().isoformat()
    days = int(options.get("days") or 3)
    span = int(options.get("week") or 7)
    directory = options.get("sessions") or ""

    seen, grouped = threads(directory, now, days, pages, wsdir, head_file) if directory \
        else (None, [])
    return {
        "now": now.isoformat(),
        "today": today,
        "days": days,
        "week": span,
        # No sessions to read is not a failure: the brain may be worked from another machine, or
        # from the app in the cloud. The page says so and shows the other three blocks (C7 of the
        # spec's delegated criteria).
        "sessions": {"dir": directory, "available": seen is not None, "files": seen or 0,
                     "readRecord": False},
        "threads": grouped,
        "gates": gates(gate_rows, today),
        "waiting": {w["slug"]: waiting(pages, w["slug"], today, options.get("operator", ""))
                    for w in workspaces},
        "week_items": {w["slug"]: week(pages, w["slug"], today, span) for w in workspaces},
    }
