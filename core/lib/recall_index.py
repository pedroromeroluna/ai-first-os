#!/usr/bin/env python3
"""Living Memory's indexer and query engine (spec 050). Internal: `recall.sh` is the invocable;
this file has no `command:` header and is never called on its own.

Called as: recall_index.py DB BRAIN MODE SCOPE_KIND WSDIR SCOPE_SLUG ARG LIMIT

Reads the file list on stdin, two blocks separated by the sentinel line `%%FILES%%`: the node
heads first (the subset of the `glob:` class whose basename is the brain's head file — computed in
bash from `os_tree_files`/`os_head_file`, no second parser of `tree.md` here), then every file to
index (the union of the `glob:` and `content:` classes).

SECOND READING OF THE FRONTMATTER FORMAT. `common.sh`'s `fm_read` (lines 289-345 there) is the one
reader of `tree.md`-reached frontmatter the rest of the product uses; this is a second reading of
the same bounded format, for the six keys this feature needs. Whenever the two disagree on the
shape, `common.sh` is the authority, never this file.
"""

import hashlib
import os
import re
import sqlite3
import sys

db_path, brain, mode, scope_kind, wsdir, scope_slug, arg, limit = sys.argv[1:9]
limit = int(limit)
CAP_FRONTMATTER = 30
FM_KEYS = ("updated", "fecha", "date", "status", "about", "superseded_by")
DATE_RE = re.compile(r"^(\d{4}-\d{2}-\d{2})\b")
HEADING_RE = re.compile(r"^#{1,3}(\s|$)")


def read_frontmatter(lines):
    """lines: the file's raw lines, no trailing newline. -> (dict, body_start_index)."""
    if not lines or lines[0].strip() != "---":
        return {}, 0
    fm = {}
    for i in range(1, min(len(lines), CAP_FRONTMATTER)):
        line = lines[i]
        if line.strip() == "---":
            return fm, i + 1
        if ":" not in line:
            continue
        key, _, value = line.partition(":")
        key = key.strip()
        value = value.strip()
        if key in FM_KEYS and key not in fm:
            fm[key] = value
    # Unclosed, or past the bound: unreadable, same as `common.sh` — nothing is stripped, because
    # nobody knows where a legitimate frontmatter would have closed.
    return {}, 0


def file_status(fm):
    if fm.get("superseded_by"):
        return "superseded"
    if fm.get("status") == "superseded":
        return "superseded"
    return "current"


def mtime_date(path):
    try:
        t = os.path.getmtime(path)
    except OSError:
        return ""
    import datetime
    return datetime.date.fromtimestamp(t).isoformat()


def entry_date(header_text, fm, path):
    m = DATE_RE.match(header_text.strip())
    if m:
        return m.group(1)
    for k in ("updated", "fecha", "date"):
        v = fm.get(k, "").strip()
        if v:
            return v
    return mtime_date(path)


def split_entries(body_lines, body_start, fm, path):
    """-> list of (line, header, text).

    Heading beats item: a section under a heading that is itself a flat list —`# Backlog` followed
    by nothing but `- ` items, no sub-heading in between— still comes out one entry per item, not
    one entry for the whole section. What decides is the section's own body once its heading line
    is set aside: no item line there means the section reads as prose (`decisions.md`) and stays one
    entry; at least one does means the section is `backlog.md`/`inbox.md`-shaped.
    """
    n = len(body_lines)
    heading_idx = [i for i, l in enumerate(body_lines) if HEADING_RE.match(l)]
    entries = []
    if heading_idx:
        for j, start in enumerate(heading_idx):
            end = heading_idx[j + 1] if j + 1 < len(heading_idx) else n
            chunk = body_lines[start:end]
            sub_item_idx = [k for k, l in enumerate(chunk) if k > 0 and l.startswith("- ")]
            if sub_item_idx:
                for jj, s2 in enumerate(sub_item_idx):
                    e2 = sub_item_idx[jj + 1] if jj + 1 < len(sub_item_idx) else len(chunk)
                    item_chunk = chunk[s2:e2]
                    header = item_chunk[0][2:].strip()
                    text = "\n".join(item_chunk)
                    entries.append((body_start + start + s2 + 1, header, text))
                continue
            header = chunk[0].lstrip("#").strip()
            text = "\n".join(chunk)
            entries.append((body_start + start + 1, header, text))
        return entries
    item_idx = [i for i, l in enumerate(body_lines) if l.startswith("- ")]
    if item_idx:
        for j, start in enumerate(item_idx):
            end = item_idx[j + 1] if j + 1 < len(item_idx) else n
            chunk = body_lines[start:end]
            header = chunk[0][2:].strip()
            text = "\n".join(chunk)
            entries.append((body_start + start + 1, header, text))
        return entries
    header = ""
    for l in body_lines:
        if l.strip():
            header = l.strip().lstrip("#").strip()
            break
    text = "\n".join(body_lines)
    entries.append((body_start + 1, header or os.path.basename(path), text))
    return entries


