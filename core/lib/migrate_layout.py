#!/usr/bin/env python3
# migrate_layout.py — the engine of migrate-layout.sh (spec 076, delivery C). Internal: not invocable.
# The shell wrapper reads the brain's language and facts (workspaces folder, head file, initiative head
# form, memory-node types) with the product's own functions and hands them over in OS_ML_* variables.
#
# The engine plans first: it replays the whole migration on a virtual copy of the brain (VFS) and records
# every operation with the fingerprint of what it reads and of what it writes. Printing that record is the
# plan (C22); applying it is replaying the record on the disk (C25). Nothing here reads the disk twice for
# the same decision: the plan is the single source of what happens.
#
# Exit: 0 ran (or nothing to do) · 1 stopped, nothing (more) written · 3 interrupted by the eval hook.
import datetime
import fnmatch
import hashlib
import json
import os
import posixpath
import re
import subprocess
import sys

ENV = os.environ
PLAN_REL = '.os/migrate-layout.plan'
BLOB_REL = '.os/migrate-layout.blobs'
DELIMS = set(' \t`|()[]<>"\',;!')
MARCAS = ('blocked-by', 'hold', 'hold-until', 'since')
LINE_RE = re.compile(r'^- (\d{4}-\d{2}-\d{2}) · (clave · )?\[(.+?)\]\(([^)]+)\)(.*)$')
SUP_RE = re.compile(r' — \*\*reemplazada por\*\*: \[(.*)\]\(([^)]*)\)\s*$')
KEY_RE = re.compile(r'^([A-Za-z0-9_-]+):[ \t]*(.*)$')
ENTRY_LIKE_RE = re.compile(r'^- \d{4}-\d{2}-\d{2}')
INDEX_LINK_RE = re.compile(r'\]\(<?(\./)?(decisions|learnings)/[^)]*\)')
REFDEF_RE = re.compile(r'^ {0,3}\[[^\]]+\]:[ \t]*(?:<([^>]*)>|((?:\\.|\S)+))')
EXT_RE = re.compile(r'\.[A-Za-z][A-Za-z0-9]{0,5}$')


def sha(b):
    return hashlib.sha256(b).hexdigest()


class Unreadable(Exception):
    pass


# ---------------------------------------------------------------- the catalog
def load_strings(path, lang):
    cat = {}
    key = None
    with open(path, encoding='utf-8') as f:
        for line in f.read().split('\n'):
            if line.startswith('key: '):
                key = line[5:].strip()
                cat[key] = {}
                continue
            if key is None:
                continue
            m = re.match(r'^([a-z][a-z]):(?: (.*))?$', line)
            if m and m.group(1) in ('en', lang):
                cat[key].setdefault(m.group(1), []).append(m.group(2) or '')
    out = {}
    for k, v in cat.items():
        out[k] = '\n'.join(v.get(lang) or v.get('en') or [])
    return out


def split_fm(text):
    """(fm_lines or None, index of the first body line, lines). Raises Unreadable on an unclosed block."""
    lines = text.split('\n')
    if lines and lines[0].rstrip('\r') == '---':
        for i in range(1, len(lines)):
            if lines[i].rstrip('\r') == '---':
                return lines[1:i], i + 1, lines
        raise Unreadable('unclosed frontmatter')
    return None, 0, lines


def fm_dict(text):
    try:
        fm, _, _ = split_fm(text)
    except Unreadable:
        return None
    d = {}
    for l in fm or []:
        m = KEY_RE.match(l)
        if m and m.group(1) not in d:
            d[m.group(1)] = m.group(2).strip()
    return d


def body_title(text):
    fm, bs, lines = split_fm(text)
    for l in lines[bs:]:
        if l.startswith('# '):
            return l[2:].strip()
    return ''


def add_fm_keys(text, adds):
    fm, bs, lines = split_fm(text)
    new = ['%s: %s' % (k, v) for k, v in adds]
    if fm is None:
        return '---\n' + '\n'.join(new) + '\n---\n\n' + text
    lines[bs - 1:bs - 1] = new
    return '\n'.join(lines)


def unquote(v):
    """V without one pair of matching surrounding quotes: the rule of `os_unquote` in common.sh."""
    if len(v) >= 2 and v[0] == v[-1] and v[0] in '"\'':
        return v[1:-1]
    return v


def parse_list(v):
    """The values of `about:` as `os_about_values` reads them: one value, or `[a, b]` on one line, each
    trimmed and unquoted."""
    v = v.strip()
    if v.startswith('[') and v.endswith(']'):
        v = v[1:-1]
    return [unquote(x.strip()) for x in v.split(',') if x.strip()]


def parse_task(line):
    """-> (id, texto) with the same reading as os_backlog_lee."""
    resto = line[6:]
    while resto.endswith(')') and '(' in resto:
        grupo = resto[resto.rindex('(') + 1:-1]
        if grupo.startswith('since '):
            clave = 'since'
        elif ':' in grupo:
            clave = grupo.split(':', 1)[0].strip()
        else:
            break
        if clave not in MARCAS:
            break
        resto = resto[:resto.rindex('(')].strip()
    tid = ''
    if resto.startswith('tsk-'):
        parts = resto.split(' ', 1)
        tid = parts[0]
        resto = parts[1] if len(parts) > 1 else ''
    return tid, resto.strip()


def rel_norm(p):
    """The same normal form as `os_rel_norm` of common.sh: no `./`, no `//`, no `/./`, no trailing slash."""
    prev = None
    while p != prev:
        prev = p
        if p.startswith('./'):
            p = p[2:]
        p = p.replace('//', '/').replace('/./', '/')
        if p.endswith('/.'):
            p = p[:-2]
        if p.endswith('/'):
            p = p[:-1]
    return p


def about_is_single(value, head):
    """The reading of `os_about_is_single`: VALUE names HEAD and nothing else. It is how `capture --about`
    recognises the standing initiative of a node (C30); the migration reuses the same one (C31 step 7)."""
    vals = parse_list(value)
    return len(vals) == 1 and rel_norm(vals[0]) == head


def render_ini(title, status, about):
    """The head of an initiative the migration creates, rendered by `os_ini_render` of common.sh: the one
    writer of that shape, shared with `capture --about --create` and the system's `tasks-to-sort`. Owned by
    the operator (the title of the account file, `OS_ML_OWNER`), dated the day the plan is made."""
    out = subprocess.run(
        ['bash', '-c', '. "$1" && os_ini_render "$2" "$3" "$4" "$5" "$6"', '_', ENV['OS_ML_COMMON'],
         title, status, about, ENV.get('OS_ML_OWNER', ''), datetime.date.today().isoformat()],
        capture_output=True, text=True)
    if out.returncode != 0:
        raise RuntimeError('os_ini_render failed: ' + out.stderr.strip())
    return out.stdout


def is_task(line):
    return line.startswith('- [ ] ') or line.startswith('- [x] ')


