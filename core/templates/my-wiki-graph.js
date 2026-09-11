/* My Wiki's Graph screen (spec 061). Inlined verbatim into the page by `my_wiki_build.py`, in one
   <script id="wiki-graph"> block, right before `wiki-view` so `WIKIGRAPH` exists when the router
   first runs. No DOM is touched outside a function body, so this whole file loads and its pure
   half (WIKIGRAPH.neighbors/atDate/applyHide/view/radius/layout) runs the same way in a plain
   Node `vm` context as it does in the page — that pure half is what the suite exercises headless,
   the same pattern `wiki-core` set in spec 060. `WIKIGRAPH.mount` is the DOM half; nothing calls
   it outside a real page. */
var WIKIGRAPH = (function () {
  // One radius per kind, before its own connections grow it (spec 061 C1).
  var BASE_RADIUS = {workspace: 14, entity: 9, initiative: 7, person: 6, document: 4};
  var COLORS = {workspace: 'var(--text)', entity: 'var(--accent)', initiative: '#0f8b8d',
    person: '#d97706', document: 'var(--muted)'};
  var LEGEND_ORDER = ['workspace', 'entity', 'initiative', 'person', 'document'];

  function radius(kind, degree) {
    var base = BASE_RADIUS[kind] || 5;
    return base + Math.min(degree || 0, 12) * 0.5;
  }

  // Every neighbour of one node, from the edge list alone — what a hover highlights (C3).
  function neighbors(edges, id) {
    var seen = {}, out = [];
    for (var i = 0; i < edges.length; i++) {
      var e = edges[i], other = null;
      if (e.a === id) other = e.b;
      else if (e.b === id) other = e.a;
      if (other !== null && !seen[other]) { seen[other] = true; out.push(other); }
    }
    return out;
  }

  function edgesAmong(edges, ids) {
    return edges.filter(function (e) { return ids[e.a] && ids[e.b]; });
  }

  function scope(graph, ws) {
    if (!ws) return graph;
    var nodes = graph.nodes.filter(function (n) { return n.ws === ws; });
    var ids = {};
    nodes.forEach(function (n) { ids[n.id] = true; });
    return {nodes: nodes, edges: edgesAmong(graph.edges, ids), dates: graph.dates};
  }

  // Only what already existed at `date` — the state one tick of "how it grew" shows (C5). A node
  // with no known first commit is treated as always having been there, never hidden by a date it
  // does not carry.
  function atDate(graph, date) {
    if (!date) return graph;
    var ids = {};
    var nodes = graph.nodes.filter(function (n) {
      var ok = !n.first || n.first <= date;
      if (ok) ids[n.id] = true;
      return ok;
    });
    return {nodes: nodes, edges: edgesAmong(graph.edges, ids), dates: graph.dates};
  }

  // Hiding a type never recomputes anything about the rest (C4): it is a pure filter on top of
  // whatever scope/date already produced.
  function applyHide(graph, hide) {
    hide = hide || {};
    var nodes = graph.nodes.filter(function (n) { return !hide[n.kind]; });
    var ids = {};
    nodes.forEach(function (n) { ids[n.id] = true; });
    return {nodes: nodes, edges: edgesAmong(graph.edges, ids), dates: graph.dates};
  }

  // The one composition point every other filter goes through, headless-testable end to end.
  function view(graph, opts) {
    opts = opts || {};
    var g = scope(graph, opts.ws);
    g = atDate(g, opts.date);
    g = applyHide(g, opts.hide);
    return g;
  }

  // A minimal force layout: repulsion between every pair, a spring on every edge, a pull to the
  // centre so a page with no link at all still settles on the canvas instead of flying off it
  // (spec 061: an unlinked page shows loose and dim, never hidden). Fixed tick count, no timers,
  // no DOM — the same run in Node as in the page, which is how C7's 650-node budget is measured.
  function layout(graph, opts) {
    opts = opts || {};
    // 60 ticks is a compromise, not a perfect settle: spec 061's budget is 650 nodes drawn in
    // under 2 seconds, and a rough, organic scatter reads fine for a screen nobody stares at
    // pixel-perfect. More ticks converge tighter but blow the budget well before 650 nodes do.
    var w = opts.width || 760, h = opts.height || 520, ticks = opts.ticks || 60;
    var n = graph.nodes.length;
    var nodes = graph.nodes.map(function (node, i) {
      var a = n ? (i / n) * Math.PI * 2 : 0;
      return {
        id: node.id, kind: node.kind, degree: node.degree,
        x: w / 2 + Math.cos(a) * (Math.min(w, h) / 3),
        y: h / 2 + Math.sin(a) * (Math.min(w, h) / 3),
        vx: 0, vy: 0,
      };
    });
    var index = {};
    nodes.forEach(function (node, i) { index[node.id] = i; });
    var edges = [];
    for (var e = 0; e < graph.edges.length; e++) {
      var a = index[graph.edges[e].a], b = index[graph.edges[e].b];
      if (a !== undefined && b !== undefined) edges.push({a: a, b: b});
    }
    var REPEL = 2600, SPRING = 0.02, LEN = 70, CENTER = 0.012, DAMP = 0.85;
    for (var t = 0; t < ticks; t++) {
      for (var i = 0; i < nodes.length; i++) {
        var ni = nodes[i];
        for (var j = i + 1; j < nodes.length; j++) {
          var nj = nodes[j];
          var dx = ni.x - nj.x, dy = ni.y - nj.y;
          var d2 = dx * dx + dy * dy + 0.01;
          var f = REPEL / d2;
          var d = Math.sqrt(d2);
          var fx = (dx / d) * f, fy = (dy / d) * f;
          ni.vx += fx; ni.vy += fy;
          nj.vx -= fx; nj.vy -= fy;
        }
      }
      for (var k = 0; k < edges.length; k++) {
        var na = nodes[edges[k].a], nb = nodes[edges[k].b];
        var ex = nb.x - na.x, ey = nb.y - na.y;
        var ed = Math.sqrt(ex * ex + ey * ey) || 0.01;
        var stretch = (ed - LEN) * SPRING;
        var sfx = (ex / ed) * stretch, sfy = (ey / ed) * stretch;
        na.vx += sfx; na.vy += sfy;
        nb.vx -= sfx; nb.vy -= sfy;
      }
      for (var m = 0; m < nodes.length; m++) {
        var nm = nodes[m];
        nm.vx += (w / 2 - nm.x) * CENTER;
        nm.vy += (h / 2 - nm.y) * CENTER;
        nm.vx *= DAMP; nm.vy *= DAMP;
        nm.x += nm.vx; nm.y += nm.vy;
      }
    }
    return nodes;
  }

  return {
    COLORS: COLORS, LEGEND_ORDER: LEGEND_ORDER,
    radius: radius, neighbors: neighbors, scope: scope, atDate: atDate, applyHide: applyHide,
    view: view, layout: layout,
  };
})();
if (typeof module !== 'undefined' && module.exports) { module.exports = WIKIGRAPH; }