def parse_file(abspath, relpath):
    try:
        with open(abspath, "r", encoding="utf-8", errors="replace") as f:
            raw = f.read()
    except OSError:
        return {}, [], ""
    lines = raw.split("\n")
    if lines and lines[-1] == "":
        lines = lines[:-1]
    fm, body_start = read_frontmatter(lines)
    body_lines = lines[body_start:]
    entries = split_entries(body_lines, body_start, fm, relpath)
    status = file_status(fm)
    superseded_by = fm.get("superseded_by", "") if status == "superseded" else ""
    out_entries = []
    for line, header, text in entries:
        date = entry_date(header, fm, abspath)
        out_entries.append((line, header, text, date))
    title = out_entries[0][1] if out_entries else os.path.splitext(os.path.basename(relpath))[0]
    return fm, out_entries, status, superseded_by, title


def connect(path):
    conn = sqlite3.connect(path)
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute(
        "CREATE TABLE IF NOT EXISTS files ("
        " path TEXT PRIMARY KEY, size INTEGER, mtime REAL, hash TEXT,"
        " node TEXT, title TEXT, status TEXT, superseded_by TEXT, about TEXT)"
    )
    conn.execute(
        "CREATE VIRTUAL TABLE IF NOT EXISTS entries USING fts5("
        " header, body, path UNINDEXED, line UNINDEXED, date UNINDEXED,"
        " node UNINDEXED, status UNINDEXED, superseded_by UNINDEXED,"
        " tokenize='unicode61 remove_diacritics 2')"
    )
    conn.execute(
        "CREATE TABLE IF NOT EXISTS relations (src TEXT, rel TEXT, dst TEXT)"
    )
    conn.execute("CREATE INDEX IF NOT EXISTS relations_src ON relations(src)")
    conn.execute("CREATE INDEX IF NOT EXISTS relations_dst ON relations(dst)")
    return conn


def node_of(relpath, true_heads_dirs):
    d = os.path.dirname(relpath)
    best = None
    for hd in true_heads_dirs:
        if d == hd or d.startswith(hd + "/"):
            if best is None or len(hd) > len(best):
                best = hd
    return true_heads_dirs.get(best, "") if best is not None else ""


def reconcile(conn, brain, all_files, true_heads):
    true_heads_dirs = {}
    for h in true_heads:
        true_heads_dirs[os.path.dirname(h)] = h

    stored = {}
    for row in conn.execute("SELECT path, size, mtime, hash FROM files"):
        stored[row[0]] = (row[1], row[2], row[3])

    current_set = set(all_files)
    to_delete = [p for p in stored if p not in current_set]

    to_reindex = []
    to_touch = []  # (path, size, mtime) -- hash unchanged, only refresh stat
    to_insert = []  # new files

    for rel in all_files:
        abspath = os.path.join(brain, rel)
        try:
            st = os.stat(abspath)
        except OSError:
            to_delete.append(rel)
            continue
        size, mtime = st.st_size, st.st_mtime
        prev = stored.get(rel)
        if prev is not None and prev[0] == size and prev[1] == mtime:
            continue  # first filter: unchanged size and mtime, skip entirely
        h = hashlib.sha256()
        try:
            with open(abspath, "rb") as f:
                h.update(f.read())
        except OSError:
            to_delete.append(rel)
            continue
        digest = h.hexdigest()
        if prev is not None and prev[2] == digest:
            to_touch.append((rel, size, mtime))
            continue
        if prev is None:
            to_insert.append((rel, size, mtime, digest))
        else:
            to_reindex.append((rel, size, mtime, digest))

    cur = conn.cursor()
    for p in to_delete:
        cur.execute("DELETE FROM files WHERE path=?", (p,))
        cur.execute("DELETE FROM entries WHERE path=?", (p,))
        cur.execute("DELETE FROM relations WHERE src=? OR dst=?", (p, p))

    for rel, size, mtime in to_touch:
        cur.execute("UPDATE files SET size=?, mtime=? WHERE path=?", (size, mtime, rel))

    for rel, size, mtime, digest in to_reindex + to_insert:
        abspath = os.path.join(brain, rel)
        fm, out_entries, status, superseded_by, title = parse_file(abspath, rel)
        node = node_of(rel, true_heads_dirs)
        about = fm.get("about", "")
        cur.execute("DELETE FROM entries WHERE path=?", (rel,))
        cur.execute("DELETE FROM relations WHERE src=?", (rel,))
        cur.execute(
            "INSERT OR REPLACE INTO files"
            " (path, size, mtime, hash, node, title, status, superseded_by, about)"
            " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (rel, size, mtime, digest, node, title, status, superseded_by, about),
        )
        if about:
            cur.execute("INSERT INTO relations (src, rel, dst) VALUES (?, 'about', ?)", (rel, about))
        if superseded_by:
            cur.execute(
                "INSERT INTO relations (src, rel, dst) VALUES (?, 'superseded_by', ?)",
                (rel, superseded_by),
            )
        for line, header, text, date in out_entries:
            cur.execute(
                "INSERT INTO entries"
                " (header, body, path, line, date, node, status, superseded_by)"
                " VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                (header, text, rel, line, date, node, status, superseded_by),
            )
    conn.commit()