class Planner:
    def __init__(self, brain, S):
        self.brain = brain
        self.S = S
        self.lang = ENV['OS_ML_LANG']
        self.wsdir = ENV['OS_ML_WSDIR']
        self.head = ENV['OS_ML_HEAD']
        self.ini_form = ENV['OS_ML_INI_FORM']
        self.types = ENV.get('OS_ML_TYPES', '').split()
        self.core = os.path.realpath(ENV['OS_ML_CORE'])
        self.core_claude = os.path.join(self.core, 'CLAUDE.md')
        self.ops = []
        self.blockers = []
        self.unknown = []
        self.warnings = []
        self.kind = {}
        self.target = {}
        self.mem = {}
        self.disk = {}
        self.dirs = set()
        self.walk()
        self.old_kind = dict(self.kind)
        self.old_dirs = set(self.dirs)
        self.old_target = dict(self.target)
        self.touched = set()
        self.created = {}
        self.origin = {p: p for p in self.kind}
        self.fmap = {}
        self.dirmap = {}
        self.skill_dirs = {}
        self.prov = {}
        self.index_prose = {}

    # ------------------------------------------------------------ the virtual brain
    def walk(self):
        root = self.brain
        for dp, dn, fn in os.walk(root):
            rel = os.path.relpath(dp, root)
            rel = '' if rel == '.' else rel.replace(os.sep, '/')
            keep = []
            for d in dn:
                p = posixpath.join(rel, d) if rel else d
                full = os.path.join(dp, d)
                if d == '.git' or (rel == '' and d in ('.os', '.claude')):
                    continue
                if os.path.islink(full):
                    self.kind[p] = 'l'
                    self.target[p] = os.readlink(full)
                    self.add_dirs(p)
                    continue
                keep.append(d)
                self.dirs.add(p)
            dn[:] = keep
            for f in fn:
                if f == '.git':
                    continue
                p = posixpath.join(rel, f) if rel else f
                full = os.path.join(dp, f)
                if os.path.islink(full):
                    self.kind[p] = 'l'
                    self.target[p] = os.readlink(full)
                else:
                    self.kind[p] = 'f'
                    self.disk[p] = p
                self.add_dirs(p)

    def add_dirs(self, p):
        d = posixpath.dirname(p)
        while d:
            self.dirs.add(d)
            d = posixpath.dirname(d)

    def exists(self, p):
        return p in self.kind or p in self.dirs

    def is_dir(self, p):
        return p in self.dirs and p not in self.kind

    def read(self, p):
        if p in self.mem:
            return self.mem[p]
        with open(os.path.join(self.brain, self.disk[p]), 'rb') as f:
            return f.read()

    def text(self, p):
        return self.read(p).decode('utf-8', errors='surrogateescape')

    def fp(self, p):
        if self.kind.get(p) == 'l':
            return 'L:' + self.target[p]
        return sha(self.read(p))

    def listdir(self, d):
        pre = d + '/' if d else ''
        out = set()
        for p in list(self.kind):
            if p.startswith(pre):
                out.add(p[len(pre):].split('/')[0])
        for p in self.dirs:
            if p.startswith(pre) and p != d:
                out.add(p[len(pre):].split('/')[0])
        return sorted(out)

    def files_under(self, d):
        pre = d + '/'
        return sorted(p for p in self.kind if p.startswith(pre))

    def block(self, msg):
        if msg not in self.blockers:
            self.blockers.append(msg)

    # ------------------------------------------------------------ recording
    def touch(self, op, path):
        if path in self.touched:
            return
        self.touched.add(path)
        if path in self.old_kind:
            op.setdefault('pre', []).append([path, self.orig_fp(path)])
        else:
            op.setdefault('absent', []).append(path)

    def orig_fp(self, path):
        if self.old_kind.get(path) == 'l':
            return 'L:' + self.old_target[path]
        with open(os.path.join(self.brain, path), 'rb') as f:
            return sha(f.read())

    def rec(self, step, op, **kw):
        d = {'op': op, 'step': step}
        d.update(kw)
        d['i'] = len(self.ops)
        self.ops.append(d)
        return d

    def check_dest(self, path, why):
        """A destination is written only under real directories of the brain: no symlink in the way, no file
        where a directory is needed."""
        d = posixpath.dirname(path)
        while d:
            full = os.path.join(self.brain, d)
            if d in self.kind or os.path.islink(full) or (os.path.lexists(full) and not os.path.isdir(full)):
                self.block(self.S['MIGRATE_LAYOUT_B_ANCESTOR'] % (d, why))
                return False
            d = posixpath.dirname(d)
        return True

    def mv(self, src, dst, step):
        if src not in self.kind:
            return False
        if not self.check_dest(dst, src):
            return False
        if dst in self.created:
            self.block(self.S['MIGRATE_LAYOUT_B_SAME_DEST'] % (self.created[dst], src, dst))
            return False
        dup = False
        if dst in self.kind:
            if self.fp(dst) == self.fp(src):
                dup = True
            else:
                self.block(self.S['MIGRATE_LAYOUT_B_EXISTS'] % (dst, src))
                return False
        elif dst in self.dirs:
            self.block(self.S['MIGRATE_LAYOUT_B_EXISTS'] % (dst, src))
            return False
        op = self.rec(step, 'move', src=src, dst=dst, fp=self.fp(src), dup=dup)
        self.touch(op, src)
        self.touch(op, dst)
        self.created[dst] = src
        self.kind[dst] = self.kind[src]
        if self.kind[src] == 'l':
            self.target[dst] = self.target[src]
        else:
            self.disk[dst] = self.disk.get(src)
            if src in self.mem:
                self.mem[dst] = self.mem.pop(src)
            if self.disk[dst] is None:
                del self.disk[dst]
        self.origin[dst] = self.origin.get(src, src)
        self.fmap[self.origin[dst]] = dst
        self.unset(src)
        self.add_dirs(dst)
        return True

    def unset(self, p):
        self.kind.pop(p, None)
        self.target.pop(p, None)
        self.mem.pop(p, None)
        if p in self.disk:
            pass

    def put(self, path, data, step, detail='', origin=None):
        if isinstance(data, str):
            data = data.encode('utf-8', errors='surrogateescape')
        before = self.fp(path) if path in self.kind else None
        if before == sha(data):
            return
        if not self.check_dest(path, path):
            return
        if before is None and path in self.created:
            self.block(self.S['MIGRATE_LAYOUT_B_SAME_DEST'] % (self.created[path], path, path))
            return
        op = self.rec(step, 'put', path=path, before=before, after=sha(data), detail=detail)
        self.touch(op, path)
        op['blob'] = data
        if before is None:
            self.created[path] = path
            if origin:
                self.origin[path] = origin
        self.kind[path] = 'f'
        self.mem[path] = data
        self.add_dirs(path)

    def delete(self, path, step, detail=''):
        if path not in self.kind:
            return
        op = self.rec(step, 'delete', path=path, fp=self.fp(path), detail=detail)
        self.touch(op, path)
        self.unset(path)

    def delete_disk(self, path, step, detail=''):
        """Delete something the walk does not cover (inside `.claude/`) or that is in the model."""
        if path in self.kind:
            return self.delete(path, step, detail)
        full = os.path.join(self.brain, path)
        if not os.path.lexists(full):
            return
        if os.path.islink(full):
            fp = 'L:' + os.readlink(full)
        else:
            with open(full, 'rb') as f:
                fp = sha(f.read())
        op = self.rec(step, 'delete', path=path, fp=fp, detail=detail)
        if path not in self.touched:
            self.touched.add(path)
            op.setdefault('pre', []).append([path, fp])

    def link(self, path, target, step):
        if not self.check_dest(path, path):
            return
        op = self.rec(step, 'link', path=path, target=target)
        self.touch(op, path)
        if path in self.old_kind or not path.startswith('.claude/'):
            self.kind[path] = 'l'
            self.target[path] = target
            self.add_dirs(path)

    # ------------------------------------------------------------ the layout
    def workspaces(self):
        out = []
        for n in self.listdir(self.wsdir):
            if self.is_dir(posixpath.join(self.wsdir, n)):
                out.append(posixpath.join(self.wsdir, n))
        return out

    def nodes(self, ws):
        out = []
        for t in self.types:
            base = posixpath.join(ws, t)
            for n in self.listdir(base):
                if self.is_dir(posixpath.join(base, n)):
                    out.append(posixpath.join(base, n))
        return out

    def node_head(self, node):
        return posixpath.join(node, self.head)

    def initiatives(self, ws):
        out = {}
        base = posixpath.join(ws, 'initiatives')
        for n in self.listdir(base):
            full = posixpath.join(base, n)
            if self.is_dir(full):
                for h in (self.head, 'README.md'):
                    if posixpath.join(full, h) in self.kind:
                        out[n] = posixpath.join(full, h)
                        break
            elif n.endswith('.md') and full in self.kind and not n == 'backlog.md':
                out[n[:-3]] = full
        return out

    def ini_head_path(self, ws, slug):
        return posixpath.join(ws, self.ini_form.replace('@SLUG@', slug))

    # ------------------------------------------------------------ tokens (step 11 and the roles)
    def md_dests(self, line):
        """The destinations of the inline Markdown links of LINE, as (start, end, kind): angle brackets keep
        their spaces, a plain destination ends at an unescaped space or at its unbalanced `)`."""
        out = []
        # A reference definition (`[label]: destination`) is a link like an inline one.
        m = REFDEF_RE.match(line)
        if m:
            if m.group(1) is not None:
                out.append((m.start(1), m.end(1), 'angle'))
            else:
                out.append((m.start(2), m.end(2), 'plain'))
            return out
        i = 0
        while True:
            k = line.find('](', i)
            if k < 0:
                break
            j = k + 2
            if j < len(line) and line[j] == '<':
                e = line.find('>', j + 1)
                if e < 0:
                    i = j
                    continue
                out.append((j + 1, e, 'angle'))
                i = e + 1
            else:
                e = j
                depth = 0
                while e < len(line):
                    c = line[e]
                    if c == '\\' and e + 1 < len(line):
                        e += 2
                        continue
                    if c in ' \t':
                        break
                    if c == '(':
                        depth += 1
                    elif c == ')':
                        if depth == 0:
                            break
                        depth -= 1
                    e += 1
                out.append((j, e, 'plain'))
                i = e
        return out

    def scan_tokens(self, line, dir_o):
        """Yield (start, end, info) for every token of LINE that names an existing old path, by the product's
        convention (every path is relative to the brain; only a Markdown link is relative to its file):
        - the destination of an inline Markdown link, whole (spaces and escapes included), read from the file's
          old folder (`mode: file`);
        - every token inside a backtick span, and a table cell that is a single path, read from the brain root
          only (`mode: brain`);
        - nothing else: a word of prose outside backticks and links is never a path, even if it names a file."""
        found = []
        masked = list(line)
        for s, e, kind in self.md_dests(line):
            raw = line[s:e]
            dec = raw.replace('%20', ' ')
            if kind == 'plain':
                dec = re.sub(r'\\(.)', r'\1', dec)
            r = self.token(dec, dir_o, ('file',)) if dec else None
            if r and r[0] == 0 and r[1] == len(dec):
                info = dict(r[2])
                info.update({'md': kind, 'esc': '\\' in raw, 'pct': '%20' in raw})
                found.append((s, e, info))
            for t in range(s, e):
                masked[t] = ' '
        line2 = ''.join(masked)
        spans = []
        for m in re.finditer(r'(`+)(.+?)\1', line2):
            spans.append((m.start(2), m.end(2)))
        for a, b in spans:
            if not self.brain_whole(line2, a, b, found):
                self.brain_tokens(line2, a, b, found)
        masked2 = list(line2)
        for a, b in spans:
            for t in range(a - 1, b + 1):
                if 0 <= t < len(masked2):
                    masked2[t] = ' '
        line3 = ''.join(masked2)
        if line3.lstrip().startswith('|'):
            pos = 0
            for cell in line3.split('|'):
                a = pos
                b = pos + len(cell)
                pos = b + 1
                body = cell.strip()
                if body:
                    k = a + cell.index(body)
                    if not self.brain_whole(line3, k, k + len(body), found) and not re.search(r'\s', body):
                        self.brain_tokens(line3, k, k + len(body), found)
        found.sort(key=lambda x: x[0])
        return found

    def brain_whole(self, line, a, b, found):
        """LINE[a:b], whole (spaces included), as one path relative to the brain: appended to FOUND and True
        when it names an existing old path. A span or a cell is tried whole before it is split in words."""
        seg = line[a:b].strip()
        if not seg or seg != line[a:b] or not re.search(r'\s', seg):
            return False
        r = self.token(seg, '', ('brain',))
        if r and r[0] == 0 and r[1] == len(seg):
            found.append((a, b, r[2]))
            return True
        return False

    def brain_tokens(self, line, a, b, found):
        """The tokens of LINE[a:b] that name an existing old path relative to the brain, appended to FOUND."""
        i = a
        while i < b:
            if line[i] in DELIMS:
                i += 1
                continue
            j = i
            while j < b and line[j] not in DELIMS:
                j += 1
            r = self.token(line[i:j], '', ('brain',))
            if r:
                s, e, info = r
                found.append((i + s, i + e, info))
            i = j

    def token(self, tok, dir_o, modes=('file', 'brain')):
        s = 0
        e = len(tok)
        while s < e and tok[s] in '*_~':
            s += 1
        while e > s and tok[e - 1] in '*_~':
            e -= 1
        core = tok[s:e]
        if not core or '://' in core or core.startswith(('mailto:', '#', '/', '~', '$', '-')):
            return None
        if '*' in core or '?' in core or '{{' in core:
            return None
        anch = ''
        if '#' in core:
            k = core.index('#')
            anch = core[k:]
            core = core[:k]
        lsuf = ''
        m = re.search(r':\d+(-\d+)?$', core)
        if m:
            lsuf = core[m.start():]
            core = core[:m.start()]
        elif core.endswith(':'):
            lsuf = ':'
            core = core[:-1]
        trail = ''
        while core.endswith('.') and core not in ('.', '..') and not core.endswith('/.') and not core.endswith('/..'):
            trail += '.'
            core = core[:-1]
        if not core:
            return None
        slash = core.endswith('/')
        path = core.rstrip('/') if slash else core
        if not path:
            return None
        if '/' not in path and not EXT_RE.search(path):
            return None
        cands = []
        c1 = posixpath.normpath(posixpath.join(dir_o, path))
        if 'file' in modes and not c1.startswith('..'):
            cands.append(('file', c1))
        if 'brain' in modes and not path.startswith('../'):
            c2 = posixpath.normpath(path)
            if not c2.startswith('..'):
                cands.append(('brain', c2))
        for mode, P in cands:
            if P in self.old_kind or P in self.old_dirs:
                return (s, e,
                        {'mode': mode, 'P': P, 'slash': slash, 'anch': anch, 'lsuf': lsuf, 'trail': trail,
                         'dot': path.startswith('./'), 'path': path})
        return None

    def map_path(self, P):
        if P in self.fmap:
            return self.fmap[P]
        best = None
        for d, nd in self.dirmap.items():
            if P == d or P.startswith(d + '/'):
                if best is None or len(d) > len(best[0]):
                    best = (d, nd)
        if best:
            return best[1] + P[len(best[0]):]
        return None

    # The frontmatter keys whose value is a path relative to the brain (`superseded_by`, spec 046) or a
    # list of them (`about`, specs 049 and 076): rewritten through the move map like a backticked path.
    FM_PATH_KEYS = ('superseded_by', 'about')

    def fm_path_line(self, line):
        m = KEY_RE.match(line)
        if not m or m.group(1) not in self.FM_PATH_KEYS:
            return line
        raw = m.group(2).strip()
        is_list = raw.startswith('[') and raw.endswith(']')
        vals = parse_list(raw)
        if not vals:
            return line
        changed = False
        new = []
        for v in vals:
            P = rel_norm(v)
            T = self.map_path(P)
            if T is not None and T != P:
                new.append(T)
                changed = True
            else:
                new.append(v)
        if not changed:
            return line
        value = '[%s]' % ', '.join(new) if is_list else new[0]
        return '%s: %s' % (m.group(1), value)

    def rewrite_text(self, text, dir_o, dir_n, dirs=None):
        """TEXT with every moved path rewritten once. `dirs` gives, per line, the old directory its relative paths
        are read from (a task block that moved from another backlog keeps the one it came from)."""
        out = []
        count = 0
        all_lines = text.split('\n')
        fm_end = 0
        if all_lines and all_lines[0].rstrip('\r') == '---':
            for k in range(1, len(all_lines)):
                if all_lines[k].rstrip('\r') == '---':
                    fm_end = k
                    break
        for no, line in enumerate(all_lines):
            if 0 < no < fm_end:
                new_line = self.fm_path_line(line)
                if new_line != line:
                    count += 1
                out.append(new_line)
                continue
            d_o = dirs[no] if dirs and no < len(dirs) else dir_o
            if ('/' not in line and '.' not in line):
                out.append(line)
                continue
            res = []
            last = 0
            for s, e, info in self.scan_tokens(line, d_o):
                P = info['P']
                T = self.map_path(P)
                moved = T is not None and T != P
                if T is None and P not in self.kind and P not in self.dirs:
                    continue
                if info['mode'] == 'brain':
                    if not moved:
                        continue
                    new = T
                else:
                    Tn = T if T is not None else P
                    newrel = posixpath.relpath(Tn, dir_n or '.')
                    if not moved and newrel == posixpath.normpath(info['path']):
                        continue
                    new = newrel
                    if info['dot'] and not new.startswith('.'):
                        new = './' + new
                    elif info['dot'] and new.startswith('.') and not new.startswith('..') and not new.startswith('./'):
                        new = './' + new
                if info['slash']:
                    new += '/'
                full_old = line[s:e]
                tail = info['trail'] + info['lsuf'] + info['anch']
                rep = new + tail
                if info.get('md') == 'plain':
                    if info['esc']:
                        rep = re.sub(r'([ ()])', r'\\\1', rep)
                    elif info['pct']:
                        rep = rep.replace(' ', '%20')
                    elif re.search(r'[ ()]', rep):
                        rep = re.sub(r'([ ()])', r'\\\1', rep)
                if rep == full_old:
                    continue
                res.append(line[last:s])
                res.append(rep)
                last = e
                count += 1
            res.append(line[last:])
            out.append(''.join(res))
        return '\n'.join(out), count

    def plan(self):
        self.collect_unknown()
        self.step1()
        self.step2()
        self.step3()
        self.step4()
        self.step5()
        self.step6()
        self.step7()
        self.step8()
        self.step9()
        self.step10()
        self.step11()
        self.step12()
        self.prune()

    def unk(self, path, reason=''):
        if not any(u[0] == path for u in self.unknown):
            self.unknown.append((path, reason))

    def collect_unknown(self):
        ws_known = set([self.head, 'README.md', 'resolver.md', '.resolver.md', 'backlog.md',
                        'decisions.md', 'learnings.md', 'decisions', 'learnings', 'glossary.md', 'context-map.md',
                        'voice.md', 'voice', 'visual-style.md', 'initiatives', 'people', 'records', 'context',
                        'resources', 'index.md'] + self.types)
        node_known = set([self.head, 'README.md', 'resolver.md', '.resolver.md', 'backlog.md',
                          'decisions.md', 'decisions', 'context', 'research', 'material', 'resources', 'archive',
                          'index.md'])
        for ws in self.workspaces():
            for n in self.listdir(ws):
                if n.startswith('.') and n != '.resolver.md':
                    continue
                if n not in ws_known:
                    self.unk(posixpath.join(ws, n))
            for node in self.nodes(ws):
                for n in self.listdir(node):
                    if n.startswith('.') and n != '.resolver.md':
                        continue
                    if n not in node_known:
                        self.unk(posixpath.join(node, n))
        if 'backlog.md' in self.kind:
            self.unk('backlog.md', self.S['MIGRATE_LAYOUT_R_ROOT_BACKLOG'])

    # step 1 · the account
    def step1(self):
        self.mv('operator.md', 'account/operator.md', 1)
        self.mv('voice.md', 'account/voice/voice.md', 1)
        if self.is_dir('voice'):
            for p in self.files_under('voice'):
                self.mv(p, 'account/' + p, 1)
            self.dirmap['voice'] = 'account/voice'

    # step 2 · the session contract: adoption and links, each operation on its own
    def contract_state(self, loc):
        full = os.path.join(self.brain, loc)
        if os.path.islink(full):
            if not os.path.exists(full):
                return 'ours'
            return 'ours' if os.path.realpath(full) == self.core_claude else 'foreign'
        if os.path.exists(full):
            return 'foreign'
        return 'absent'

    def step2(self):
        S = self.S
        locs = ['CLAUDE.md', 'AGENTS.md', '.claude/CLAUDE.md']
        foreign = [l for l in locs if self.contract_state(l) == 'foreign']
        opfile = 'account/operator.md'
        if foreign:
            if opfile not in self.kind:
                self.block(S['MIGRATE_LAYOUT_B_NO_OPERATOR'])
                return
            snaps = []
            seen = set()
            for loc in foreign:
                real = os.path.realpath(os.path.join(self.brain, loc))
                if not os.path.isfile(real) or not os.access(real, os.R_OK):
                    self.block(S['MIGRATE_LAYOUT_B_NOT_A_FILE'] % loc)
                    return
                if real in seen:
                    continue
                seen.add(real)
                with open(real, 'rb') as f:
                    snaps.append((loc, f.read()))
            # The adopted text first (one atomic write of the whole account file), the foreign files after it:
            # a cut between the two leaves each operation on its own fingerprint, never half an adoption.
            content = self.read(opfile)
            if content and not content.endswith(b'\n'):
                content += b'\n'
            content += ('\n## %s\n' % S['INSTALL_ADOPTED_HEADING']).encode()
            lines = []
            for loc, data in snaps:
                content += ('\n### %s\n\n' % loc).encode() + data
                if data and not data.endswith(b'\n'):
                    content += b'\n'
                lines.append('%s → %s' % (loc, opfile))
            self.put(opfile, content, 2, S['MIGRATE_LAYOUT_D_ADOPT'])
            self.ops[-1]['adopt_lines'] = lines
            for loc in foreign:
                self.delete_disk(loc, 2, S['MIGRATE_LAYOUT_D_ADOPTED'])
        # A root contract that is a link to the product (or broken) is replaced by the two new places.
        if 'CLAUDE.md' not in foreign and os.path.islink(os.path.join(self.brain, 'CLAUDE.md')):
            self.delete_disk('CLAUDE.md', 2, S['MIGRATE_LAYOUT_D_CLAUDE'])
        for loc in ('AGENTS.md', '.claude/CLAUDE.md'):
            full = os.path.join(self.brain, loc)
            if os.path.islink(full) and os.path.realpath(full) == self.core_claude:
                continue
            if loc not in foreign and os.path.islink(full):
                self.delete_disk(loc, 2, '')
            self.link(loc, self.core_claude, 2)

    # step 3 · the machinery of the root goes to .system/
    def step3(self):
        moved_mounts = self.mv('mounts.md', '.system/mounts.md', 3)
        self.mv('tree.md', '.system/tree.md', 3)
        self.mv('resolver.md', '.system/resolver.md', 3)
        if moved_mounts:
            gi = '.gitignore'
            cur = self.text(gi) if gi in self.kind else ''
            out = []
            have = False
            for l in cur.split('\n'):
                if l.strip() == 'mounts.md':
                    if not have:
                        out.append('.system/mounts.md')
                        have = True
                    continue
                if l.strip() == '.system/mounts.md':
                    have = True
                out.append(l)
            if not have:
                if out and out[-1] == '':
                    out.insert(len(out) - 1, '.system/mounts.md')
                else:
                    out.append('.system/mounts.md')
            new = '\n'.join(out)
            if gi not in self.kind and not new.endswith('\n'):
                new += '\n'
            self.put(gi, new, 3, '.system/mounts.md')

    # step 4 · roles become skills
    def step4(self):
        if not self.is_dir('roles'):
            return
        mds = []
        for n in self.listdir('roles'):
            p = 'roles/' + n
            if p in self.kind and n.endswith('.md'):
                mds.append(n)
            else:
                self.unk(p)
        # Who links each role file by its path: the other roles and, on a brain already half migrated, the
        # skills made from roles (their text still names `roles/<file>`): a file shared by two stays put.
        linkers = {n: set() for n in mds}
        sources = [('r:' + n, 'roles/' + n, 'roles') for n in mds]
        for p in sorted(self.kind):
            if p.startswith('.agents/skills/') and p.endswith('.md') and self.kind[p] == 'f':
                parts = p.split('/')
                if len(parts) >= 4:
                    sources.append(('s:' + parts[2], p, posixpath.dirname(p)))
        for key, path, dir_o in sources:
            for line in self.text(path).split('\n'):
                for s_, e_, info in self.scan_tokens(line, dir_o):
                    P = info['P']
                    if P.startswith('roles/') and P[6:] in linkers and key != 'r:' + P[6:]:
                        linkers[P[6:]].add(key)
        owner = {}
        for n in mds:
            ls = linkers[n]
            if len(ls) >= 2:
                self.unk('roles/' + n, self.S['MIGRATE_LAYOUT_R_SHARED_ROLE'])
                owner[n] = False
            elif len(ls) == 1:
                k = next(iter(ls))
                owner[n] = k[2:] if k.startswith('r:') else k
            else:
                owner[n] = None

        def top(n, seen=()):
            o = owner.get(n)
            if o is None:
                return n
            if isinstance(o, str) and o.startswith('s:'):
                return o
            if o is False or o in seen:
                return False
            return top(o, seen + (n,))
        for n in mds:
            if owner[n] is False:
                continue
            t = top(n)
            if t is False or owner.get(t) is False:
                self.block(self.S['MIGRATE_LAYOUT_B_ROLE_CYCLE'] % ('roles/' + n))
                continue
            name = n[:-3]
            if t == n:
                dst = '.agents/skills/%s/SKILL.md' % name
                if not self.mv('roles/' + n, dst, 4):
                    continue
                self.skill_file(dst, name)
                lk = '.claude/skills/%s' % name
                want = '../../.agents/skills/%s' % name
                full = os.path.join(self.brain, lk)
                if os.path.islink(full) and os.readlink(full) == want:
                    continue
                if os.path.lexists(full):
                    self.block(self.S['MIGRATE_LAYOUT_B_EXISTS'] % (lk, 'roles/' + n))
                    continue
                self.link(lk, want, 4)
            elif t.startswith('s:'):
                self.mv('roles/' + n, '.agents/skills/%s/%s' % (t[2:], n), 4)
            else:
                self.mv('roles/' + n, '.agents/skills/%s/%s' % (t[:-3], n), 4)

    def skill_file(self, path, name):
        text = self.text(path)
        title = ''
        try:
            fm, bs, lines = split_fm(text)
        except Unreadable:
            self.block(self.S['MIGRATE_LAYOUT_B_FM'] % path)
            return
        for l in lines[bs:]:
            if l.startswith('# '):
                title = l[2:].strip()
                break
        desc = re.sub(r'^(Rol|Role)\s*:\s*', '', title, flags=re.I)
        desc = re.sub(r'\s*\(SSOT\)\s*$', '', desc).strip() or name
        if re.search(r'(^[\[\]{}&*!|>\'"%@`#-]|: | #|:$)', desc):
            desc = '"' + desc.replace('\\', '\\\\').replace('"', '\\"') + '"'
        have = fm_dict(text) or {}
        adds = []
        if 'name' not in have:
            adds.append(('name', name))
        if 'description' not in have:
            adds.append(('description', desc))
        if adds:
            self.put(path, add_fm_keys(text, adds), 4, 'name, description')

    # step 5 · the link to the manual
    def step5(self):
        """The manual link at the root is always `OS_MANUAL_LINK` (D16, C11), to the manual of the brain's
        language (`os_manual_file`, its physical path handed over by the wrapper), as `manual-link.sh` leaves it. An old link with
        the Spanish name is replaced; a brain with no link at all gets one. A file of the operator with that
        name is never touched."""
        name = ENV.get('OS_ML_MANUAL_LINK') or 'HOW-IT-WORKS.md'
        target = ENV.get('OS_ML_MANUAL_TARGET') or os.path.join(self.core, 'manual', name)
        old = 'COMO-FUNCIONA.md'
        if old != name and self.kind.get(old) == 'l':
            self.delete(old, 5, self.S['MIGRATE_LAYOUT_D_MANUAL'])
            self.fmap[old] = name
        if name not in self.kind:
            self.link(name, target, 5)

    # step 6 · the hand-written indexes go to the frontmatter of the files they link
    STD_SUBTITLES = (
        'Registro append-only. Nunca se corrige: si una decisión cambia, se agrega otra que la reemplaza y la nombra.',
        'Vivo: se actualiza o se borra. Lo que se intentó y no cerró queda con status: provisional, para que nadie lo reintente sin saberlo.',
    )

    def parse_index(self, idx):
        """The entries of a hand-written index, and the rest of its text. A line that looks like an entry (a
        list line that opens with a date, or any line with a link into the index's `decisions/` or `learnings/`)
        and cannot be read stops the run: its data would be lost. Every other line that is not the first title, a
        standard subtitle of the product or blank is prose, wherever it sits (before, between or after the
        entries), and is kept verbatim in `legacy-<index>-notes.md`: consecutive lines stay together, with the
        blank lines between them, and separate stretches are joined by one blank line."""
        entries = []
        chunks = []
        cur = []
        pending = []
        titled = False

        def close():
            if cur:
                chunks.append(list(cur))
            cur[:] = []
            pending[:] = []

        for no, raw in enumerate(self.text(idx).split('\n'), 1):
            l = raw.rstrip('\r')
            if l.strip() == '':
                if cur:
                    pending.append(raw)
                continue
            m = LINE_RE.match(l)
            if m:
                close()
                rest = m.group(5)
                sup = None
                note = None
                mm = SUP_RE.search(rest)
                if mm:
                    sup = (mm.group(1), mm.group(2))
                    rest = rest[:mm.start()]
                if rest.startswith(' — '):
                    note = rest[3:]
                elif rest.strip() != '':
                    self.block(self.S['MIGRATE_LAYOUT_B_INDEX_LINE'] % (idx, no, l))
                    continue
                entries.append({'date': m.group(1), 'clave': bool(m.group(2)), 'title': m.group(3),
                                'rel': m.group(4), 'note': note or None, 'sup': sup, 'no': no, 'raw': l})
            elif ENTRY_LIKE_RE.match(l) or INDEX_LINK_RE.search(l):
                close()
                self.block(self.S['MIGRATE_LAYOUT_B_INDEX_LINE'] % (idx, no, l))
            elif l.startswith('# ') and not titled and not entries and not chunks and not cur:
                titled = True
            elif l in self.STD_SUBTITLES:
                close()
            else:
                cur.extend(pending)
                pending[:] = []
                cur.append(raw)
        close()
        if chunks:
            self.index_prose[idx] = ['\n'.join(c) for c in chunks]
        return entries

    def step6(self):
        idxs = []
        for ws in self.workspaces():
            for f in ('decisions.md', 'learnings.md'):
                if posixpath.join(ws, f) in self.kind:
                    idxs.append(posixpath.join(ws, f))
            for node in self.nodes(ws):
                if posixpath.join(node, 'decisions.md') in self.kind:
                    idxs.append(posixpath.join(node, 'decisions.md'))
        pending = {}
        order = []
        all_entries = []
        for idx in idxs:
            for e in self.parse_index(idx):
                tgt = posixpath.normpath(posixpath.join(posixpath.dirname(idx), e['rel']))
                if tgt not in self.kind or self.kind[tgt] != 'f':
                    self.block(self.S['MIGRATE_LAYOUT_B_INDEX_LINE'] % (idx, e['no'], e['raw']))
                    continue
                text = self.text(tgt)
                try:
                    have = fm_dict(text)
                except Unreadable:
                    have = None
                if have is None:
                    self.block(self.S['MIGRATE_LAYOUT_B_FM'] % tgt)
                    continue
                want = {}
                if 'date' not in have:
                    want['date'] = e['date']
                if e['clave'] and 'key' not in have:
                    want['key'] = 'true'
                if 'title' not in have and e['title'] != body_title(text):
                    want['title'] = e['title']
                if e['note'] and 'index_note' not in have:
                    want['index_note'] = e['note']
                if e['sup'] and 'superseded_by' not in have:
                    want['superseded_by'] = posixpath.normpath(posixpath.join(posixpath.dirname(idx), e['sup'][1]))
                cur = pending.setdefault(tgt, {})
                if tgt not in order:
                    order.append(tgt)
                for k, v in want.items():
                    if k in cur and cur[k] != v:
                        self.block(self.S['MIGRATE_LAYOUT_B_INDEX_DISAGREE'] % (tgt, k))
                    cur.setdefault(k, v)
                all_entries.append((tgt, e, have))
        for tgt in order:
            adds = [(k, v) for k, v in pending[tgt].items()]
            if adds:
                self.put(tgt, add_fm_keys(self.text(tgt), adds), 6, ', '.join(k for k, _ in adds))
        for tgt, e, have in all_entries:
            text = self.text(tgt)
            fmv = fm_dict(text) or {}
            ok = True
            if 'date' not in have and fmv.get('date') != e['date']:
                ok = False
            if e['clave'] and 'key' not in fmv:
                ok = False
            if 'title' not in have and (fmv.get('title') or body_title(text)) != e['title']:
                ok = False
            if e['note'] and 'index_note' not in have and fmv.get('index_note') != e['note']:
                ok = False
            if e['sup'] and 'superseded_by' not in have and 'superseded_by' not in fmv:
                ok = False
            if not ok:
                self.block(self.S['MIGRATE_LAYOUT_B_INDEX_LINE'] % (tgt, e['no'], e['raw']))
        if self.blockers:
            return
        for idx in idxs:
            if idx in self.index_prose:
                notes = posixpath.join(posixpath.dirname(idx), 'legacy-%s-notes.md' % posixpath.basename(idx)[:-3])
                if notes in self.kind:
                    self.block(self.S['MIGRATE_LAYOUT_B_EXISTS'] % (notes, idx))
                else:
                    self.put(notes, '\n\n'.join(self.index_prose[idx]) + '\n', 6, '', origin=idx)
        if self.blockers:
            return
        for idx in idxs:
            base = posixpath.basename(idx)
            d = posixpath.dirname(idx)
            if d.count('/') == 1:
                gen = posixpath.join(d, base[:-3], 'index.md')
                self.fmap[idx] = gen
                self.delete(idx, 6, self.S['MIGRATE_LAYOUT_D_INDEX'])
            else:
                self.fmap[idx] = posixpath.join(d, 'index.md')

    # step 7 · no backlog outside an initiative (C31)
    def step7(self):
        # Only a regular file is a backlog the migration splits: a symbolic link named backlog.md is listed as
        # not moved, and never read or counted (its target, if it is a backlog, is counted where it lives).
        strays = []
        for ws in self.workspaces():
            for node in [None] + self.nodes(ws):
                p = (node or ws) + '/backlog.md'
                if self.kind.get(p) == 'f':
                    strays.append((ws, node, p))
                elif self.kind.get(p) == 'l':
                    self.unk(p, self.S['MIGRATE_LAYOUT_R_LINKED_BACKLOG'])
        if not strays:
            return
        # A task id already used by two tasks is a numbering collision of the brain's history: the migration
        # never renumbers, so it is a warning of the plan, one line per id with its backlogs, and never a stop.
        # What the migration must never do is create one: every block moves once, and the count of each id
        # after step 7 is checked against the count before it.
        before = self.task_id_counts()
        files = {}
        for p in self.kind:
            if self.kind[p] != 'f':
                continue
            if p.endswith('/backlog.md') or p == 'backlog.md':
                if p.startswith(self.wsdir + '/') or p == 'backlog.md':
                    for line in self.text(p).split('\n'):
                        if is_task(line):
                            tid, _ = parse_task(line)
                            if tid:
                                files.setdefault(tid, set()).add(p)
        stray_paths = set(s[2] for s in strays)
        for tid in sorted(before):
            if before[tid] > 1 and files.get(tid, set()) & stray_paths:
                self.warnings.append(self.S['MIGRATE_LAYOUT_W_DUP_ID'] % (tid, ', '.join(sorted(files[tid]))))
        self.recv = {}
        self.intro = set()
        for lg in ('en', 'es'):
            cat = load_strings(ENV['OS_ML_STRINGS'], lg)
            for l in cat.get('BACKLOG_INTRO', '').split('\n'):
                self.intro.add(l.rstrip())
        for ws, node, path in strays:
            self.split_backlog(ws, node, path)
        after = self.task_id_counts()
        for tid in sorted(after):
            if after[tid] > before.get(tid, 0):
                self.block(self.S['MIGRATE_LAYOUT_B_DUP_CREATED'] % (tid, before.get(tid, 0), after[tid]))

    def task_id_counts(self):
        """How many task lines carry each id, over every backlog.md of the walk (as the model stands now)."""
        n = {}
        for p in self.kind:
            if posixpath.basename(p) == 'backlog.md' and self.kind[p] == 'f':
                for line in self.text(p).split('\n'):
                    if is_task(line.lstrip(' ')):
                        tid, _ = parse_task(line.lstrip(' '))
                        if tid:
                            n[tid] = n.get(tid, 0) + 1
        return n

    def ini_title(self, head):
        t = ''
        if head in self.kind:
            try:
                t = body_title(self.text(head))
            except Unreadable:
                t = ''
        return t

    def paren_target(self, ws, texto, inits):
        if not texto.startswith('(') or ')' not in texto:
            return None
        cand = texto[1:].split(')', 1)[0]
        if cand in inits:
            return cand
        hits = [s for s, h in inits.items() if self.ini_title(h) == cand]
        return hits[0] if len(hits) == 1 else None

    def receiving(self, ws, node):
        key = (ws, node)
        if key in self.recv:
            return self.recv[key]
        S = self.S
        inits = self.initiatives(ws)
        if node:
            name = posixpath.basename(node)
            nh = self.node_head(node)
            cands = []
            for s, h in inits.items():
                d = fm_dict(self.text(h)) or {}
                if d.get('status') == 'ongoing' and about_is_single(d.get('about', ''), nh):
                    cands.append(s)
            if len(cands) > 1:
                self.block(S['MIGRATE_LAYOUT_B_INI_TWO'] % (node, ', '.join(sorted(cands))))
                self.recv[key] = None
                return None
            if len(cands) == 1:
                self.recv[key] = cands[0]
                return cands[0]
            if name in inits or posixpath.join(ws, 'initiatives', name) in self.dirs:
                self.block(S['MIGRATE_LAYOUT_B_INI_TAKEN'] % (name, node))
                self.recv[key] = None
                return None
            head = self.ini_head_path(ws, name)
            title = ''
            if nh in self.kind:
                try:
                    title = body_title(self.text(nh))
                except Unreadable:
                    title = ''
            self.put(head, render_ini(title or name, 'ongoing', nh), 7, '')
            self.recv[key] = name
            return name
        slug = 'tasks-to-sort'
        if slug in inits:
            d = fm_dict(self.text(inits[slug])) or {}
            if d.get('about'):
                self.block(S['MIGRATE_LAYOUT_B_INI_TAKEN'] % (slug, ws))
                self.recv[key] = None
                return None
            self.recv[key] = slug
            return slug
        if posixpath.join(ws, 'initiatives', slug) in self.dirs:
            self.block(S['MIGRATE_LAYOUT_B_INI_TAKEN'] % (slug, ws))
            self.recv[key] = None
            return None
        head = self.ini_head_path(ws, slug)
        self.put(head, render_ini(S['TASKS_TO_SORT_TITLE'], 'active', ''), 7, '')
        self.recv[key] = slug
        return slug

    def backlog_header(self, title):
        return '# %s %s\n\n%s\n\n' % (self.S['BACKLOG_TITLE'], title, self.S['BACKLOG_INTRO'])

    def append_tasks(self, ws, slug, blocks, origin):
        bl = posixpath.join(ws, 'initiatives', slug, 'backlog.md')
        add = ''.join(l + '\n' for blk in blocks for l in blk)
        if bl in self.kind:
            cur = self.text(bl)
            if cur and not cur.endswith('\n'):
                cur += '\n'
        else:
            head = self.initiatives(ws).get(slug)
            title = self.ini_title(head) if head else ''
            cur = self.backlog_header(title or slug)
        new = cur + add
        self.put(bl, new, 7, '')
        if bl not in self.origin:
            self.origin[bl] = bl
        # Provenance is the range of lines this append wrote, recorded here: never recovered later by matching
        # task text, which an identical task already in the destination would steal.
        first = cur.count('\n')
        self.prov.setdefault(bl, []).append((first, add.count('\n'), posixpath.dirname(origin)))
        got = self.text(bl)
        for blk in blocks:
            if '\n'.join(blk) + '\n' not in got:
                self.block(self.S['MIGRATE_LAYOUT_B_TASK_LOST'] % blk[0])

    def split_backlog(self, ws, node, path):
        lines = self.text(path).split('\n')
        if lines and lines[-1] == '':
            lines.pop()
        blocks = []
        notes = []
        title_seen = False
        owner_of = [None] * len(lines)
        i, n = 0, len(lines)
        while i < n:
            l = lines[i]
            if is_task(l):
                # the task, and everything indented that follows it, blank lines inside included
                end = i
                j = i + 1
                while j < n:
                    if lines[j].strip() == '':
                        j += 1
                    elif lines[j][:1] in (' ', '\t'):
                        end = j
                        j += 1
                    else:
                        break
                blocks.append(lines[i:end + 1])
                for t in range(i, end + 1):
                    owner_of[t] = 'block'
                i = end + 1
                continue
            if l.strip() == '':
                i += 1
                continue
            if l.startswith('# ') and not title_seen:
                title_seen = True
                owner_of[i] = 'title'
                i += 1
                continue
            if l.rstrip() in self.intro:
                owner_of[i] = 'intro'
                i += 1
                continue
            notes.append(l)
            owner_of[i] = 'note'
            i += 1
        # every line that says something belongs to exactly one place before the file can go
        for t, l in enumerate(lines):
            if l.strip() != '' and owner_of[t] is None:
                self.block(self.S['MIGRATE_LAYOUT_B_TASK_LOST'] % l)
        inits = self.initiatives(ws)
        routed = {}
        loose = []
        for blk in blocks:
            _, texto = parse_task(blk[0])
            tgt = self.paren_target(ws, texto, inits)
            if tgt:
                routed.setdefault(tgt, []).append(blk)
            else:
                loose.append(blk)
        for slug in sorted(routed):
            self.append_tasks(ws, slug, routed[slug], path)
        if loose or notes:
            slug = self.receiving(ws, node)
            if slug is None:
                return
            if loose:
                self.append_tasks(ws, slug, loose, path)
            if notes:
                np_ = posixpath.join(ws, 'initiatives', slug, 'legacy-backlog-notes.md')
                if np_ in self.kind:
                    self.block(self.S['MIGRATE_LAYOUT_B_EXISTS'] % (np_, path))
                else:
                    self.put(np_, '\n'.join(notes) + '\n', 7, '', origin=path)
        self.delete(path, 7, self.S['MIGRATE_LAYOUT_D_BACKLOG'])

    # step 8 · the decisions of a node go to the workspace
    def step8(self):
        for ws in self.workspaces():
            for node in self.nodes(ws):
                nh = self.node_head(node)
                dd = node + '/decisions'
                if self.is_dir(dd):
                    for p in self.files_under(dd):
                        dst = posixpath.join(ws, 'decisions', posixpath.basename(p))
                        if self.mv(p, dst, 8) and dst.endswith('.md'):
                            text = self.text(dst)
                            have = fm_dict(text)
                            if have is None:
                                self.block(self.S['MIGRATE_LAYOUT_B_FM'] % dst)
                            elif 'about' not in have:
                                self.put(dst, add_fm_keys(text, [('about', nh)]), 8, 'about')
                    self.dirmap[dd] = posixpath.join(ws, 'decisions')
                if node + '/decisions.md' in self.kind:
                    self.delete(node + '/decisions.md', 8, self.S['MIGRATE_LAYOUT_D_INDEX'])

    # step 9 · resolvers become hidden
    def rows(self, text):
        ls = [l for l in text.split('\n') if l.lstrip().startswith('|')]
        sep = [i for i, l in enumerate(ls) if re.match(r'^\s*\|[\s:|-]+\|?\s*$', l)]
        heads = set(i - 1 for i in sep if i > 0)
        return len([i for i in range(len(ls)) if i not in sep and i not in heads])

    def step9(self):
        for ws in self.workspaces():
            self.mv(ws + '/resolver.md', ws + '/.resolver.md', 9)
            for node in self.nodes(ws):
                r = node + '/resolver.md'
                if r not in self.kind:
                    continue
                if self.rows(self.text(r)) == 0:
                    self.delete(r, 9, self.S['MIGRATE_LAYOUT_D_RESOLVER'])
                else:
                    self.mv(r, node + '/.resolver.md', 9)

    # step 10 · resources and context
    def step10(self):
        for ws in self.workspaces():
            for f in ('voice.md', 'visual-style.md'):
                self.mv(posixpath.join(ws, f), posixpath.join(ws, 'resources', f), 10)
            vd = ws + '/voice'
            if self.is_dir(vd):
                for p in self.files_under(vd):
                    self.mv(p, posixpath.join(ws, 'resources', p[len(ws) + 1:]), 10)
                self.dirmap[vd] = ws + '/resources/voice'
            for f in ('glossary.md', 'context-map.md'):
                self.mv(posixpath.join(ws, f), posixpath.join(ws, 'context', f), 10)
            for node in self.nodes(ws):
                md = node + '/material'
                if self.is_dir(md):
                    for p in self.files_under(md):
                        self.mv(p, node + '/resources/' + p[len(md) + 1:], 10)
                    self.dirmap[md] = node + '/resources'

    # step 11 · every link, once, from the fixed map
    def fix_symlinks(self):
        """A relative symlink that moved, or whose target moved, is recomputed against the mapped target."""
        for p in sorted(p for p, k in self.kind.items() if k == 'l'):
            o = self.origin.get(p, p)
            if o not in self.old_target:
                continue
            t = self.old_target[o]
            absolute = t.startswith('/')
            if absolute:
                root = self.brain.rstrip('/') + '/'
                if not t.startswith(root):
                    continue
                old_abs = posixpath.normpath(t[len(root):])
            else:
                old_abs = posixpath.normpath(posixpath.join(posixpath.dirname(o), t))
            if old_abs.startswith('..') or not (old_abs in self.old_kind or old_abs in self.old_dirs):
                continue
            T = self.map_path(old_abs) or old_abs
            new = (self.brain.rstrip('/') + '/' + T) if absolute else posixpath.relpath(T, posixpath.dirname(p) or '.')
            if new != self.target[p]:
                self.delete(p, 11, self.S['MIGRATE_LAYOUT_D_RELINK'])
                self.link(p, new, 11)

    def step11(self):
        if self.blockers:
            return
        self.fix_symlinks()
        for p in sorted(self.kind):
            if not p.endswith('.md') or self.kind[p] != 'f' or p == '.system/tree.md':
                continue
            if p not in self.origin:
                continue
            o = self.origin[p]
            text = self.text(p)
            lines = text.split('\n')
            dirs = None
            if p in self.prov:
                dirs = [posixpath.dirname(o)] * len(lines)
                for first, count, odir in self.prov[p]:
                    for t in range(first, min(first + count, len(lines))):
                        dirs[t] = odir
            new, n = self.rewrite_text(text, posixpath.dirname(o), posixpath.dirname(p), dirs)
            if n and new != text:
                self.put(p, new, 11, self.S['MIGRATE_LAYOUT_N_LINKS'] % n)

    # step 12 · tree.md, last
    def tree_map(self, pat):
        """Where a tree declaration goes through the move map: the new pattern, 'drop' when what it reached is
        deleted, or None when the migration does not touch what it reaches."""
        segs = pat.split('/')
        n = len(segs)
        root = {'operator.md': 'account/operator.md', 'voice.md': 'account/voice/voice.md',
                'tree.md': '.system/tree.md', 'resolver.md': '.system/resolver.md',
                'mounts.md': '.system/mounts.md', 'COMO-FUNCIONA.md': 'HOW-IT-WORKS.md'}
        if segs[0] != self.wsdir:
            if pat in root:
                return root[pat]
            if segs[0] == 'voice' and n > 1:
                return 'account/' + pat
            return None
        if n < 3:
            return None
        ws = segs[:2]
        rest = segs[2:]
        if len(rest) == 1:
            f = rest[0]
            if f == 'resolver.md':
                return '/'.join(ws + ['.resolver.md'])
            if f in ('decisions.md', 'learnings.md', 'backlog.md'):
                return 'drop'
            if f in ('voice.md', 'visual-style.md'):
                return '/'.join(ws + ['resources', f])
            if f in ('glossary.md', 'context-map.md'):
                return '/'.join(ws + ['context', f])
            return None
        if rest[0] == 'voice':
            return '/'.join(ws + ['resources'] + rest)
        if len(rest) >= 3 and rest[0] in self.types:
            node = ws + rest[:2]
            r2 = rest[2:]
            if r2 == ['resolver.md']:
                return '/'.join(node + ['.resolver.md'])
            if r2 in (['decisions.md'], ['backlog.md']):
                return 'drop'
            if r2[0] == 'material' and len(r2) > 1:
                return '/'.join(node + ['resources'] + r2[1:])
            if r2[0] == 'decisions':
                return '/'.join(ws + ['decisions', r2[1]]) if len(r2) == 2 else 'drop'
        return None

    @staticmethod
    def glob_match(pat, path):
        a, b = pat.split('/'), path.split('/')
        return len(a) == len(b) and all(fnmatch.fnmatchcase(y, x) for x, y in zip(a, b))

    def step12(self):
        if self.blockers:
            return
        tp = '.system/tree.md'
        if tp not in self.kind:
            self.block(self.S['MIGRATE_LAYOUT_B_NO_TREE'])
            return
        text = self.text(tp)
        lines = text.split('\n')
        unmoved = [p for p in self.kind if self.origin.get(p, p) == p and p not in self.created]
        out = []
        removed = 0
        for l in lines:
            m = re.match(r'^(glob|content|archive):\s*(.*?)\s*$', l)
            if not m:
                out.append(l)
                continue
            r = self.tree_map(m.group(2))
            if r is None:
                out.append(l)
                continue
            # what the pattern still reaches where it is keeps the declaration; what moved gets it transformed
            if any(self.glob_match(m.group(2), p) for p in unmoved):
                out.append(l)
            else:
                removed += 1
            if r != 'drop':
                out.append('%s: %s' % (m.group(1), r))
        keep = []
        seen = set()
        for l in out:
            m = re.match(r'^(glob|content|archive):\s*(.*?)\s*$', l)
            if m:
                key = '%s: %s' % (m.group(1), m.group(2))
                if key in seen:
                    continue
                seen.add(key)
            keep.append(l)
        have = seen
        tpl = os.path.join(self.core, 'templates', 'tree.md')
        add = []
        with open(tpl, encoding='utf-8') as f:
            for l in f.read().split('\n'):
                m = re.match(r'^(glob|content|archive):\s*(.*?)\s*$', l)
                if not m:
                    continue
                pat = m.group(2).replace('{{MANUAL}}', 'HOW-IT-WORKS.md')
                if pat.startswith('workspaces/'):
                    pat = self.wsdir + pat[len('workspaces'):]
                line = '%s: %s' % (m.group(1), pat)
                if self.tree_map(pat) is not None:
                    continue
                if pat.endswith('/README.md') and self.head != 'README.md':
                    continue
                if line not in have:
                    have.add(line)
                    add.append(line)
        # The notes the migration keeps from a hand-written index (`legacy-<index>-notes.md`, step 6) sit next to
        # the generated index, where no line of the template reaches: each kind gets one `content:` line, with
        # the workspace and the node as `*`, unless a line already reaches it.
        for p in sorted(self.kind):
            if not re.match(r'^legacy-(decisions|learnings)-notes\.md$', posixpath.basename(p)):
                continue
            if '/initiatives/' in p or not p.startswith(self.wsdir + '/'):
                continue
            reached = False
            for l in keep + add:
                m = re.match(r'^(glob|content|archive):\s*(.*?)\s*$', l)
                if m and self.glob_match(m.group(2), p):
                    reached = True
                    break
            if reached:
                continue
            seg = p.split('/')
            seg[1] = '*'
            if len(seg) == 5:
                seg[3] = '*'
            line = 'content: ' + '/'.join(seg)
            if line not in have:
                have.add(line)
                add.append(line)
        new = '\n'.join(keep)
        while new.endswith('\n\n'):
            new = new[:-1]
        if not new.endswith('\n'):
            new += '\n'
        new += ''.join(l + '\n' for l in add)
        if new == text:
            return
        self.put(tp, new, 12, self.S['MIGRATE_LAYOUT_N_TREE'] % (removed, len(add)))

    def prune(self):
        dirs = set()
        for op in self.ops:
            for k in ('src', 'path'):
                p = op.get(k)
                if p and op['op'] in ('move', 'delete'):
                    d = posixpath.dirname(p)
                    while d:
                        dirs.add(d)
                        d = posixpath.dirname(d)
        empty = []
        for d in sorted(dirs, key=lambda x: -x.count('/')):
            pre = d + '/'
            if not any(k.startswith(pre) for k in self.kind):
                empty.append(d)
        if empty:
            self.rec(12, 'prune', dirs=empty)


