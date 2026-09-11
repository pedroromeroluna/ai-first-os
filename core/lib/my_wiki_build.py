#!/usr/bin/env python3
"""My Wiki's builder (spec 060). Internal: `my-wiki.sh` is the invocable; this file has no
`command:` header and is never called on its own.

Called as: my_wiki_build.py BRAIN WSDIR HEAD_FILE VAULT TEMPLATE OUT GENERATED VERSION

Reads its input on stdin, in blocks opened by a sentinel line. Everything that needs a reader the
product already owns is read on the bash side and handed over here: the tree (`os_tree_globs`,
`os_tree_files`, `os_tree_content_files`), the mount table (`os_mounts_filas`), the runtime prose
(`os_lang_load`) and git. There is no second parser of any of those formats in this file.

  %%STRINGS%%   KEY<TAB>text
  %%GLOBS%%     one `glob:` pattern per line, unexpanded
  %%HEADS%%     one path per line — what the `glob:` class reaches
  %%FILES%%     one path per line — what the `content:` class reaches
  %%MOUNTS%%    remote<TAB>local path<TAB>last merge date
  %%OVERVIEW%%  key<TAB>value — the options of the first screen (spec 062)
  %%GATES%%     gate<TAB>repo<TAB>spec<TAB>title<TAB>date<TAB>branch, already resolved by git

NOTHING OF THE MACHINERY REACHES THE PAGE (spec 060 C3). The filter is `MACHINERY`, below, and it
runs before anything is read: a file it names is never opened, so its content cannot leak into the
payload by way of a section, a search body or a listing.

NO ENTITY TYPE IS WRITTEN IN THIS FILE (C1). The shelves of a workspace are derived from the
`glob:` patterns of the brain's own tree: a pattern of the shape `<wsdir>/*/<type>/*` declares a
type, and its name is the shelf's name. `initiatives` and `people` are the two names this file
does know, and it knows them as *layouts* the view has — a stretch with a state, a directory of
people — never as a list of what a brain may contain.
"""

import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import markdown as md  # noqa: E402
import my_wiki_graph as mwg  # noqa: E402 — the Graph screen's data, built once below (spec 061)
import my_wiki_overview  # noqa: E402

BRAIN, WSDIR, HEAD_FILE, VAULT, TEMPLATE, OUT, GENERATED, VERSION = sys.argv[1:9]

# The machinery, by basename and by path segment. A file this names is never opened.
MACHINERY_FILES = (
    "resolver.md", "tree.md", "operator.md", "mounts.md", "inbox.md",
    "voice.md", "CLAUDE.md", "AGENTS.md", "skills-lock.md", "skills-lock.json",
)
MACHINERY_DIRS = ("roles", "voice", ".os", ".claude", ".git", "skills")

# A section's name decides its icon, and a name with no entry gets the generic one. The map is the
# only place a section name appears, and no name here is required to exist in any brain.
# One rule for every icon in the page: a section heading, a document group, a shelf. The name
# is normalized —lowercase, no accents, no trailing "s"— and looked up here; anything unknown gets
# the generic dot. The page reads this same table from `data.json` (`icons`), so the two never
# drift.
SECTION_ICONS = {
    "task": "check", "tarea": "check", "backlog": "check", "pendiente": "check",
    "decision": "gavel", "decisione": "gavel",
    "learning": "bulb", "aprendizaje": "bulb",
    "stakeholder": "people", "people": "people", "persona": "people", "equipo": "people", "team": "people",
    "open question": "question", "pregunta abierta": "question", "abierto": "question", "dudas": "question",
    "development": "code", "desarrollo": "code", "spec": "code",
    "research": "search", "investigacion": "search",
    "context": "compass", "contexto": "compass", "strategy": "compass", "estrategia": "compass",
    "initiative": "flag", "iniciativa": "flag",
    "document": "doc", "documento": "doc", "material": "book", "piece": "doc", "pieza": "doc",
    "resumen": "doc", "summary": "doc", "registro": "doc",
    "mention": "link", "mencione": "link", "mencion": "link",
}
DEFAULT_ICON = "dot"


