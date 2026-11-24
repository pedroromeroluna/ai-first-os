#!/usr/bin/env python3
"""Tools behind capabilities/. Called by the thin bash wrappers in scripts/.

  capability_tools.py apply SPEC [--root DIR]        apply a spec's "## Capability changes"
  capability_tools.py check-evals OUTPUT [--root DIR]  every requirement has Evals: ids with a PASS line
  capability_tools.py check-diagrams [--root DIR]    diagram form + the general diagram names every capability
  capability_tools.py blocks [--root DIR]            print every mermaid block as FILE<TAB>INDEX<TAB>path (see render-mermaid.sh)

Exit codes: 0 ok / nothing to do · 1 stopped (prints capability, requirement and rule) · 2 misused.
The format lives in capabilities/README.md and nowhere else.
"""
import os
import re
import sys

DIAGRAM_TYPES = ("flowchart", "graph", "stateDiagram-v2", "sequenceDiagram")
EVAL_ID = re.compile(r"S\d{3}-[A-Za-z0-9]+")
SLUG = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
KINDS = ("DIAGRAM", "RENAMED", "REMOVED", "MODIFIED", "ADDED")


class Stop(Exception):
    def __init__(self, cap, req, rule, msg):
        super().__init__(msg)
        self.cap, self.req, self.rule, self.msg = cap, req, rule, msg

    def __str__(self):
        return "capability: %s · requirement: %s · rule %s: %s" % (self.cap, self.req or "-", self.rule, self.msg)


# ---------------------------------------------------------------- text helpers

FENCE = re.compile(r"^ {0,3}(`{3,}|~{3,})(.*)$")
FENCE_END = re.compile(r"^ {0,3}(`{3,}|~{3,})[ \t]*$")


def fence_open(line):
    """CommonMark opening fence: up to 3 spaces of indent, 3+ backticks or tildes. -> (char, length, info) or None."""
    m = FENCE.match(line)
    if not m:
        return None
    f, info = m.group(1), m.group(2)
    if f[0] == "`" and "`" in info:
        return None
    return (f[0], len(f), info.strip())


def fence_close(line, st):
    """Closes a fence opened as st: same character, at least the same length, up to 3 spaces of indent."""
    m = FENCE_END.match(line)
    return bool(m) and m.group(1)[0] == st[0] and len(m.group(1)) >= st[1]


def outside_fence(lines):
    """Yield (index, line, inside) for each line; inside is True for lines in or on a fence."""
    st = None
    for i, line in enumerate(lines):
        if st:
            yield i, line, True
            if fence_close(line, st):
                st = None
        else:
            st = fence_open(line)
            yield i, line, bool(st)


def scan_mermaid(lines):
    """-> (blocks, suspects). blocks: (open_idx, close_idx or None, body). suspects: messages for fences whose
    info string mentions mermaid without being exactly 'mermaid' (never skipped silently)."""
    blocks, suspects = [], []
    st = None
    cur = None
    for i, l in enumerate(lines):
        if st:
            if fence_close(l, st):
                if cur is not None:
                    blocks.append((cur[0], i, cur[1]))
                st, cur = None, None
            elif cur is not None:
                cur[1].append(l)
        else:
            st = fence_open(l)
            if st:
                word = st[2].split()[0] if st[2].split() else ""
                if word == "mermaid":
                    cur = [i, []]
                elif "mermaid" in st[2].lower():
                    suspects.append("line %d: fence info '%s' looks like mermaid but is not exactly 'mermaid'" % (i + 1, st[2]))
    if st and cur is not None:
        blocks.append((cur[0], None, cur[1]))
    return blocks, suspects


def norm(lines):
    out = [l.rstrip() for l in lines]
    while out and not out[0]:
        out.pop(0)
    while out and not out[-1]:
        out.pop()
    return out


def read_lines(path):
    with open(path, encoding="utf-8") as f:
        return f.read().split("\n")


def find_root(args):
    root = None
    rest = []
    it = iter(args)
    for a in it:
        if a == "--root":
            root = next(it, None)
            if root is None:
                print("--root needs a value", file=sys.stderr)
                sys.exit(2)
        else:
            rest.append(a)
    if root is None:
        root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    return os.path.abspath(root), rest