# ---------------------------------------------------------------- printing the plan
def op_lines(S, op):
    k = op['op']
    if k == 'move':
        return ['%s %s → %s' % (S['MIGRATE_LAYOUT_V_MOVE'], op['src'], op['dst'])]
    if k == 'put':
        if op['before'] is None:
            return ['%s %s' % (S['MIGRATE_LAYOUT_V_CREATE'], op['path'])]
        d = ' (%s)' % op['detail'] if op.get('detail') else ''
        out = ['%s %s%s' % (S['MIGRATE_LAYOUT_V_REWRITE'], op['path'], d)]
        for l in op.get('adopt_lines', []):
            out.append('%s %s' % (S['MIGRATE_LAYOUT_V_ADOPT'], l))
        return out
    if k == 'delete':
        d = ' (%s)' % op['detail'] if op.get('detail') else ''
        return ['%s %s%s' % (S['MIGRATE_LAYOUT_V_DELETE'], op['path'], d)]
    if k == 'link':
        return ['%s %s → %s' % (S['MIGRATE_LAYOUT_V_LINK'], op['path'], op['target'])]
    return []


def print_plan(S, ops, unknown, header=True):
    n = len([o for o in ops if o['op'] != 'prune'])
    if header:
        print(S['MIGRATE_LAYOUT_PLAN_HEAD'] % n)
    last = None
    for op in ops:
        ls = op_lines(S, op)
        if not ls:
            continue
        if op['step'] != last:
            last = op['step']
            print(S['MIGRATE_LAYOUT_STEP_%d' % last])
        for l in ls:
            print('  ' + l)
    if unknown:
        print(S['MIGRATE_LAYOUT_UNKNOWN_HEAD'])
        for path, reason in unknown:
            print('  %s · %s%s' % (S['MIGRATE_LAYOUT_V_UNKNOWN'], path, ' (%s)' % reason if reason else ''))


