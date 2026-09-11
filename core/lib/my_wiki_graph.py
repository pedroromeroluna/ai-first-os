#!/usr/bin/env python3
"""My Wiki's Graph screen (spec 061). Internal: `my_wiki_build.py` imports `build_graph` and calls
it once, after every page of the wiki already exists and is rendered. This file opens no file of
its own and parses no markdown of its own — everything it needs is handed in by the caller, which
is spec 060's stopping condition for a second reader of the format.

NO SECOND LINK ENGINE. A page's edges come from the same three sources spec 060 already put on the
page's own fields and cached raw text — `about:`, a path inside backticks, and a path into
`people/` — and from nothing else. A page that names another one by title, with no path attached,
draws no edge (spec 061 C2): that is the difference between this graph and a person's `mentions`,
which is a fuzzy, name-based list built for a different purpose.

ONE `git log` FOR EVERY FIRST-COMMIT DATE, NEVER ONE PER FILE. `history_lines` is the untouched
output of a single call the bash side made; this module walks it once and keeps, for every path,
the earliest date it saw — regardless of what order the log itself lists commits in, so nothing
here depends on that log being chronological.
"""

import re

CODE_RE = re.compile(r"`([^`]+)`")
PEOPLE_RE = re.compile(r"people/[^\s)\]`]+")


def _clean_path(raw):
    return raw.strip().strip("`").split("#")[0].lstrip("./").rstrip("/")


def _resolve_doc(raw, pages):
    """A backtick span that names a page, directly or by its node's directory."""
    path = _clean_path(raw)
    if path in pages:
        return path
    cand = path + "/README.md"
    if cand in pages:
        return cand
    return None


def _resolve_person(raw, pages):
    """A `people/...` span that names a person page, even when it is shorter than the full path —
    the same tolerance the sections of 060 already give a stakeholder's `[ficha](people/x.md)`."""
    tail = raw.strip().strip("`)]")
    for p, page in pages.items():
        if page.get("kind") != "person":
            continue
        if p == tail or p.endswith("/" + tail.split("/", 1)[-1]):
            return p
    return None


def _raw_text(rel, cache):
    """The page's own markdown — lede and every section's body — exactly as `my_wiki_build.read`
    cached it before rendering. Reading `cache` instead of the file again is what keeps this a
    zero-read module: the bytes were already opened once, by the caller."""
    hit = cache.get(rel)
    if not hit:
        return ""
    _, _, lede, sections = hit
    lines = list(lede)
    for _, body in sections:
        lines.extend(body)
    return "\n".join(lines)


def _links(rel, page, cache, pages):
    out = set()
    about = (page.get("about") or "").strip()
    if about and about in pages:
        out.add(about)
    text = _raw_text(rel, cache)
    for m in CODE_RE.finditer(text):
        hit = _resolve_doc(m.group(1), pages)
        if hit and hit != rel:
            out.add(hit)
    for m in PEOPLE_RE.finditer(text):
        hit = _resolve_person(m.group(0), pages)
        if hit and hit != rel:
            out.add(hit)
    return out


def _first_dates(history_lines):
    first = {}
    date = ""
    for line in history_lines:
        if line.startswith("\x01"):
            date = line[1:].strip()
            continue
        path = line.strip()
        if not path or not date:
            continue
        if path not in first or date < first[path]:
            first[path] = date
    return first


def build_graph(pages, cache, history_lines):
    """-> {"nodes": [...], "edges": [...], "dates": [...]}.

    Every page of `pages` is a node — workspace, entity, initiative, person and document alike, a
    page with no link at all included (spec 061: shown loose, never hidden). `dates` is the sorted,
    deduplicated set of first-commit dates the graph actually has, the ticks of the "how it grew"
    slider.
    """
    first = _first_dates(history_lines)
    edges = set()
    for rel, page in pages.items():
        for other in _links(rel, page, cache, pages):
            if other in pages:
                edges.add(tuple(sorted((rel, other))))

    degree = {}
    for a, b in edges:
        degree[a] = degree.get(a, 0) + 1
        degree[b] = degree.get(b, 0) + 1

    nodes = []
    dates = set()
    for rel, page in pages.items():
        d = first.get(rel, "")
        if d:
            dates.add(d)
        nodes.append({
            "id": rel,
            "kind": page["kind"],
            "ws": page["ws"],
            "title": page["title"],
            "degree": degree.get(rel, 0),
            "first": d,
        })

    return {
        "nodes": nodes,
        "edges": [{"a": a, "b": b} for a, b in sorted(edges)],
        "dates": sorted(dates),
    }
