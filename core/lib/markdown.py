#!/usr/bin/env python3
"""The one Python reading of the brain's markdown. Internal: it is a library, never invoked.

`common.sh`'s `fm_read` is the bash reading of the same bounded format and stays the authority
whenever the two disagree on the shape. On the Python side there is exactly one reading, and it is
this file: `recall_index.py` (spec 050) and `my_wiki_build.py` (spec 060) both import from here
instead of carrying a parser of their own. A second Python parser of frontmatter or of headings is
the desync this module exists to prevent — spec 060 says so as a stopping condition.

What lives here is the format: splitting a file into its frontmatter, its entries and its `##`
sections, and turning a block of that markdown into HTML. What a section *means* — a list of tasks,
a list of decisions — is the caller's, because it is the caller's feature, not the format's.
"""

import re

# Same bound as `common.sh`: a frontmatter that does not close inside it is unreadable, and nothing
# is stripped, because nobody knows where a legitimate frontmatter would have closed.
CAP_FRONTMATTER = 30

DATE_RE = re.compile(r"^(\d{4}-\d{2}-\d{2})\b")
HEADING_RE = re.compile(r"^#{1,3}(\s|$)")
SECTION_RE = re.compile(r"^##(?!#)\s*(.*)$")
TASK_RE = re.compile(r"^\s*[-*]\s+\[([ xX])\]\s*(.*)$")
ITEM_RE = re.compile(r"^\s*[-*]\s+(?!\[[ xX]\])(.*)$")


def read_frontmatter(lines, keys=None):
    """lines: the file's raw lines, no trailing newline. -> (dict, body_start_index).

    `keys` limits which keys are kept; `None` keeps every key the block declares, which is what a
    view that prints the header a file happens to carry needs.
    """
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
        if keys is not None and key not in keys:
            continue
        if key and key not in fm:
            fm[key] = value
    return {}, 0