# ---------------------------------------------------------------- applying the plan
class Runner:
    def __init__(self, brain, S, ops, core):
        self.brain = brain
        self.S = S
        self.ops = ops
        self.core = core
        self.core_claude = os.path.join(os.path.realpath(core), 'CLAUDE.md')
        self.plan_file = os.path.join(brain, PLAN_REL)
        self.blobs = os.path.join(brain, BLOB_REL)
        self.counts = {}
        hook = ENV.get('OS_MIGRATE_LAYOUT_INTERRUPT_AFTER', '')
        self.hook = None
        if hook and ':' in hook:
            k, n = hook.rsplit(':', 1)
            self.hook = (k, int(n))

    def cur(self, path):
        full = os.path.join(self.brain, path)
        if os.path.islink(full):
            return 'L:' + os.readlink(full)
        if os.path.isfile(full):
            with open(full, 'rb') as f:
                return sha(f.read())
        if os.path.exists(full):
            return 'D'
        return None

    def state(self, op):
        k = op['op']
        if k == 'move':
            s, d = self.cur(op['src']), self.cur(op['dst'])
            if s is None and d == op['fp']:
                return 'done'
            if s == op['fp'] and (d is None or d == op['fp']):
                return 'pending'
            return 'foreign'
        if k == 'put':
            c = self.cur(op['path'])
            if c == op['after']:
                return 'done'
            if c == op['before']:
                return 'pending'
            return 'foreign'
        if k == 'delete':
            c = self.cur(op['path'])
            if c is None:
                return 'done'
            return 'pending' if c == op['fp'] else 'foreign'
        if k == 'link':
            c = self.cur(op['path'])
            if c == 'L:' + op['target']:
                return 'done'
            return 'pending' if c is None else 'foreign'
        return 'pending'

    def guard(self, rel):
        """Refuse to write under a symlink or a file standing where a directory should be."""
        d = posixpath.dirname(rel)
        parts = []
        while d:
            parts.append(d)
            d = posixpath.dirname(d)
        for a in reversed(parts):
            full = os.path.join(self.brain, a)
            if os.path.islink(full) or (os.path.lexists(full) and not os.path.isdir(full)):
                raise RuntimeError('unsafe destination ancestor: ' + a)

    def execute(self, op):
        k = op['op']
        b = self.brain
        if k == 'move':
            src, dst = os.path.join(b, op['src']), os.path.join(b, op['dst'])
            self.guard(op['dst'])
            if os.path.lexists(dst):
                os.remove(src)
            else:
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                os.rename(src, dst)
        elif k == 'put':
            path = os.path.join(b, op['path'])
            self.guard(op['path'])
            with open(os.path.join(self.blobs, op['after']), 'rb') as f:
                data = f.read()
            os.makedirs(os.path.dirname(path), exist_ok=True)
            mode = os.stat(path).st_mode & 0o7777 if os.path.isfile(path) else 0o644
            tmp = path + '.os-tmp'
            with open(tmp, 'wb') as f:
                f.write(data)
            os.chmod(tmp, mode)
            os.replace(tmp, path)
        elif k == 'delete':
            os.remove(os.path.join(b, op['path']))
        elif k == 'link':
            path = os.path.join(b, op['path'])
            self.guard(op['path'])
            os.makedirs(os.path.dirname(path), exist_ok=True)
            os.symlink(op['target'], path)
        elif k == 'prune':
            for d in op['dirs']:
                try:
                    os.rmdir(os.path.join(b, d))
                except OSError:
                    pass

    def mark(self, i):
        with open(self.plan_file, 'a') as f:
            f.write(json.dumps({'done': i}) + '\n')

    def preflight(self, done_n):
        """Resume check: nothing the plan has not yet touched may differ from what the plan fingerprinted."""
        bad = []
        first = done_n
        while first < len(self.ops) and self.ops[first]['op'] != 'prune' and self.state(self.ops[first]) == 'done':
            first += 1
        # Everything the completed operations left behind must still be as they left it.
        expected = {}
        for op in self.ops[:first]:
            k = op['op']
            if k == 'move':
                expected[op['src']] = None
                expected[op['dst']] = op['fp']
            elif k == 'put':
                expected[op['path']] = op['after']
            elif k == 'delete':
                expected[op['path']] = None
            elif k == 'link':
                expected[op['path']] = 'L:' + op['target']
        for path, fp in expected.items():
            if self.cur(path) != fp:
                bad.append(path)
        for op in self.ops[first:]:
            for path, fp in op.get('pre', []):
                if self.cur(path) != fp:
                    bad.append(path)
            for path in op.get('absent', []):
                if self.cur(path) is not None:
                    bad.append(path)
        return bad

    def run(self, done):
        S = self.S
        for op in self.ops:
            if op['i'] in done:
                continue
            st = self.state(op)
            if st == 'foreign':
                return 1, S['MIGRATE_LAYOUT_B_FOREIGN'] % (op.get('src') or op.get('path') or 'install')
            if st == 'pending':
                try:
                    self.execute(op)
                except Exception as ex:
                    return 1, S['MIGRATE_LAYOUT_B_OP_FAILED'] % (op.get('src') or op.get('path') or 'install', ex)
                if op['op'] != 'prune' and self.state(op) != 'done':
                    return 1, S['MIGRATE_LAYOUT_B_OP_FAILED'] % (op.get('src') or op.get('path') or 'install', 'result differs from the plan')
            self.mark(op['i'])
            if op['op'] != 'prune':
                for key in (op['op'], 'step%d' % op['step']):
                    self.counts[key] = self.counts.get(key, 0) + 1
                if self.hook and self.counts.get(self.hook[0], 0) >= self.hook[1]:
                    return 3, ''
        return 0, ''