def section_icon(name):
    """The icon of a section or a document group by its name, under one normalization: lowercase,
    accents stripped, a final "s" dropped. "Investigación", "Research" and "researchs" all land on
    the same key."""
    import unicodedata
    n = unicodedata.normalize("NFD", (name or "").strip().lower())
    n = "".join(c for c in n if unicodedata.category(c) != "Mn")
    n = re.sub(r"[\s_-]+", " ", n).strip()
    # A heading that qualifies itself —"Open — closed by the operator", "Decisions (2026)"— is looked
    # up by its head: what comes before the dash, the colon or the parenthesis; then by its first word.
    candidates = [n, re.split(r"\s+[—–-]\s+|:|\(", n)[0].strip(), n.split(" ")[0]]
    for c in candidates:
        for k in (c, c[:-1] if c.endswith("s") else c):
            if k in SECTION_ICONS:
                return SECTION_ICONS[k]
    return DEFAULT_ICON

DATE_LED = re.compile(r"^\s*(\d{4}-\d{2}-\d{2})\b[\s·:—-]*(.*)$")
PEOPLE_LINK = re.compile(r"people/[^\s)\]]+")


# ------------------------------------------------------------------ the input, block by block
def read_blocks():
    blocks, current = {}, None
    for line in sys.stdin.read().split("\n"):
        if line.startswith("%%") and line.endswith("%%"):
            current = line.strip("%")
            blocks[current] = []
            continue
        if current is not None:
            blocks[current].append(line)
    return blocks


BLOCKS = read_blocks()


def block(name):
    return [l for l in BLOCKS.get(name, []) if l != ""]


STRINGS = {}
for line in block("STRINGS"):
    k, _, v = line.partition("\t")
    STRINGS[k] = v


def T(key, fallback=""):
    return STRINGS.get(key, fallback or key)


# ------------------------------------------------------------------ what is machinery, what is not
def is_machinery(rel):
    parts = rel.split("/")
    if parts[-1] in MACHINERY_FILES:
        return True
    for p in parts[:-1]:
        if p in MACHINERY_DIRS:
            return True
    return False


def in_workspaces(rel):
    return rel.startswith(WSDIR + "/")


HEADS = [p for p in block("HEADS") if in_workspaces(p) and not is_machinery(p)]
CONTENT = [p for p in block("FILES") if in_workspaces(p) and not is_machinery(p)]
ALL_FILES = sorted(set(HEADS) | set(CONTENT))


# ------------------------------------------------------------------ the shelves come from the tree
def entity_types():
    """The types the brain's own tree declares under a workspace, in the order they are declared.

    A pattern of the shape `<wsdir>/*/<type>/*...` declares `<type>`. `initiatives` and `people`
    are layouts of the view, not shelves, so they come out of the list — everything else is a
    shelf, whatever it is called.
    """
    types = []
    prefix = WSDIR + "/*/"
    for g in block("GLOBS"):
        if not g.startswith(prefix):
            continue
        rest = g[len(prefix):].split("/")
        if len(rest) < 2 or rest[0] == "*":
            continue
        t = rest[0]
        if t in ("initiatives", "people"):
            continue
        if t not in types:
            types.append(t)
    return types


TYPES = entity_types()


def shelf_label(t):
    return t.replace("-", " ").replace("_", " ").strip().capitalize()


# ------------------------------------------------------------------ reading a file
CACHE = {}


def read(rel):
    if rel in CACHE:
        return CACHE[rel]
    try:
        with open(os.path.join(BRAIN, rel), "r", encoding="utf-8", errors="replace") as f:
            raw = f.read()
    except OSError:
        raw = ""
    lines = raw.split("\n")
    if lines and lines[-1] == "":
        lines = lines[:-1]
    fm, start = md.read_frontmatter(lines)
    title, lede, sections = md.split_sections(lines[start:])
    CACHE[rel] = (fm, title, md.strip_lines(lede), sections)
    return CACHE[rel]


def slug_title(rel):
    base = os.path.basename(rel)
    if base == HEAD_FILE:
        base = os.path.basename(os.path.dirname(rel))
    else:
        base = os.path.splitext(base)[0]
    return base.replace("-", " ").replace("_", " ").strip().capitalize()