# ---------------------------------------------------------------- the capability file

class Cap:
    """A capabilities/<slug>.md: header (title, diagram, purpose), requirements, tail."""

    def __init__(self, slug, lines):
        self.slug = slug
        idx = None
        for i, l, inside in outside_fence(lines):
            if not inside and l.strip() == "## Requirements":
                idx = i
                break
        if idx is None:
            raise Stop(slug, None, "file", "capabilities/%s.md has no '## Requirements' section" % slug)
        self.header = lines[: idx + 1]
        body = lines[idx + 1:]
        self.reqs = []  # [name, lines]
        self.tail = []
        cur = None
        for i, l, inside in outside_fence(body):
            if not inside and l.startswith("### Requirement:"):
                cur = [l[len("### Requirement:"):].strip(), [l]]
                self.reqs.append(cur)
            elif not inside and re.match(r"^## ", l):
                self.tail = body[i:]
                break
            elif cur is not None:
                cur[1].append(l)
        for r in self.reqs:
            r[1] = norm(r[1])

    def names(self):
        return [r[0] for r in self.reqs]

    def get(self, name):
        for r in self.reqs:
            if r[0] == name:
                return r
        return None

    def set_diagram(self, block):
        blocks, _ = scan_mermaid(self.header)
        if not blocks or blocks[0][1] is None:
            raise Stop(self.slug, None, 11, "the file has no closed mermaid diagram to replace")
        o, c, _ = blocks[0]
        self.header = self.header[:o] + block + self.header[c + 1:]

    def render(self):
        out = list(norm(self.header))
        out.append("")
        for _, ls in self.reqs:
            out.extend(ls)
            out.append("")
        if self.tail:
            out.extend(self.tail)
        while out and not out[-1]:
            out.pop()
        return "\n".join(out) + "\n"


def new_cap_text(slug, purpose, diagram):
    title = slug.replace("-", " ")
    title = title[0].upper() + title[1:]
    out = ["# " + title, ""] + diagram + ["", "## Purpose", purpose, "", "## Requirements", ""]
    return out


# ---------------------------------------------------------------- the spec's section

def section_lines(spec_lines):
    start = None
    for i, l, inside in outside_fence(spec_lines):
        if inside:
            continue
        if start is None:
            if re.match(r"^## Capability changes\s*$", l):
                start = i + 1
        elif re.match(r"^## ", l):
            return spec_lines[start:i]
    return spec_lines[start:] if start is not None else None


def split_headed(lines, prefix):
    """Split lines in blocks by headings that start with prefix (outside fences): [(heading, body)]."""
    blocks = []
    cur = None
    for i, l, inside in outside_fence(lines):
        if not inside and l.startswith(prefix):
            cur = [l, []]
            blocks.append(cur)
        elif cur is not None:
            cur[1].append(l)
    return blocks


def parse_requirements(cap, kind, body):
    """Requirement blocks of a ADDED / MODIFIED body, as [(name, lines at file level, scenarios, drops, evals)]."""
    reqs = []
    for head, rbody in split_headed(body, "#### Requirement:"):
        name = head[len("#### Requirement:"):].strip()
        text = [head] + rbody
        scenarios = []
        evals = []
        drops = []
        for i, l, inside in outside_fence(text):
            if inside:
                continue
            if l.startswith("##### Scenario:"):
                scenarios.append(l[len("##### Scenario:"):].strip())
            m = re.match(r"^Evals:\s*(.*)$", l)
            if m:
                evals.extend(EVAL_ID.findall(m.group(1)))
            m = re.match(r"^Drops scenario:\s*(.+)$", l)
            if m:
                drops.append(m.group(1).strip())
        if not evals:
            raise Stop(cap, name, 8, "%s requirement has no 'Evals:' line with an id" % kind)
        if not scenarios:
            raise Stop(cap, name, 8, "%s requirement has no scenario" % kind)
        filelines = []
        # lower every heading by one level outside fences (spec-level #### -> file-level ###)
        for (_, l, inside) in outside_fence(text):
            if not inside and re.match(r"^#{4,} ", l):
                l = l[1:]
            if not inside and l.startswith("Drops scenario:"):
                continue
            filelines.append(l)
        filelines[0] = "### Requirement: " + name
        reqs.append((name, norm(filelines), scenarios, drops, evals))
    return reqs