def fts_query(q):
    tokens = q.split()
    if not tokens:
        return '""'
    return " ".join('"' + t.replace('"', '""') + '"' for t in tokens)


def fragment(text, limit=200):
    text = " ".join(text.split())
    if len(text) > limit:
        text = text[: limit - 1].rstrip() + "…"
    return text


def scope_filter(scope_kind, wsdir, scope_slug):
    if scope_kind == "all":
        return "1=1", ()
    if scope_kind == "root":
        return "path NOT LIKE ?", (wsdir + "/%",)
    if scope_kind == "workspace":
        return "path LIKE ?", (wsdir + "/" + scope_slug + "/%",)
    return "1=1", ()


def run_search():
    conn = connect(db_path)
    reconcile(conn, brain, all_files, true_heads)
    n_files = conn.execute("SELECT COUNT(*) FROM files").fetchone()[0]

    clause, params = scope_filter(scope_kind, wsdir, scope_slug)
    match = fts_query(arg)
    sql = (
        "SELECT path, line, date, status, superseded_by, header,"
        " snippet(entries, -1, '', '', '...', 20) AS frag"
        " FROM entries WHERE entries MATCH ? AND " + clause +
        " ORDER BY (status='superseded') ASC, bm25(entries, 10.0, 1.0) ASC"
        " LIMIT ?"
    )
    rows = conn.execute(sql, (match,) + params + (limit,)).fetchall()

    hits = len(rows)
    print("scope: %s · %d hits · %d files indexed" % (
        scope_slug if scope_kind == "workspace" else scope_kind, hits, n_files))
    if hits == 0:
        print("__NO_RESULTS__")
        return
    for path, line, date, status, superseded_by, header, frag in rows:
        estado = "current" if status != "superseded" else ("superseded → " + superseded_by)
        print("%s:%s · %s · %s · %s · %s" % (
            path, line, date, estado, header, fragment(frag)))


def title_of(conn, path):
    row = conn.execute("SELECT title FROM files WHERE path=?", (path,)).fetchone()
    if row:
        return row[0]
    return os.path.splitext(os.path.basename(path))[0]


def run_expand():
    conn = connect(db_path)
    reconcile(conn, brain, all_files, true_heads)

    lines = []
    row = conn.execute("SELECT about FROM files WHERE path=?", (arg,)).fetchone()
    if row and row[0]:
        dst = row[0]
        lines.append("about · %s · %s" % (dst, title_of(conn, dst)))
    for (src,) in conn.execute(
        "SELECT src FROM relations WHERE rel='about' AND dst=?", (arg,)
    ):
        lines.append("about-by · %s · %s" % (src, title_of(conn, src)))
    row = conn.execute("SELECT superseded_by FROM files WHERE path=?", (arg,)).fetchone()
    if row and row[0]:
        dst = row[0]
        lines.append("superseded-by · %s · %s" % (dst, title_of(conn, dst)))
    for (src,) in conn.execute(
        "SELECT src FROM relations WHERE rel='superseded_by' AND dst=?", (arg,)
    ):
        lines.append("supersedes · %s · %s" % (src, title_of(conn, src)))
    for l in lines:
        print(l)


data = sys.stdin.read().split("\n")
true_heads = []
all_files = []
target = true_heads
for l in data:
    if l == "%%FILES%%":
        target = all_files
        continue
    if l:
        target.append(l)

if mode == "expand":
    run_expand()
else:
    run_search()