def plan_paths(ops):
    s = set()
    for op in ops:
        for k in ('src', 'dst', 'path'):
            if op.get(k):
                s.add(op[k])
        for p in op.get('extra', []):
            s.add(p)
    return s


def git_changes(brain):
    if not os.path.exists(os.path.join(brain, '.git')):
        return []
    r = subprocess.run(['git', '-C', brain, 'status', '--porcelain', '-z', '--untracked-files=all'],
                       stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    parts = r.stdout.decode('utf-8', 'surrogateescape').split('\0')
    out = []
    i = 0
    while i < len(parts):
        e = parts[i]
        i += 1
        if len(e) < 4:
            continue
        xy, path = e[:2], e[3:]
        if xy[0] in 'RC':
            i += 1
        if xy == '??' and (path.startswith('.claude/') or path.startswith('.os/')):
            continue
        out.append(path)
    return out


def save_plan(brain, ops, unknown, lang):
    os.makedirs(os.path.join(brain, BLOB_REL), exist_ok=True)
    lines = [json.dumps({'v': 1, 'lang': lang, 'unknown': unknown})]
    for op in ops:
        o = dict(op)
        blob = o.pop('blob', None)
        if blob is not None:
            with open(os.path.join(brain, BLOB_REL, o['after']), 'wb') as f:
                f.write(blob)
        lines.append(json.dumps(o))
    tmp = os.path.join(brain, PLAN_REL + '.tmp')
    with open(tmp, 'w') as f:
        f.write('\n'.join(lines) + '\n')
    os.replace(tmp, os.path.join(brain, PLAN_REL))


def load_plan(brain):
    ops, done, unknown = [], set(), []
    with open(os.path.join(brain, PLAN_REL)) as f:
        for n, line in enumerate(f):
            line = line.strip()
            if not line:
                continue
            d = json.loads(line)
            if n == 0:
                unknown = d.get('unknown', [])
            elif 'done' in d:
                done.add(d['done'])
            else:
                ops.append(d)
    return ops, done, unknown


def cleanup(brain):
    import shutil
    try:
        os.remove(os.path.join(brain, PLAN_REL))
    except OSError:
        pass
    shutil.rmtree(os.path.join(brain, BLOB_REL), ignore_errors=True)


def stop(S, msgs):
    print(S['MIGRATE_LAYOUT_STOPPED'])
    for m in msgs:
        print('  ' + m)
    return 1


def main():
    brain = ENV['OS_ML_BRAIN']
    apply_ = ENV.get('OS_ML_APPLY') == '1'
    S = load_strings(ENV['OS_ML_STRINGS'], ENV['OS_ML_LANG'])
    core = ENV['OS_ML_CORE']
    plan_file = os.path.join(brain, PLAN_REL)
    if os.path.exists(plan_file):
        ops, done, unknown = load_plan(brain)
        n_done = 0
        while n_done in done:
            n_done += 1
        total = len([o for o in ops if o['op'] != 'prune'])
        runner = Runner(brain, S, ops, core)
        if not apply_:
            print(S['MIGRATE_LAYOUT_RESUME_PENDING'] % (n_done, len(ops)))
            print_plan(S, [o for o in ops if o['i'] >= n_done], unknown, header=False)
            return 0
        print(S['MIGRATE_LAYOUT_RESUME'] % (n_done, len(ops)))
        allowed = plan_paths(ops)
        foreign = [p for p in git_changes(brain) if p not in allowed]
        bad = runner.preflight(n_done)
        if foreign or bad:
            return stop(S, [S['MIGRATE_LAYOUT_B_FOREIGN'] % p for p in (foreign + bad)[:8]])
        rc, msg = runner.run(done)
        if rc == 1:
            return stop(S, [msg])
        if rc == 3:
            return 3
        cleanup(brain)
        print(S['MIGRATE_LAYOUT_DONE'] % total)
        return 0
    P = Planner(brain, S)
    P.plan()
    if not P.ops:
        print(S['MIGRATE_LAYOUT_NOTHING'])
        return 0
    print_plan(S, P.ops, P.unknown)
    if P.warnings:
        print(S['MIGRATE_LAYOUT_WARN_HEAD'])
        for w in P.warnings:
            print('  ' + w)
    if P.blockers:
        print(S['MIGRATE_LAYOUT_STOPPED'] if apply_ else S['MIGRATE_LAYOUT_WOULD_STOP'])
        for b in P.blockers:
            print('  ' + b)
        return 1 if apply_ else 0
    if not apply_:
        print(S['MIGRATE_LAYOUT_HINT'])
        return 0
    dirty = git_changes(brain)
    if dirty:
        return stop(S, [S['MIGRATE_LAYOUT_B_DIRTY'] % ', '.join(dirty[:5])])
    save_plan(brain, P.ops, P.unknown, ENV['OS_ML_LANG'])
    ops, done, unknown = load_plan(brain)
    runner = Runner(brain, S, ops, core)
    rc, msg = runner.run(done)
    if rc == 1:
        return stop(S, [msg])
    if rc == 3:
        return 3
    cleanup(brain)
    print(S['MIGRATE_LAYOUT_DONE'] % len([o for o in ops if o['op'] != 'prune']))
    return 0


if __name__ == '__main__':
    sys.exit(main())