def link_target(target, ws):
    """A markdown link that names something the wiki has a page for becomes a link to that page;
    anything else keeps its href if it is a URL and is dropped to plain text if it is not."""
    if target.startswith("http://") or target.startswith("https://") or target.startswith("mailto:"):
        return target
    clean = target.split("#")[0].lstrip("./")
    if clean in PAGES:
        return "#/" + clean
    return None


# ------------------------------------------------------------------ the shape of a section (C4)
def classify(lines):
    lines = md.strip_lines(lines)
    tasks, items = [], []
    for l in lines:
        m = md.TASK_RE.match(l)
        if m:
            tasks.append((m.group(1).lower() == "x", m.group(2).strip()))
            continue
        m = md.ITEM_RE.match(l)
        if m:
            items.append(m.group(1).strip())
    if tasks:
        out = []
        for done, text in tasks:
            m = DATE_LED.match(text)
            date = ""
            rest = text
            if m:
                date, rest = m.group(1), m.group(2) or text
            else:
                m2 = re.search(r"\((?:since|due|desde|vence)[: ]\s*(\d{4}-\d{2}-\d{2})\)", text)
                if m2:
                    date = m2.group(1)
            out.append({"done": done, "text": rest, "date": date})
        return "tasks", out
    if items and any(PEOPLE_LINK.search(i) for i in items):
        out = []
        for i in items:
            m = PEOPLE_LINK.search(i)
            path = m.group(0) if m else ""
            out.append({"text": i, "person": path})
        return "people", out
    dated = [DATE_LED.match(i) for i in items]
    if items and sum(1 for d in dated if d) * 2 >= len(items):
        out = []
        for i, d in zip(items, dated):
            if d:
                out.append({"date": d.group(1), "text": d.group(2) or i})
            else:
                out.append({"date": "", "text": i})
        return "decisions", out
    return "prose", lines


# ------------------------------------------------------------------ Development, from the repo (C5)
MOUNTS = {}
for line in block("MOUNTS"):
    parts = line.split("\t")
    if len(parts) >= 3:
        MOUNTS[parts[0]] = {"local": parts[1], "merge": parts[2]}

SPEC_STATUS = re.compile(r"^(?:status|estado):\s*(.+)$")


def development(remote):
    """The `Development` block of a node with a `repo:`. Read by the local path the mount table
    declares for that remote; with no row for it, the block says the repo is not mounted and
    nothing fails."""
    row = MOUNTS.get(remote)
    short = remote.rstrip("/")
    if short.endswith(".git"):
        short = short[:-4]
    short = "/".join(short.split("/")[-2:])
    if not row or not row["local"] or not os.path.isdir(row["local"]):
        return {"repo": short, "mounted": False, "specs": [], "merge": ""}
    counts = {}
    for sub in ("specs", os.path.join("specs", "done")):
        d = os.path.join(row["local"], sub)
        if not os.path.isdir(d):
            continue
        for name in sorted(os.listdir(d)):
            if not name.endswith(".md"):
                continue
            try:
                with open(os.path.join(d, name), encoding="utf-8", errors="replace") as f:
                    head = f.read(2000).split("\n")
            except OSError:
                continue
            fm, _ = md.read_frontmatter(head)
            st = fm.get("status") or fm.get("estado") or ""
            if not st:
                continue
            counts[st] = counts.get(st, 0) + 1
    specs = [{"status": k, "count": v} for k, v in sorted(counts.items())]
    return {"repo": short, "mounted": True, "specs": specs, "merge": row["merge"]}


# ------------------------------------------------------------------ the pages
PAGES = {}
WORKSPACES = []


def node_dir(rel):
    return os.path.dirname(rel) if os.path.basename(rel) == HEAD_FILE else os.path.splitext(rel)[0]


def is_person(rel):
    return "/people/" in "/" + rel