def scenarios_of(lines):
    out = []
    for _, l, inside in outside_fence(lines):
        if not inside and l.startswith("#### Scenario:"):
            out.append(l[len("#### Scenario:"):].strip())
    return out


def diagram_block(cap, body, is_new):
    lines = norm(body)
    if len(lines) == 1 and re.match(r"^Diagram:\s*unchanged\s*$", lines[0]):
        if is_new:
            raise Stop(cap, None, 11, "a new capability needs a mermaid diagram, never 'Diagram: unchanged'")
        return None
    blocks, suspects = scan_mermaid(lines)
    if (len(blocks) == 1 and not suspects and blocks[0][1] is not None
            and blocks[0][0] == 0 and blocks[0][1] == len(lines) - 1):
        return lines
    raise Stop(cap, None, 11, "DIAGRAM block must be exactly one closed ```mermaid block and nothing else, or the line 'Diagram: unchanged'")


def apply(root, spec_path):
    spec_lines = read_lines(spec_path)
    sec = section_lines(spec_lines)
    if sec is None:
        return {}
    blocks = split_headed(sec, "### ")
    if not blocks:
        return {}
    caps = {}  # slug -> {kind: body}
    order = []
    for head, body in blocks:
        m = re.match(r"^### (\S+) · (\S+)\s*$", head)
        if not m or m.group(2) not in KINDS or not SLUG.match(m.group(1)):
            raise Stop(head[4:].strip() or "?", None, "format", "heading must be '### <capability> · <%s>'" % "|".join(KINDS))
        slug, kind = m.groups()
        if slug not in caps:
            caps[slug] = {}
            order.append(slug)
        if kind in caps[slug]:
            raise Stop(slug, None, 9, "two %s blocks for the same capability" % kind)
        caps[slug][kind] = body
    writes = {}
    for slug in order:
        kinds = caps[slug]
        path = os.path.join(root, "capabilities", slug + ".md")
        exists = os.path.isfile(path)
        # rule 7
        if not exists:
            for k in kinds:
                if k not in ("ADDED", "DIAGRAM"):
                    raise Stop(slug, None, 7, "a capability without a file only accepts ADDED, not %s" % k)
            if "ADDED" not in kinds:
                raise Stop(slug, None, 7, "a capability without a file needs an ADDED block")
        # rule 11
        if "DIAGRAM" not in kinds:
            raise Stop(slug, None, 11, "the capability has no DIAGRAM block")
        diagram = diagram_block(slug, kinds["DIAGRAM"], not exists)
        purpose = None
        added = []
        if "ADDED" in kinds:
            body = kinds["ADDED"]
            pre = []
            for l in body:
                if l.startswith("#### Requirement:"):
                    break
                pre.append(l)
            for l in pre:
                m = re.match(r"^Purpose:\s*(.+)$", l)
                if m:
                    purpose = m.group(1).strip()
            if not exists and not purpose:
                raise Stop(slug, None, 7, "a new capability's ADDED block needs a 'Purpose:' line")
            added = parse_requirements(slug, "ADDED", body)
        modified = parse_requirements(slug, "MODIFIED", kinds["MODIFIED"]) if "MODIFIED" in kinds else []
        removed = []
        if "REMOVED" in kinds:
            for head, _ in split_headed(kinds["REMOVED"], "#### Requirement:"):
                removed.append(head[len("#### Requirement:"):].strip())
        renamed = []
        if "RENAMED" in kinds:
            frm = None
            for l in kinds["RENAMED"]:
                m = re.match(r"^FROM:\s*(.+)$", l.strip())
                if m:
                    frm = m.group(1).strip()
                m = re.match(r"^TO:\s*(.+)$", l.strip())
                if m:
                    if frm is None:
                        raise Stop(slug, m.group(1).strip(), 6, "TO without a FROM before it")
                    renamed.append((frm, m.group(1).strip()))
                    frm = None
        # rule 9
        seen = {}
        def claim(name, tag):
            if name in seen:
                raise Stop(slug, name, 9, "the requirement appears in two sections (%s and %s)" % (seen[name], tag))
            seen[name] = tag
        for a, b in renamed:
            claim(a, "RENAMED")
        for n in removed:
            claim(n, "REMOVED")
        for n, *_ in added:
            claim(n, "ADDED")
        for n, *_ in modified:
            if n in [b for _, b in renamed] and seen.get(n) is None:
                seen[n] = "MODIFIED"
                continue
            claim(n, "MODIFIED")
        for _, b in renamed:
            if b in seen and seen[b] not in ("MODIFIED",):
                raise Stop(slug, b, 9, "the new name of a rename appears in another section (%s)" % seen[b])
        # build
        if exists:
            cap = Cap(slug, read_lines(path))
        else:
            cap = Cap(slug, new_cap_text(slug, purpose, diagram) )
        # rule 6 renamed
        for a, b in renamed:
            r = cap.get(a)
            if r is None:
                raise Stop(slug, a, 6, "RENAMED: the old requirement does not exist")
            if cap.get(b) is not None:
                raise Stop(slug, b, 6, "RENAMED: the new name already exists")
            r[0] = b
            r[1][0] = "### Requirement: " + b
        # rule 5 removed
        for n in removed:
            r = cap.get(n)
            if r is None:
                raise Stop(slug, n, 5, "REMOVED: the requirement does not exist")
            cap.reqs.remove(r)
        # rule 3 modified
        for n, lines, scen, drops, ev in modified:
            r = cap.get(n)
            if r is None:
                raise Stop(slug, n, 3, "MODIFIED: the requirement does not exist")
            lost = [s for s in scenarios_of(r[1]) if s not in scen and s not in drops]
            if lost:
                raise Stop(slug, n, 3, "MODIFIED drops scenario(s) without 'Drops scenario:': %s" % "; ".join(lost))
            r[1] = lines
        # rule 4 added
        for n, lines, scen, drops, ev in added:
            r = cap.get(n)
            if r is not None:
                if norm(r[1]) == lines:
                    continue
                raise Stop(slug, n, 4, "ADDED: a requirement with that name exists with other text")
            cap.reqs.append([n, lines])
        if diagram is not None:
            cap.set_diagram(diagram)
        writes[path] = cap.render()
    return writes


