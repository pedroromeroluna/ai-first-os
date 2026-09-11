/* Overview: what is waiting for the person, as the page's first screen (spec 062).

   It is its own block on purpose. `wiki-core` is the DOM-free logic the suite runs headlessly and
   `wiki-view` is the shell; this one is the first screen's view, and it exposes one function so
   the shell reaches it with a single line. Its icons live here too: the screen's four headings are
   the only place they are used, and the shell's own map stays as it was. */
var WIKI_OVERVIEW = (function () {
  var ICONS = {
    grid: '<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>',
    message: '<path d="M21 12a8 8 0 0 1-11 7.4L4 21l1.6-5A8 8 0 1 1 21 12z"/>',
    gate: '<path d="M4 22V4a1 1 0 0 1 1-1h11l-2 4 2 4H5"/>',
    clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
    calendar: '<rect x="3" y="4" width="18" height="17" rx="2"/><path d="M8 2v4M16 2v4M3 10h18"/>'
  };
  function svg(name, size) {
    return '<svg width="' + (size || 18) + '" height="' + (size || 18) + '" viewBox="0 0 24 24" ' +
      'fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" ' +
      'stroke-linejoin="round">' + (ICONS[name] || ICONS.grid) + '</svg>';
  }

  /* How long ago, with the word the catalog gives it. The number is the builder's; the unit it is
     counted in is a key, never a literal — the page speaks the brain's language. */
  function ago(T, age) {
    if (!age) return '';
    var word = age.unit === 'min' ? T('WIKI_AGO_MIN', 'min')
      : age.unit === 'h' ? T('WIKI_AGO_HOUR', 'h') : T('WIKI_AGO_DAY', 'd');
    return age.n + ' ' + word;
  }
  function days(T, n) {
    if (n === null || n === undefined) return '';
    return n + ' ' + T('WIKI_AGO_DAY', 'd');
  }

  function labelChip(T, esc, label) {
    if (label === 'asks') return '<span class="chip hot">' + esc(T('WIKI_THREAD_ASKS', 'asks you')) + '</span>';
    if (label === 'gate1') return '<span class="chip wait">' + esc(T('WIKI_THREAD_GATE1', 'Gate 1')) + '</span>';
    return '<span class="chip ok">' + esc(T('WIKI_THREAD_UNREAD', 'finished · unread')) + '</span>';
  }

  function threadRow(T, esc, href, t) {
    var h = ['<div class="li">'];
    h.push('<span style="width:8px;height:8px;border-radius:999px;background:var(--accent);display:inline-block;margin-top:7px;flex-shrink:0"></span>');
    // A thread has no URL a browser can open, so it offers the two things that exist: its focus
    // page in the wiki, and the command that resumes it in Claude Code, copied on click.
    var cmd = 'claude --resume ' + t.id;
    h.push('<div style="min-width:0;flex:1"><div class="t">' + esc(t.title) + '</div>');
    h.push('<div class="d">' + esc(t.says) + '</div>');
    h.push('<div class="d" style="margin-top:6px;display:flex;gap:10px;flex-wrap:wrap">' +
      (t.focus ? '<a href="' + href(t.focus) + '">' + esc(t.focusLabel || t.focus) + '</a>' : '') +
      '<a href="#" class="resume" data-resume="' + esc(cmd) + '" title="' + esc(cmd) + '">' + esc(T('WIKI_THREAD_RESUME', 'Copy the command to resume it')) + '</a>' +
      '</div></div>');
    h.push('<div style="display:flex;flex-direction:column;align-items:flex-end;gap:4px;flex-shrink:0">');
    h.push(labelChip(T, esc, t.label));
    h.push('<span class="muted" style="font-size:12px">' + esc(ago(T, t.age)) + '</span></div>');
    return h.join('') + '</div>';
  }

  function threads(T, esc, href, o) {
    var h = ['<h2>' + svg('message') + ' ' + esc(T('WIKI_THREADS', 'Threads waiting for you')) +
      ' <span class="muted" style="font-weight:400;font-size:13px">' +
      esc(T('WIKI_THREADS_WINDOW', 'last %s days · grouped by focus').replace('%s', o.days)) +
      '</span></h2>'];
    if (!o.sessions.available) {
      h.push('<div class="note">' + esc(T('WIKI_NO_SESSIONS',
        'No local Claude Code sessions to read on this machine.')) + '</div>');
      return h.join('');
    }
    if (!o.threads.length) {
      h.push('<div class="note">' + esc(T('WIKI_NO_THREADS', 'No thread is waiting for you.')) + '</div>');
      return h.join('');
    }
    h.push('<div class="card" style="padding:4px 16px">');
    var unread = 0;
    o.threads.forEach(function (g) {
      h.push('<div class="grp" style="padding:10px 0 2px">' +
        (g.focus ? '<a href="' + href(g.focus) + '" style="color:inherit">' + esc(g.label) + '</a>' : esc(g.label || T('WIKI_NO_FOCUS', 'No focus'))) + '</div>');
      g.threads.forEach(function (t) {
        if (t.unreadByDefault) unread++;
        h.push(threadRow(T, esc, href, t));
      });
    });
    h.push('</div>');
    /* The page says WHY a thread is here when the reason is a missing datum, not a fact: there is
       no record of what the person read, so a finished turn is shown, and shown as unverified. */
    if (unread) {
      h.push('<div class="note" style="margin-top:10px">' + esc(T('WIKI_UNREAD_WHY',
        'Claude Code keeps no record of what you opened: a finished thread is shown as unread for lack of that datum.')) +
        '</div>');
    }
    return h.join('');
  }

  function gates(T, esc, o) {
    var h = ['<div class="card"><h2 style="margin:0 0 8px">' + svg('gate') + ' ' +
      esc(T('WIKI_GATES', 'Gates')) + '</h2>'];
    if (!o.gates.length) {
      h.push('<div class="d">' + esc(T('WIKI_NO_GATES', 'No gate is open.')) + '</div>');
    }
    o.gates.forEach(function (g) {
      var chip = g.gate === '2'
        ? '<span class="chip wait">' + esc(T('WIKI_GATE_2', 'Gate 2 · merge')) + '</span>'
        : '<span class="chip wait">' + esc(T('WIKI_GATE_1', 'Gate 1')) + '</span>';
      var detail = esc(g.repo);
      if (g.branch) detail += ' · ' + esc(g.branch);
      if (g.days !== null && g.days !== undefined) detail += ' · ' + esc(days(T, g.days));
      h.push('<div class="li"><div><div class="t">' + esc(g.title) + '</div>' +
        '<div class="d">' + detail + '</div></div>' + chip + '</div>');
    });
    return h.join('') + '</div>';
  }

  function waiting(T, esc, href, rows) {
    var h = ['<div class="card"><h2 style="margin:0 0 8px">' + svg('clock') + ' ' +
      esc(T('WIKI_WAITING_OTHERS', 'Waiting on others')) + '</h2>'];
    if (!rows.length) {
      h.push('<div class="d">' + esc(T('WIKI_NO_WAITING', 'Nobody owes you an answer.')) + '</div>');
    }
    rows.forEach(function (r) {
      var detail = r.reason ? esc(r.reason) + ' · ' : '';
      h.push('<div class="li"><div><div class="t">' + esc(r.who) + '</div><div class="d">' +
        detail + '<a href="' + href(r.path) + '">' + esc(r.title) + '</a></div></div>' +
        '<span class="chip' + (r.days !== null && r.days >= 14 ? ' hot' : '') + '">' +
        esc(days(T, r.days)) + '</span></div>');
    });
    return h.join('') + '</div>';
  }

  function week(T, esc, href, rows, span) {
    var h = ['<h2>' + svg('calendar') + ' ' + esc(T('WIKI_THIS_WEEK', 'This week')) +
      ' <span class="muted" style="font-weight:400;font-size:13px">' +
      esc(T('WIKI_WEEK_WINDOW', 'next %s days').replace('%s', span)) + '</span></h2>'];
    if (!rows.length) {
      return h.join('') + '<div class="note">' +
        esc(T('WIKI_NO_WEEK', 'Nothing has a date this week.')) + '</div>';
    }
    h.push('<div class="card" style="padding:4px 16px">');
    rows.forEach(function (r) {
      var detail = '<a href="' + href(r.path) + '">' + esc(r.node) + '</a>';
      if (r.reason) detail += ' · ' + esc(r.reason);
      h.push('<div class="li"><div><div class="t">' + esc(r.text) + '</div><div class="d">' +
        detail + '</div></div><span class="chip' + (r.days <= 1 ? ' hot' : ' wait') + '">' +
        esc(r.date) + '</span></div>');
    });
    return h.join('') + '</div>';
  }

  /* The screen. It takes what the shell already has —the payload, the workspace on screen, the
     catalog and the two helpers— and gives back HTML: no DOM, no state of its own. */
  function view(DATA, w, T, esc, href) {
    var o = DATA.overview;
    if (!o) return '<h1>' + esc(T('WIKI_OVERVIEW', 'Overview')) + '</h1>';
    var slug = w ? w.slug : '';
    var asks = 0;
    o.threads.forEach(function (g) {
      g.threads.forEach(function (t) { if (t.label !== 'unread') asks++; });
    });
    var wait = (o.waiting[slug] || []), days7 = (o.week_items[slug] || []);
    var h = ['<h1>' + esc(T('WIKI_OVERVIEW', 'Overview')) + '</h1>'];
    h.push('<div class="meta"><span>' + esc(w ? w.title : '') + '</span><span>·</span><span>' +
      esc(o.today) + '</span>');
    h.push('<span class="chip hot">' + asks + ' ' + esc(T('WIKI_COUNT_THREADS', 'threads wait for you')) + '</span>');
    h.push('<span class="chip wait">' + o.gates.length + ' ' + esc(T('WIKI_COUNT_GATES', 'gates')) + '</span>');
    h.push('<span class="chip">' + wait.length + ' ' + esc(T('WIKI_COUNT_WAITING', 'waiting on others')) + '</span>');
    h.push('</div>');
    h.push(threads(T, esc, href, o));
    h.push('<div class="cards" style="margin-top:22px">' + gates(T, esc, o) +
      waiting(T, esc, href, wait) + '</div>');
    h.push(week(T, esc, href, days7, o.week));
    return h.join('');
  }

  return {view: view, icon: svg};
})();
if (typeof module !== 'undefined' && module.exports) { module.exports = WIKI_OVERVIEW; }