def build_page(rel, kind, ws, ptype=""):
    fm, title, lede, sections = read(rel)
    page = {
        "path": rel,
        "kind": kind,
        "ws": ws,
        "type": ptype,
        "typeLabel": shelf_label(ptype) if ptype else "",
        "title": title or slug_title(rel),
        "fm": fm,
        "lede": [],
        "sections": [],
        "docs": [],
        "children": [],
        "mentions": [],
        "dev": None,
        "raw": {"lede": lede, "sections": sections},
    }
    PAGES[rel] = page
    return page


def render_page(page):
    """Second pass: what needs every page to exist before it can be written — the links."""
    ws = page["ws"]
    raw = page.pop("raw")

    def link(t):
        return link_target(t, ws)

    page["lede"] = md.render(raw["lede"], link)
    page["summary"] = md.first_paragraph(raw["lede"])[:400]
    out = []
    for name, lines in raw["sections"]:
        form, payload = classify(lines)
        section = {
            "name": name,
            "icon": section_icon(name),
            "form": form,
        }
        if form == "prose":
            section["html"] = md.render(payload, link)
            section["text"] = " ".join(l.strip() for l in payload if l.strip())
        else:
            section["items"] = payload
            section["text"] = " ".join(i.get("text", "") for i in payload)
        out.append(section)
    page["sections"] = out
    if page["fm"].get("repo"):
        page["dev"] = development(page["fm"]["repo"])


# --- the workspaces, their shelves and their initiatives
ws_slugs = []
for h in HEADS:
    parts = h.split("/")
    if len(parts) == 3 and parts[0] == WSDIR and parts[2] == HEAD_FILE:
        if parts[1] not in ws_slugs:
            ws_slugs.append(parts[1])

for slug in sorted(ws_slugs):
    ws_home = "%s/%s/%s" % (WSDIR, slug, HEAD_FILE)
    home = build_page(ws_home, "workspace", slug)
    ws = {
        "slug": slug,
        "title": home["title"],
        "home": ws_home,
        "shelves": [],
        "orphans": [],
        "people": [],
    }
    WORKSPACES.append(ws)

    prefix = "%s/%s/" % (WSDIR, slug)
    ws_heads = [h for h in HEADS if h.startswith(prefix) and h != ws_home]

    # entities, by the types the tree declares
    by_type = {}
    for t in TYPES:
        tp = prefix + t + "/"
        for h in ws_heads:
            if not h.startswith(tp):
                continue
            rest = h[len(tp):]
            if rest.count("/") > 1:
                continue
            build_page(h, "entity", slug, t)
            by_type.setdefault(t, []).append(h)
    for t in TYPES:
        if t in by_type:
            ws["shelves"].append({
                "type": t, "label": shelf_label(t), "icon": section_icon(t), "pages": sorted(by_type[t]),
            })

    # initiatives: the one type with a fixed meaning
    ip = prefix + "initiatives/"
    for h in ws_heads:
        if h.startswith(ip) and h[len(ip):].count("/") <= 1:
            build_page(h, "initiative", slug, "initiatives")

# --- people and documents: everything the content class reaches, attached to its node
NODE_OF = {}
for rel, page in PAGES.items():
    NODE_OF[node_dir(rel)] = rel

for rel in ALL_FILES:
    if rel in PAGES:
        continue
    ws = rel.split("/")[1] if rel.startswith(WSDIR + "/") else ""
    if is_person(rel):
        page = build_page(rel, "person", ws)
        continue
    d = os.path.dirname(rel)
    owner = None
    while d and "/" in d:
        if d in NODE_OF:
            owner = NODE_OF[d]
            break
        d = os.path.dirname(d)
    page = build_page(rel, "document", ws)
    page["owner"] = owner
    if owner:
        # The folder a document lives in is what says what it is —`decisions/`, `research/`— and
        # the view groups by it. One sitting directly in the node's own folder belongs to no such
        # group: it comes out under the generic heading instead of under the node's own name.
        holder = os.path.dirname(rel)
        group = "" if holder == node_dir(owner) else os.path.basename(holder)
        PAGES[owner]["docs"].append({"path": rel, "group": group})

for ws in WORKSPACES:
    ws["people"] = sorted(p for p, v in PAGES.items()
                          if v["kind"] == "person" and v["ws"] == ws["slug"])

