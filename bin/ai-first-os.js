#!/usr/bin/env node
'use strict';

// AI First OS launcher — this is what `npx ai-first-os` runs.
//
// It does three things, in this order, and nothing else:
//   1. checks git is on PATH — the one hard requirement of the system, the same check
//      core/lib/bootstrap.sh makes before writing anything. Python 3 is looked up by its three names
//      (python3, python, py -3: the same order and the same test as os_python_find in
//      core/lib/common.sh); without it the install goes on and prints a warning;
//   2. copies core/, README.md and LICENSE from this package to a fixed folder, ~/.ai-first-os,
//      replacing whatever was already there — the npm cache this script runs from is reclaimed,
//      so the system cannot keep living inside it;
//   3. prints the exact path of the skill that conducts the interview.
//
// It never installs system software, never asks a question, and never runs anything from the
// tree it just copied: the interview is a separate step, run by the agent that reads the file
// this prints. Running this again is always safe — it replaces the destination, it never merges
// into it.

const { spawnSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

function hasCommand(cmd) {
  const result = spawnSync(cmd, ['--version'], { stdio: 'ignore' });
  return !result.error && result.status === 0;
}

function fail(message) {
  process.stderr.write('error: ' + message + '\n');
  process.exit(1);
}

// A candidate is accepted only if it runs and exits 0 exactly when its major version is 3. That
// leaves out the Microsoft Store shortcut (it fails) and a Python 2. Same order as os_python_find.
const PYTHON_PROBE = 'import sys; sys.exit(0 if sys.version_info[0] == 3 else 1)';
const PYTHON_CANDIDATES = [['python3'], ['python'], ['py', '-3']];

// Each probe has a deadline: a candidate that hangs counts as failed and the next one is tried.
const PROBE_TIMEOUT_MS = Number(process.env.AI_FIRST_OS_PROBE_TIMEOUT_MS) || 10000;

// Runs one probe of `argv` (command first). On Windows, a `.cmd` shim (pyenv-win and some managers)
// cannot be spawned directly: the spawn fails with ENOENT or EINVAL, and the probe is retried through
// `cmd.exe /d /s /c` with the line quoted. `.exe` candidates never reach that retry.
function runProbe(argv) {
  const opts = { stdio: 'ignore', timeout: PROBE_TIMEOUT_MS };
  let result = spawnSync(argv[0], argv.slice(1), opts);
  if (result.error && process.platform === 'win32' && (result.error.code === 'ENOENT' || result.error.code === 'EINVAL')) {
    const line = argv.map((a) => (/[\s"]/.test(a) ? '"' + a + '"' : a)).join(' ');
    result = spawnSync(process.env.ComSpec || 'cmd.exe', ['/d', '/s', '/c', '"' + line + '"'], {
      ...opts,
      windowsVerbatimArguments: true,
    });
  }
  return !result.error && result.status === 0;
}

function findPython() {
  for (const candidate of PYTHON_CANDIDATES) {
    if (runProbe(candidate.concat(['-c', PYTHON_PROBE]))) return candidate.join(' ');
  }
  return null;
}

// Required by the evals (S080-C1) to run findPython alone; `npx` runs this file directly, never so.
if (require.main !== module) {
  module.exports = { findPython };
  return;
}

if (!hasCommand('git')) {
  fail(
    'git is missing. Install it from the official channel (macOS: `xcode-select --install`; ' +
      "Windows: git-scm.com) and run `npx ai-first-os` again — nothing was written."
  );
}

// Printed in both languages, English first: the brain does not exist yet, so its language is unknown.
const PYTHON_WARNING =
  "Python 3 was not found \u2014 installing anyway. Without Python, 2 features won't be available:\n" +
  '  \u2022 Connecting a code repository (mount-repo).\n' +
  '  \u2022 Living Memory search (recall). The AI searches files as plain text instead: it can\'t put the\n' +
  '    current version of a document above a replaced one, open the exact section, or follow what a\n' +
  '    document is about or what replaced it.\n' +
  'To get them: install Python (python.org). Nothing needs to be reinstalled.\n' +
  '\n' +
  'No se encontr\u00f3 Python 3: la instalaci\u00f3n sigue. Sin Python hay 2 funcionalidades que no vas a tener disponibles:\n' +
  '  \u2022 Conectar un repositorio de c\u00f3digo (mount-repo).\n' +
  '  \u2022 La b\u00fasqueda de Living Memory (recall). La IA busca en los archivos como texto com\u00fan: no puede\n' +
  '    poner la versi\u00f3n vigente de un documento por encima de una reemplazada, abrir la secci\u00f3n exacta\n' +
  '    ni seguir de qu\u00e9 trata un documento o qu\u00e9 lo reemplaz\u00f3.\n' +
  'Para tenerlas: instal\u00e1 Python (python.org). No hace falta reinstalar nada.\n';

// The marker means "the launcher already warned during this install": it is deleted at the start of
// every run and written only when this run warns. A retry of the launcher warns again.
const warnedMarker = path.join(os.homedir(), '.ai-first-os', '.python-warned');
fs.rmSync(warnedMarker, { force: true });
const pythonFound = findPython() !== null;
if (!pythonFound) {
  process.stderr.write(PYTHON_WARNING);
}

const packageRoot = path.join(__dirname, '..');
const dest = path.join(os.homedir(), '.ai-first-os');

function copyReplace(name) {
  const src = path.join(packageRoot, name);
  const target = path.join(dest, name);
  fs.rmSync(target, { recursive: true, force: true });
  fs.cpSync(src, target, { recursive: true });
}

fs.mkdirSync(dest, { recursive: true });
copyReplace('core');
copyReplace('README.md');
copyReplace('LICENSE');

if (!pythonFound) fs.writeFileSync(warnedMarker, 'The launcher warned that Python 3 was not found.\n');

const LOGO = [
  ' █████╗ ██╗  ███████╗██╗██████╗ ███████╗████████╗   ██████╗ ███████╗',
  '██╔══██╗██║  ██╔════╝██║██╔══██╗██╔════╝╚══██╔══╝  ██╔═══██╗██╔════╝',
  '███████║██║  █████╗  ██║██████╔╝███████╗   ██║     ██║   ██║███████╗',
  '██╔══██║██║  ██╔══╝  ██║██╔══██╗╚════██║   ██║     ██║   ██║╚════██║',
  '██║  ██║██║  ██║     ██║██║  ██║███████║   ██║     ╚██████╔╝███████║',
  '╚═╝  ╚═╝╚═╝  ╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝   ╚═╝      ╚═════╝ ╚══════╝',
];
const LOGO_WIDTH = 68;
const TAGLINE = 'An OS to work with your second brain and manage your context.';
const ROW_TOP = [0x8f, 0xd0, 0xff]; // light blue, first row
const ROW_BOTTOM = [0x00, 0x78, 0xff]; // brand blue, last row
const TAGLINE_TO = [0x4f, 0xc3, 0xff]; // tagline gradient: brand blue to this
const SHIMMER = [0xe6, 0xf6, 0xff]; // near-white light blue, the sweeping band
const SHIMMER_HALF = 4; // half width in columns: a band about 8 wide, soft falloff
const SHIMMER_FRAMES = 22;
const SHIMMER_MS = 27;
const REVEAL_MS = 70;
const SHADOW_DARKEN = 0.55; // shadow strokes keep the row color at 55% brightness

// Interactive terminals only: agents, pipes and evals get exactly the plain output.
function logoWanted() {
  return (
    process.stdout.isTTY === true &&
    process.stdout.columns >= LOGO_WIDTH &&
    process.env.TERM !== 'dumb'
  );
}

function mix(from, to, t) {
  return from.map((v, k) => Math.round(v + (to[k] - v) * t));
}

function rgb(c) {
  return '\x1b[38;2;' + c[0] + ';' + c[1] + ';' + c[2] + 'm';
}

// One color per row; the block characters get it as is, the shadow strokes a darker version of it.
// A shimmer position (a column, or null) lightens the characters near it toward SHIMMER.
function paintRow(line, row, shimmer) {
  if (process.env.NO_COLOR) return line;
  const solid = mix(ROW_TOP, ROW_BOTTOM, row / (LOGO.length - 1));
  const shadow = solid.map((v) => Math.round(v * SHADOW_DARKEN));
  let out = '';
  let col = 0;
  for (const ch of line) {
    let c = ch === '█' ? solid : shadow;
    if (shimmer !== null && ch !== ' ') {
      const d = Math.abs(col - shimmer);
      if (d < SHIMMER_HALF) c = mix(c, SHIMMER, Math.pow(1 - d / SHIMMER_HALF, 1.5));
    }
    out += ch === ' ' ? ch : rgb(c) + ch;
    col++;
  }
  return out + '\x1b[0m';
}

// Horizontal gradient across the tagline's own length.
function paintTagline(text) {
  if (process.env.NO_COLOR) return text;
  let out = '';
  for (let i = 0; i < text.length; i++) {
    out += text[i] === ' ' ? ' ' : rgb(mix(ROW_BOTTOM, TAGLINE_TO, i / (text.length - 1))) + text[i];
  }
  return out + '\x1b[0m';
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// Reveal the rows top to bottom, then sweep one band of light left to right, redrawing in place.
// Each frame is a single write. The cursor is hidden meanwhile and always restored.
async function animateLogo() {
  const showCursor = () => process.stdout.write('\x1b[?25h');
  const onSigint = () => {
    showCursor();
    process.exit(130);
  };
  process.on('exit', showCursor);
  process.on('SIGINT', onSigint);
  process.stdout.write('\x1b[?25l');
  for (let row = 0; row < LOGO.length; row++) {
    process.stdout.write(paintRow(LOGO[row], row, null) + '\n');
    await sleep(REVEAL_MS);
  }
  for (let f = 0; f < SHIMMER_FRAMES; f++) {
    const center = -SHIMMER_HALF + ((LOGO_WIDTH + 2 * SHIMMER_HALF) * f) / (SHIMMER_FRAMES - 1);
    const frame = LOGO.map((line, row) => paintRow(line, row, f === SHIMMER_FRAMES - 1 ? null : center));
    process.stdout.write('\x1b[' + LOGO.length + 'A' + frame.join('\n') + '\n');
    await sleep(SHIMMER_MS);
  }
  showCursor();
  process.removeListener('exit', showCursor);
  process.removeListener('SIGINT', onSigint);
}

async function printLogo() {
  if (!logoWanted()) return;
  const animate = !process.env.NO_COLOR && !process.env.CI && !process.env.AI_FIRST_OS_NO_ANIMATION;
  if (animate) await animateLogo();
  else process.stdout.write(LOGO.map((line, row) => paintRow(line, row, null)).join('\n') + '\n');
  process.stdout.write(paintTagline(TAGLINE) + '\n');
  let version = '';
  try {
    version = fs.readFileSync(path.join(packageRoot, 'core', 'VERSION'), 'utf8').split('\n')[0].replace(/\r/g, '').trim();
  } catch (e) {
    // No VERSION file: no version line.
  }
  if (version) process.stdout.write('v' + version + '\n');
  process.stdout.write('\n');
}

const bootstrapPath = path.join(dest, 'core', 'skills', 'bootstrap.md');

printLogo().then(() => {
  process.stdout.write('AI First OS is installed at ' + dest + '\n');
  process.stdout.write(
    'Do not replicate this script by hand: a hand-copied install skips the symlinks the system ' +
      'needs and leaves it broken. This script is the deliverable — run `npx ai-first-os` again ' +
      'instead of rewriting it.\n'
  );
  process.stdout.write('Tell your agent: read and follow ' + bootstrapPath + '\n');
});