# ---------------------------------------------------------------- checks

def cap_files(root):
    d = os.path.join(root, "capabilities")
    if not os.path.isdir(d):
        return []
    return sorted(f for f in os.listdir(d) if f.endswith(".md") and f != "README.md")


def mermaid_blocks(lines):
    """[(start_line_number, body_lines, closed)] for each mermaid fence (any fence length, backticks or tildes)."""
    return [(o + 1, body, c is not None) for o, c, body in scan_mermaid(lines)[0]]


def form_problems(body, closed):
    p = []
    if not closed:
        p.append("the fence never closes")
    first = next((l.strip() for l in body if l.strip() and not l.strip().startswith("%%")), "")
    if not any(first == t or first.startswith(t + " ") for t in DIAGRAM_TYPES):
        p.append("does not open with a known diagram type (%s)" % ", ".join(DIAGRAM_TYPES))
    for j, l in enumerate(body):
        for a, b in ("[]", "{}", "()"):
            if l.count(a) != l.count(b):
                p.append("line %d: unbalanced %s%s" % (j + 1, a, b))
        if l.count('"') % 2:
            p.append("line %d: unbalanced quotes" % (j + 1))
    return p


def node_texts(body):
    """Every node id and node label of a diagram, comments excluded: exact strings, never substrings."""
    texts = set()
    for l in body:
        l = re.sub(r"%%.*$", "", l)
        for m in re.finditer(r'"([^"]*)"', l):
            texts.add(m.group(1).strip())
        l = re.sub(r'"[^"]*"', '""', l)
        for m in re.finditer(r"[\[\(\{>]+([^\[\]\(\)\{\}\"]*)[\]\)\}]+", l):
            texts.add(m.group(1).strip())
        rest = re.sub(r"[\[\(\{>]+[^\[\]\(\)\{\}]*[\]\)\}]+", " ", l)
        rest = re.sub(r"\|[^|]*\|", " ", rest)
        rest = re.sub(r"--\s+[^>]*?\s+-->", " --> ", rest)
        for piece in re.split(r"\s*(?:<?[-=]{2,}[>xo-]?|[-=]\.+-?>?|&|;)\s*", rest):
            piece = piece.strip()
            if piece:
                texts.add(piece)
    return texts