# --- an initiative hangs from the entity its `about:` names (C2)
for rel, page in PAGES.items():
    if page["kind"] != "initiative":
        continue
    about = page["fm"].get("about", "").strip().strip("`")
    parent = about if about in PAGES and PAGES[about]["kind"] == "entity" else ""
    page["about"] = parent
    if parent:
        PAGES[parent]["children"].append(rel)
    else:
        for ws in WORKSPACES:
            if ws["slug"] == page["ws"]:
                ws["orphans"].append(rel)

for rel, page in PAGES.items():
    page["children"].sort()
for ws in WORKSPACES:
    ws["orphans"].sort()

# --- render every page now that every page exists
for page in list(PAGES.values()):
    render_page(page)

# --- a person's relations and mentions (C6)
for rel, page in PAGES.items():
    if page["kind"] != "person":
        continue
    name = page["title"]
    tail = rel.split("/people/")[-1]
    for other, op in PAGES.items():
        if other == rel or op["kind"] == "person":
            continue
        hit = False
        blob = op.get("summary", "")
        if rel in blob or tail in blob or (name and len(name) > 3 and name in blob):
            hit = True
        for s in op["sections"]:
            if rel in s.get("text", "") or tail in s.get("text", ""):
                hit = True
            if s["form"] == "people":
                for it in s["items"]:
                    if it["person"] and (it["person"] in rel or rel.endswith(it["person"])):
                        hit = True
            if not hit and name and len(name) > 3 and name in s.get("text", ""):
                hit = True
        if hit:
            page["mentions"].append({
                "path": other, "kind": op["kind"], "title": op["title"],
                "ws": op["ws"],
            })
    page["mentions"].sort(key=lambda m: (m["kind"], m["path"]))

# ------------------------------------------------------------------ the payload and the page
# `owner` stays on a document page (spec 063 C4): the sidebar walks it to find which entity to
# expand when a document is the one that is open. Every other kind never had the key at all.
# ------------------------------------------------------------------ Overview, the first screen (spec 062)
# It replaces *What changed*, which the 062 removed from the menu and from this payload: a list of
# commits is history, and the first screen is what is waiting for a person.
OPTIONS = {}
for line in block("OVERVIEW"):
    k, _, v = line.partition("\t")
    OPTIONS[k] = v

OVERVIEW = my_wiki_overview.build(PAGES, WORKSPACES, WSDIR, HEAD_FILE, OPTIONS, block("GATES"))

for page in PAGES.values():
    page.pop("owner", None)

data = {
    "generated": GENERATED,
    "vault": VAULT,
    "version": VERSION,
    "strings": STRINGS,
    "icons": SECTION_ICONS,
    "workspaces": WORKSPACES,
    "pages": PAGES,
    "graph": mwg.build_graph(PAGES, CACHE, block("HISTORY")),
    "overview": OVERVIEW,
}

payload = json.dumps(data, ensure_ascii=False, separators=(",", ":"))
payload = payload.replace("</", "<\\/")

with open(TEMPLATE, encoding="utf-8") as f:
    html = f.read()
html = html.replace("{{DATA}}", payload)
# The first screen's view travels beside the shell, from its own file: the 062 adds its code
# without a second copy of the template (spec 062).
with open(os.path.join(os.path.dirname(TEMPLATE), "my-wiki-overview.js"), encoding="utf-8") as f:
    html = html.replace("{{OVERVIEW_JS}}", f.read())
html = html.replace("{{TITLE}}", md.escape(T("WIKI_TITLE", "My Wiki")))
with open(os.path.join(os.path.dirname(TEMPLATE), "my-wiki-graph.js"), encoding="utf-8") as f:
    html = html.replace("{{GRAPH_JS}}", "<script id=\"wiki-graph\">\n" + f.read() + "\n</script>")

with open(OUT, "w", encoding="utf-8") as f:
    f.write(html)

size = os.path.getsize(OUT)
print("%s\t%d\t%d\t%d" % (OUT, size, len(PAGES), len(WORKSPACES)))