(function () {
  // The DOM half (spec 066): a <canvas> with its own force simulation, pan and zoom, drag, hover
  // highlight, click to open, filters and the time slider. Nothing loads from outside the page.
  function ensureStyle() {
    if (typeof document === 'undefined' || document.getElementById('wiki-graph-style')) return;
    var css =
      '.graph-legend{display:flex;gap:14px;margin-bottom:10px;flex-wrap:wrap;font-size:13px;color:var(--text);align-items:center}' +
      '.graph-legend .sw{width:10px;height:10px;border-radius:999px;display:inline-block;margin-right:6px}' +
      '.graph-filters{margin-left:auto;display:flex;gap:8px}' +
      '.graph-filters .chip{cursor:pointer;user-select:none}' +
      '.graph-wrap{border:1px solid var(--border);background:var(--card);border-radius:12px;overflow:hidden;position:relative}' +
      '.graph-wrap canvas{display:block;width:100%;cursor:grab}' +
      '.graph-wrap canvas.grabbing{cursor:grabbing}' +
      '.graph-hint{position:absolute;right:10px;bottom:8px;font-size:11.5px;color:var(--muted);pointer-events:none}' +
      '.graph-slider-row{display:flex;align-items:center;gap:12px;margin-top:12px}' +
      '.graph-slider-row input[type=range]{flex:1;accent-color:var(--accent)}' +
      '.graph-date{font-family:ui-monospace,Menlo,monospace;font-size:12.5px;color:var(--muted);min-width:86px;text-align:right}';
    var styleTag = document.createElement('style');
    styleTag.id = 'wiki-graph-style';
    styleTag.textContent = css;
    document.head.appendChild(styleTag);
  }
  function esc(s) {
    return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }
  function cssVar(name, fallback) {
    try { var v = getComputedStyle(document.documentElement).getPropertyValue(name).trim(); return v || fallback; } catch (e) { return fallback; }
  }
  function hexA(hex, a) {
    var m = /^#([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i.exec(hex || '');
    if (!m) return hex;
    return 'rgba(' + parseInt(m[1], 16) + ',' + parseInt(m[2], 16) + ',' + parseInt(m[3], 16) + ',' + a + ')';
  }

  // What survives between visits to the screen inside one visit to the page: the camera, the
  // filters, the date, and where the reader left the nodes.
  var keep = {};

  WIKIGRAPH.mount = function (root, DATA, T, href, opts) {
    ensureStyle();
    opts = opts || {};
    var full = DATA.graph || {nodes: [], edges: [], dates: []};
    // The builder's edges are the explicit links (about:, paths in backticks, people). The graph
    // also needs the structure the brain already has —a document hangs from its node, an
    // initiative from its entity, an entity from its workspace— or most pages float alone.
    if (!full._structured) {
      var seen = {}; full.edges.forEach(function (e) { seen[e.a + '|' + e.b] = 1; seen[e.b + '|' + e.a] = 1; });
      var homes = {}; (DATA.workspaces || []).forEach(function (w) { homes[w.slug] = w.home; });
      function link(a, b) { if (!a || !b || a === b || seen[a + '|' + b]) return; seen[a + '|' + b] = 1; seen[b + '|' + a] = 1; full.edges.push({a: a, b: b, structural: true}); }
      var pages = DATA.pages || {};
      for (var id in pages) {
        var pg = pages[id];
        // The builder keeps the tree on the node: `docs` are the documents that hang from it,
        // `children` its initiatives, `about` the entity an initiative belongs to.
        (pg.docs || []).forEach(function (d) { var dp = d && (d.path || d); if (pages[dp]) link(dp, id); });
        (pg.children || []).forEach(function (c) { if (pages[c]) link(c, id); });
        if (pg.kind === 'initiative') {
          var ent = pg.about || (pg.fm && pg.fm.about) || '';
          ent = String(ent).replace(/^\.?\/?/, '');
          if (ent && pages[ent]) link(id, ent); else if (homes[pg.ws]) link(id, homes[pg.ws]);
        } else if ((pg.kind === 'entity' || pg.kind === 'person') && homes[pg.ws]) link(id, homes[pg.ws]);
      }
      var deg = {}; full.edges.forEach(function (e) { deg[e.a] = (deg[e.a] || 0) + 1; deg[e.b] = (deg[e.b] || 0) + 1; });
      full.nodes.forEach(function (n) { n.degree = deg[n.id] || 0; });
      full._structured = true;
    }
    var dates = full.dates || [];
    var k = keep[opts.ws] || (keep[opts.ws] = {hide: {document: true, person: false}, labels: false, dateIdx: dates.length ? dates.length - 1 : -1, cam: null, pos: {}});
    var state = {ws: opts.ws, hover: null, drag: null, playing: null, raf: null, alpha: 1};
    var COLORS = {workspace: cssVar('--text', '#1c1b22'), entity: cssVar('--accent', '#4b5563'), initiative: '#0f8b8d', person: '#d97706', document: cssVar('--muted', '#6b6a75')};

    root.innerHTML =
      '<div class="graph-legend">' +
      [['entity', T('WIKI_GRAPH_ENTITY', 'Entities')], ['initiative', T('WIKI_GRAPH_INITIATIVE', 'Initiatives')], ['person', T('WIKI_GRAPH_PERSON', 'People')], ['document', T('WIKI_GRAPH_DOCUMENT', 'Documents')]]
        .map(function (l) { return '<span><span class="sw" style="background:' + COLORS[l[0]] + '"></span>' + esc(l[1]) + '</span>'; }).join('') +
      '<span class="graph-filters">' +
      '<span class="chip' + (k.hide.document ? '' : ' vio') + '" data-hide="document">' + esc(T('WIKI_GRAPH_SHOW_DOCS', 'Show documents')) + '</span>' +
      '<span class="chip' + (k.hide.person ? '' : ' vio') + '" data-hide="person">' + esc(T('WIKI_GRAPH_SHOW_PEOPLE', 'Show people')) + '</span>' +
      '<label class="chip" style="cursor:pointer;gap:6px"><input type="checkbox" data-labels' + (k.labels ? ' checked' : '') + ' style="margin:0"> ' + esc(T('WIKI_GRAPH_LABELS', 'Labels')) + '</label>' +
      '</span></div>' +
      '<div class="graph-wrap"><canvas></canvas><div class="graph-hint">' + esc(T('WIKI_GRAPH_HINT', 'drag · wheel to zoom · double-click to fit · click opens')) + '</div></div>' +
      (dates.length ? '<div class="graph-slider-row"><span class="muted" style="font-size:13px">' + esc(T('WIKI_GRAPH_GREW', 'How it grew')) + '</span>' +
        '<input type="range" min="0" max="' + (dates.length - 1) + '" value="' + k.dateIdx + '">' +
        '<span class="graph-date"></span><button class="btn" data-play>' + esc(T('WIKI_GRAPH_PLAY', 'Play')) + '</button></div>' : '');

    var canvas = root.querySelector('canvas'), ctx = canvas.getContext('2d');
    var wrap = root.querySelector('.graph-wrap');
    var W = 0, H = 520, dpr = window.devicePixelRatio || 1;
    function size() {
      W = wrap.clientWidth || 760;
      canvas.width = W * dpr; canvas.height = H * dpr; canvas.style.height = H + 'px';
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    }
    size();

    // The graph on screen: the pure half filters by workspace, date and hidden kinds.
    var nodes = [], edges = [], byId = {}, adj = {};
    function rebuild(reheat) {
      var g = WIKIGRAPH.view(full, {ws: state.ws, date: k.dateIdx >= 0 ? dates[k.dateIdx] : null, hide: k.hide});
      var old = {}; nodes.forEach(function (n) { old[n.id] = n; });
      nodes = g.nodes.map(function (n) {
        var p = old[n.id] || k.pos[n.id];
        var r = WIKIGRAPH.radius(n.kind, n.degree) * 1.7;
        return {id: n.id, kind: n.kind, title: n.title, degree: n.degree, r: r,
          x: p ? p.x : (W / 2 + (Math.random() - .5) * W * .6), y: p ? p.y : (H / 2 + (Math.random() - .5) * H * .6),
          vx: 0, vy: 0, fx: p && p.fx != null ? p.fx : null, fy: p && p.fy != null ? p.fy : null};
      });
      byId = {}; nodes.forEach(function (n) { byId[n.id] = n; });
      edges = g.edges.filter(function (e) { return byId[e.a] && byId[e.b]; });
      adj = {}; edges.forEach(function (e) { (adj[e.a] = adj[e.a] || {})[e.b] = 1; (adj[e.b] = adj[e.b] || {})[e.a] = 1; });
      if (reheat) state.alpha = 1;
      if (!k.cam) fit(true);
      loop();
    }

    // Camera ------------------------------------------------------------------------
    function fit(silent) {
      if (!nodes.length) { k.cam = {x: 0, y: 0, s: 1}; return; }
      var minX = 1e9, minY = 1e9, maxX = -1e9, maxY = -1e9;
      nodes.forEach(function (n) { minX = Math.min(minX, n.x); maxX = Math.max(maxX, n.x); minY = Math.min(minY, n.y); maxY = Math.max(maxY, n.y); });
      var s = Math.min(2.2, Math.max(.2, .92 * Math.min(W / Math.max(1, maxX - minX + 80), H / Math.max(1, maxY - minY + 80))));
      k.cam = {s: s, x: W / 2 - s * (minX + maxX) / 2, y: H / 2 - s * (minY + maxY) / 2};
      if (!silent) draw();
    }
    function toWorld(px, py) { return {x: (px - k.cam.x) / k.cam.s, y: (py - k.cam.y) / k.cam.s}; }

    // Physics -----------------------------------------------------------------------
    // Repulsion between every pair (n² is fine for a few hundred nodes), links as springs, a soft
    // pull to the centre, velocity damping, and a temperature that cools until the graph sleeps.
    function tick() {
      var n = nodes.length; if (!n) return;
      var a = state.alpha;
      var k2 = 2600 * a;
      for (var i = 0; i < n; i++) {
        var p = nodes[i];
        for (var j = i + 1; j < n; j++) {
          var q = nodes[j];
          var dx = p.x - q.x, dy = p.y - q.y, d2 = dx * dx + dy * dy + 0.01;
          if (d2 > 90000) continue;
          var f = k2 / d2;
          var fx = dx * f, fy = dy * f;
          p.vx += fx; p.vy += fy; q.vx -= fx; q.vy -= fy;
        }
      }
      var springK = 0.02 * a + 0.002;
      for (var e = 0; e < edges.length; e++) {
        var s1 = byId[edges[e].a], s2 = byId[edges[e].b];
        var ddx = s2.x - s1.x, ddy = s2.y - s1.y, d = Math.sqrt(ddx * ddx + ddy * ddy) + 0.01;
        var rest = 34 + s1.r + s2.r;
        var f2 = (d - rest) * springK;
        var ux = ddx / d * f2, uy = ddy / d * f2;
        s1.vx += ux; s1.vy += uy; s2.vx -= ux; s2.vy -= uy;
      }
      var cx = 0, cy = 0; nodes.forEach(function (m) { cx += m.x; cy += m.y; }); cx /= n; cy /= n;
      nodes.forEach(function (m) {
        m.vx += (cx - m.x) * 0.0015 * a + (W / 2 - cx) * 0.0005;
        m.vy += (cy - m.y) * 0.0015 * a + (H / 2 - cy) * 0.0005;
        if (m.fx != null) { m.x = m.fx; m.y = m.fy; m.vx = 0; m.vy = 0; return; }
        m.vx *= 0.82; m.vy *= 0.82;
        m.x += m.vx; m.y += m.vy;
      });
      state.alpha = Math.max(0, a - 0.008);
    }
    function loop() {
      if (state.raf) return;
      var step = function () {
        state.raf = null;
        if (state.alpha > 0.003 || state.drag) { tick(); draw(); state.raf = requestAnimationFrame(step); }
        else { draw(); nodes.forEach(function (m) { k.pos[m.id] = {x: m.x, y: m.y, fx: m.fx, fy: m.fy}; }); }
      };
      state.raf = requestAnimationFrame(step);
    }

    // Drawing ----------------------------------------------------------------------
    function draw() {
      ctx.save(); ctx.clearRect(0, 0, W, H);
      ctx.translate(k.cam.x, k.cam.y); ctx.scale(k.cam.s, k.cam.s);
      var hov = state.hover, nb = hov ? (adj[hov] || {}) : null;
      var border = cssVar('--border', '#e5e5e8'), accent = cssVar('--accent', '#4b5563'), text = cssVar('--text', '#1c1b22');
      ctx.lineWidth = 1 / k.cam.s;
      edges.forEach(function (e) {
        var a = byId[e.a], b = byId[e.b];
        var hi = hov && (e.a === hov || e.b === hov);
        ctx.strokeStyle = hi ? accent : (e.structural ? border : accent);
        ctx.globalAlpha = hov ? (hi ? 1 : .15) : (e.structural ? .9 : .55);
        ctx.lineWidth = (hi ? 1.8 : 1) / k.cam.s;
        ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.stroke();
      });
      var labelOK = k.cam.s > 0.55;
      nodes.forEach(function (m) {
        var dim = hov && m.id !== hov && !nb[m.id];
        ctx.globalAlpha = dim ? .18 : 1;
        ctx.fillStyle = COLORS[m.kind] || COLORS.document;
        ctx.beginPath(); ctx.arc(m.x, m.y, m.r, 0, Math.PI * 2); ctx.fill();
        if (m.id === hov) { ctx.strokeStyle = accent; ctx.lineWidth = 2 / k.cam.s; ctx.beginPath(); ctx.arc(m.x, m.y, m.r + 4 / k.cam.s, 0, Math.PI * 2); ctx.stroke(); }
        var showLabel = m.id === hov || (nb && nb[m.id]) || (k.labels && !hov && (m.kind !== 'document' || (labelOK && k.cam.s > 1.1)));
        if (showLabel && (labelOK || m.id === hov || m.kind !== 'document')) {
          ctx.fillStyle = text; ctx.globalAlpha = dim ? .18 : (m.kind === 'document' ? .75 : 1);
          ctx.font = ((m.kind === 'entity' || m.kind === 'workspace' ? 13 : 11.5) / Math.max(k.cam.s, .8)) + 'px ' + cssVar('--font', 'system-ui');
          ctx.fillText(m.title, m.x + m.r + 4 / k.cam.s, m.y + 4 / k.cam.s);
        }
      });
      ctx.restore();
      var dl = root.querySelector('.graph-date'); if (dl) dl.textContent = k.dateIdx >= 0 ? dates[k.dateIdx] : '';
    }

    // Interaction ------------------------------------------------------------------
    function nodeAt(px, py) {
      var w = toWorld(px, py), best = null, bd = 1e9;
      nodes.forEach(function (m) { var dx = m.x - w.x, dy = m.y - w.y, d = dx * dx + dy * dy; var rr = (m.r + 6 / k.cam.s); if (d < rr * rr && d < bd) { bd = d; best = m; } });
      return best;
    }
    function pt(ev) { var r = canvas.getBoundingClientRect(); return {x: ev.clientX - r.left, y: ev.clientY - r.top}; }
    var pressed = null, moved = false;
    canvas.addEventListener('mousedown', function (ev) {
      var p = pt(ev), m = nodeAt(p.x, p.y);
      pressed = {x: p.x, y: p.y, node: m, cam: {x: k.cam.x, y: k.cam.y}}; moved = false;
      if (m) { state.drag = m; m.fx = m.x; m.fy = m.y; state.alpha = Math.max(state.alpha, .3); loop(); }
      canvas.classList.add('grabbing');
    });
    window.addEventListener('mousemove', function (ev) {
      var p = pt(ev);
      if (pressed) {
        if (Math.abs(p.x - pressed.x) + Math.abs(p.y - pressed.y) > 3) moved = true;
        if (pressed.node) { var w = toWorld(p.x, p.y); pressed.node.fx = w.x; pressed.node.fy = w.y; state.alpha = Math.max(state.alpha, .3); loop(); }
        else { k.cam.x = pressed.cam.x + (p.x - pressed.x); k.cam.y = pressed.cam.y + (p.y - pressed.y); draw(); }
        return;
      }
      var m = nodeAt(p.x, p.y), id = m ? m.id : null;
      if (id !== state.hover) { state.hover = id; canvas.style.cursor = m ? 'pointer' : 'grab'; draw(); }
    });
    window.addEventListener('mouseup', function (ev) {
      if (!pressed) return;
      var m = pressed.node;
      // A dropped node stays exactly where it was released — `fx`/`fy` keep pinning it, the same
      // way Obsidian's graph pins a node once dragged (spec 066 C1). It moves again only if
      // someone drags it again; nothing un-pins it on its own.
      if (m) { if (!moved) { location.hash = href(m.id); } state.drag = null; }
      pressed = null; canvas.classList.remove('grabbing'); loop();
    });
    canvas.addEventListener('wheel', function (ev) {
      ev.preventDefault();
      var p = pt(ev), w = toWorld(p.x, p.y);
      var s = Math.min(4, Math.max(.1, k.cam.s * (ev.deltaY < 0 ? 1.12 : 1 / 1.12)));
      k.cam = {s: s, x: p.x - w.x * s, y: p.y - w.y * s};
      draw();
    }, {passive: false});
    canvas.addEventListener('dblclick', function () { fit(); });
    canvas.addEventListener('mouseleave', function () { if (state.hover) { state.hover = null; draw(); } });

    Array.prototype.forEach.call(root.querySelectorAll('[data-hide]'), function (c) {
      c.onclick = function () { var kind = c.getAttribute('data-hide'); k.hide[kind] = !k.hide[kind]; c.classList.toggle('vio', !k.hide[kind]); rebuild(false); };
    });
    var lb = root.querySelector('[data-labels]');
    if (lb) lb.onchange = function () { k.labels = !!lb.checked; draw(); };
    var slider = root.querySelector('input[type=range]');
    if (slider) slider.oninput = function () { k.dateIdx = parseInt(slider.value, 10); rebuild(false); };
    var play = root.querySelector('[data-play]');
    if (play) play.onclick = function () {
      if (state.playing) { clearInterval(state.playing); state.playing = null; play.textContent = T('WIKI_GRAPH_PLAY', 'Play'); return; }
      k.dateIdx = 0; slider.value = 0; rebuild(true); play.textContent = T('WIKI_GRAPH_PAUSE', 'Pause');
      state.playing = setInterval(function () {
        if (k.dateIdx >= dates.length - 1) { clearInterval(state.playing); state.playing = null; play.textContent = T('WIKI_GRAPH_PLAY', 'Play'); return; }
        k.dateIdx++; slider.value = k.dateIdx; rebuild(false);
      }, 500);
    };
    window.addEventListener('resize', function () { size(); draw(); });

    rebuild(true);
    // `_debug` is read only by evals/fixtures/wiki-graph-headless.js (spec 066's `canvas` mode),
    // which has no browser to click and drag in. It exposes nothing a real caller uses.
    return {
      unmount: function () { if (state.playing) clearInterval(state.playing); },
      _debug: {
        nodes: function () { return nodes; },
        state: state,
        cam: function () { return k.cam; },
        hide: function () { return k.hide; },
        neighborsOf: function (id) { return Object.keys(adj[id] || {}); },
        colors: COLORS,
        edgeCount: function () { return edges.length; },
      },
    };
  };
})();