def check_diagrams(root):
    problems = []
    arch = os.path.join(root, "ARCHITECTURE.md")
    general = None
    # A repo with no capability file needs no general diagram: the first capability brings it. From the first
    # capability file on, the general diagram is required and has to name every capability.
    caps = cap_files(root)
    if os.path.isfile(arch):
        lines = read_lines(arch)
        first_h2 = next((i for i, l, ins in outside_fence(lines) if not ins and l.startswith("## ")), len(lines))
        for q in scan_mermaid(lines)[1]:
            problems.append("ARCHITECTURE.md: " + q)
        bl = [b for b in mermaid_blocks(lines)]
        before = [b for b in bl if b[0] <= first_h2]
        if len(before) != 1 and caps:
            problems.append("ARCHITECTURE.md: the general diagram is missing or doubled: expected one mermaid block before the first '##' title, found %d (this repo has capability files, so it needs the general diagram)" % len(before))
        for start, body, closed in before:
            general = node_texts(body)
            for q in form_problems(body, closed):
                problems.append("ARCHITECTURE.md block at line %d: %s" % (start, q))
    elif caps:
        problems.append("ARCHITECTURE.md is missing")
    for f in caps:
        lines = read_lines(os.path.join(root, "capabilities", f))
        for q in scan_mermaid(lines)[1]:
            problems.append("capabilities/%s: %s" % (f, q))
        bl = mermaid_blocks(lines)
        if len(bl) != 1:
            problems.append("capabilities/%s: expected exactly one mermaid block, found %d" % (f, len(bl)))
            continue
        start, body, closed = bl[0]
        title = next((i for i, l in enumerate(lines) if l.startswith("# ")), None)
        between = [l for l in lines[(title + 1 if title is not None else 0): start - 1] if l.strip()]
        if title is None or between:
            problems.append("capabilities/%s: the mermaid block must be the first thing after the '#' title" % f)
        for q in form_problems(body, closed):
            problems.append("capabilities/%s: %s" % (f, q))
        slug = f[:-3]
        if general is not None and slug not in general:
            problems.append("ARCHITECTURE.md: the general diagram has no node for capability '%s'" % slug)
    return problems


def requirements_of(root, f):
    lines = read_lines(os.path.join(root, "capabilities", f))
    reqs = []
    cur = None
    for i, l, inside in outside_fence(lines):
        if inside:
            if cur is not None:
                cur[1].append(l)
            continue
        if l.startswith("### Requirement:"):
            cur = [l[len("### Requirement:"):].strip(), [l]]
            reqs.append(cur)
        elif re.match(r"^## ", l):
            cur = None
        elif cur is not None:
            cur[1].append(l)
    return reqs


def check_evals(root, output_path):
    with open(output_path, encoding="utf-8", errors="replace") as f:
        out = f.read().split("\n")
    passed = set()
    for l in out:
        m = re.match(r"^PASS (S\d{3}-[A-Za-z0-9]+)\b", l)
        if m:
            passed.add(m.group(1))
    failed = set()
    for l in out:
        m = re.match(r"^FAIL (S\d{3}-[A-Za-z0-9]+)\b", l)
        if m:
            failed.add(m.group(1))
    problems = []
    for f in cap_files(root):
        for name, ls in requirements_of(root, f):
            ids = []
            has = False
            for _, l, inside in outside_fence(ls):
                if inside:
                    continue
                m = re.match(r"^Evals:\s*(.*)$", l)
                if m:
                    has = True
                    ids.extend(EVAL_ID.findall(m.group(1)))
            if not has or not ids:
                problems.append("capabilities/%s · %s: no 'Evals:' line with an id" % (f, name))
                continue
            for i in ids:
                if i not in passed:
                    why = "FAIL" if i in failed else "no PASS line"
                    problems.append("capabilities/%s · %s: %s (%s)" % (f, name, i, why))
    return problems


