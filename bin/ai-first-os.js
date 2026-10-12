#!/usr/bin/env node
'use strict';

// AI First OS launcher — this is what `npx ai-first-os` runs.
//
// It does three things, in this order, and nothing else:
//   1. checks git and python3 are on PATH — the two hard requirements of the system, the same two
//      core/lib/bootstrap.sh checks before writing anything;
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

if (!hasCommand('git')) {
  fail(
    'git is missing. Install it from the official channel (macOS: `xcode-select --install`; ' +
      "Windows: git-scm.com) and run `npx ai-first-os` again — nothing was written."
  );
}

if (!hasCommand('python3')) {
  fail(
    'python3 is missing. Install it from the official channel (macOS: `xcode-select --install`, ' +
      "the same command that brings git; Windows: python.org; Linux: your distro's package " +
      'manager) and run `npx ai-first-os` again — nothing was written.'
  );
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