def split_entries(body_lines, body_start, fallback=""):
    """-> list of (line, header, text). The unit of `recall`'s index (spec 050).

    `fallback` is the header of a file with nothing readable in its body — a name the caller
    knows and this reader does not.

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
    entries.append((body_start + 1, header or fallback, text))
    return entries


def split_sections(body_lines):
    """-> (title, lede_lines, [(name, lines)]). The unit a page of the wiki is made of (spec 060).

    The title is the first `# ` line if there is one; the lede is everything between it and the
    first `##`; each `##` opens a section that runs to the next one. A file with no `##` at all
    comes out with an empty section list and its whole body as the lede — the page still reads.
    """
    title = ""
    sections = []
    lede = []
    current = None
    for line in body_lines:
        if not title and line.startswith("# ") and current is None:
            title = line[2:].strip()
            continue
        m = SECTION_RE.match(line)
        if m:
            current = (m.group(1).strip(), [])
            sections.append(current)
            continue
        if current is None:
            lede.append(line)
        else:
            current[1].append(line)
    return title, lede, [(name, lines) for name, lines in sections]


def strip_lines(lines):
    """The same block with its leading and trailing blank lines gone."""
    out = list(lines)
    while out and not out[0].strip():
        out.pop(0)
    while out and not out[-1].strip():
        out.pop()
    return out


def escape(text):
    return (text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                .replace('"', "&quot;"))


_CODE_RE = re.compile(r"`([^`]+)`")
_BOLD_RE = re.compile(r"\*\*([^*]+)\*\*")
_ITALIC_RE = re.compile(r"(?<![\*\w])\*([^*\n]+)\*(?!\*)")
_LINK_RE = re.compile(r"\[([^\]]+)\]\(([^)\s]+)\)")


def render_inline(text, link=None):
    """One line of markdown as HTML. `link(target) -> href or None` decides what a link points at:
    a caller that knows its own routing passes one, and a target it does not recognise is dropped
    to plain text rather than left as a dead href.

    A backtick span is a path first (spec 063 C5): `link()` is tried on its raw content, and it
    becomes `<a><code>` when that resolves. A span that is not a path — or resolves to nothing —
    stays plain `<code>`, never a dead link."""
    out = escape(text)

    def do_link(m):
        label, target = m.group(1), m.group(2)
        href = link(target) if link else None
        if not href:
            return label
        return '<a href="%s">%s</a>' % (escape(href), label)

    def do_code(m):
        content = m.group(1)
        href = link(content) if link else None
        if not href:
            return "<code>%s</code>" % content
        return '<a href="%s"><code>%s</code></a>' % (escape(href), content)

    out = _LINK_RE.sub(do_link, out)
    out = _CODE_RE.sub(do_code, out)
    out = _BOLD_RE.sub(r"<b>\1</b>", out)
    out = _ITALIC_RE.sub(r"<i>\1</i>", out)
    return out


def render(lines, link=None):
    """A block of markdown as HTML: paragraphs, `###` sub-headings, lists, quotes. Deliberately
    small — what the brain's prose actually uses. Anything it does not know comes out as a
    paragraph, never as raw markup."""
    html = []
    buf = []
    items = []

    def flush_para():
        if buf:
            html.append("<p>" + render_inline(" ".join(buf), link) + "</p>")
            del buf[:]

    def flush_items():
        if items:
            html.append("<ul>" + "".join(
                "<li>" + render_inline(i, link) + "</li>" for i in items) + "</ul>")
            del items[:]

    rows = []
    fence = []
    in_fence = False

    def flush_table():
        if rows:
            body = [r for r in rows if not all(set(c.strip()) <= set(":-") for c in r)]
            has_sep = len(body) < len(rows)
            out = ["<div class=\"tbl\"><table>"]
            if has_sep and body:
                out.append("<thead><tr>" + "".join("<th>" + render_inline(c.strip(), link) + "</th>" for c in body[0]) + "</tr></thead>")
                body = body[1:]
            out.append("<tbody>" + "".join(
                "<tr>" + "".join("<td>" + render_inline(c.strip(), link) + "</td>" for c in r) + "</tr>" for r in body) + "</tbody>")
            out.append("</table></div>")
            html.append("".join(out))
            del rows[:]

    for line in lines:
        stripped = line.strip()
        # Fenced code stays verbatim, never re-read as prose.
        if stripped.startswith("```"):
            if in_fence:
                html.append("<pre><code>" + "\n".join(fence).replace("&", "&amp;").replace("<", "&lt;") + "</code></pre>")
                del fence[:]
                in_fence = False
            else:
                flush_para(); flush_items(); flush_table()
                in_fence = True
            continue
        if in_fence:
            fence.append(line.rstrip("\n"))
            continue
        # A markdown table: rows that start and end with a pipe. The separator row marks the header.
        if stripped.startswith("|") and stripped.endswith("|") and stripped.count("|") >= 2:
            flush_para(); flush_items()
            cells = stripped[1:-1].split("|")
            rows.append(cells)
            continue
        elif rows:
            flush_table()
        if not stripped:
            flush_para()
            flush_items()
            continue
        if stripped.startswith("###"):
            flush_para()
            flush_items()
            html.append("<h3>" + render_inline(stripped.lstrip("#").strip(), link) + "</h3>")
            continue
        if stripped.startswith("> "):
            flush_para()
            flush_items()
            html.append("<p class=\"quote\">" + render_inline(stripped[2:], link) + "</p>")
            continue
        m = ITEM_RE.match(line)
        if m:
            flush_para()
            items.append(m.group(1))
            continue
        m = TASK_RE.match(line)
        if m:
            flush_para()
            items.append(m.group(2))
            continue
        # A non-blank line while a list is open continues its last item: the brain's prose wraps
        # its bullets at 100 columns, and reading a wrapped line as a new paragraph broke the list
        # in two around it.
        if items:
            items[-1] = items[-1] + " " + stripped
            continue
        buf.append(stripped)
    flush_para()
    flush_table()
    if in_fence and fence:
        html.append("<pre><code>" + "\n".join(fence).replace("&", "&amp;").replace("<", "&lt;") + "</code></pre>")
    flush_items()
    return "".join(html)


def plain(text):
    """The same text with its markdown markers gone: what a listing or a card shows, where there
    is no room to render anything."""
    text = _LINK_RE.sub(r"\1", text)
    text = _CODE_RE.sub(r"\1", text)
    text = _BOLD_RE.sub(r"\1", text)
    text = _ITALIC_RE.sub(r"\1", text)
    return text


def first_paragraph(lines):
    """The first paragraph of a block, as plain text: what a card or a listing shows."""
    buf = []
    for line in lines:
        stripped = line.strip()
        if not stripped:
            if buf:
                break
            continue
        if stripped.startswith("#") or stripped.startswith(">"):
            continue
        buf.append(stripped)
    return plain(" ".join(buf))