def write_all(writes):
    """All-or-nothing: every target goes to a temp file first, then each is renamed into place. If anything
    fails, what was already replaced is restored and the temp files are removed. -> messages written."""
    plan, done, made_dir = [], [], []
    try:
        for path, text in writes.items():
            old = None
            if os.path.isfile(path):
                with open(path, encoding="utf-8") as f:
                    old = f.read()
            if old == text:
                continue
            d = os.path.dirname(path)
            if not os.path.isdir(d):
                os.makedirs(d)
                made_dir.append(d)
            tmp = "%s.tmp-%d" % (path, os.getpid())
            with open(tmp, "w", encoding="utf-8", newline="\n") as f:
                f.write(text)
            plan.append((path, tmp, old))
        for path, tmp, old in plan:
            os.replace(tmp, path)
            done.append((path, old))
    except Exception:
        for path, old in reversed(done):
            try:
                if old is None:
                    os.remove(path)
                else:
                    with open(path, "w", encoding="utf-8", newline="\n") as f:
                        f.write(old)
            except OSError:
                pass
        for _, tmp, _ in plan:
            try:
                os.remove(tmp)
            except OSError:
                pass
        for d in made_dir:
            try:
                os.rmdir(d)
            except OSError:
                pass
        raise
    return ["capabilities/%s: written" % os.path.basename(p) for p, _, _ in plan]


# ---------------------------------------------------------------- main

def main(argv):
    if len(argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    cmd = argv[1]
    root, rest = find_root(argv[2:])
    if "--root" in argv[2:] and not os.path.isdir(root):
        # A mistyped folder would read as a newborn repo with no capabilities and pass: stop instead.
        print("--root is not an existing directory: %s" % root, file=sys.stderr)
        return 2
    if cmd == "apply":
        if len(rest) != 1 or not os.path.isfile(rest[0]):
            print("usage: apply-capability-changes.sh <spec> [--root DIR]", file=sys.stderr)
            return 2
        try:
            writes = apply(root, rest[0])
        except Stop as e:
            print("STOP " + str(e), file=sys.stderr)
            return 1
        except Exception as e:
            print("STOP internal error while reading: %s" % e, file=sys.stderr)
            return 1
        try:
            for msg in write_all(writes):
                print(msg)
        except Exception as e:  # nothing half-written: write_all restored what it had replaced
            print("STOP write failed, originals restored: %s" % e, file=sys.stderr)
            return 1
        return 0
    if cmd == "check-evals":
        if len(rest) != 1 or not os.path.isfile(rest[0]):
            print("usage: check-capability-evals.sh <suite output> [--root DIR]", file=sys.stderr)
            return 2
        p = check_evals(root, rest[0])
        for x in p:
            print("STOP " + x, file=sys.stderr)
        return 1 if p else 0
    if cmd == "check-diagrams":
        p = check_diagrams(root)
        for x in p:
            print("STOP " + x, file=sys.stderr)
        return 1 if p else 0
    if cmd == "blocks":
        # blocks DIR: writes each mermaid block to DIR/NNN.mmd and prints "NNN<TAB>file<TAB>block-number"
        if len(rest) != 1:
            return 2
        d = rest[0]
        os.makedirs(d, exist_ok=True)
        files = [os.path.join(root, "ARCHITECTURE.md")] if os.path.isfile(os.path.join(root, "ARCHITECTURE.md")) else []
        files += [os.path.join(root, "capabilities", f) for f in cap_files(root)]
        n = 0
        for path in files:
            lines_ = read_lines(path)
            bad = scan_mermaid(lines_)[1] + ["line %d: the mermaid fence never closes" % st for st, _, cl in mermaid_blocks(lines_) if not cl]
            if bad:
                for q in bad:
                    print("STOP %s: %s" % (os.path.relpath(path, root), q), file=sys.stderr)
                return 1
            for k, (start, body, closed) in enumerate(mermaid_blocks(lines_), 1):
                n += 1
                with open(os.path.join(d, "%03d.mmd" % n), "w", encoding="utf-8") as f:
                    f.write("\n".join(body) + "\n")
                print("%03d\t%s\t%d\t%d" % (n, os.path.relpath(path, root), k, start))
        return 0
    print("unknown command: " + cmd, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
