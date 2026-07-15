#!/usr/bin/env node
/*
 * ─────────────────────────────────────────────────────────────────────────────
 *  Claude Code — standalone status line
 *  Single line · truecolor · emoji · zero dependencies (Node built-ins only).
 *
 *  Node ships with Claude Code, so this needs no jq, no bc, no plugins.
 *  Reads the status JSON on stdin, prints one styled line on stdout.
 * ─────────────────────────────────────────────────────────────────────────────
 */

'use strict';

const { execFileSync } = require('node:child_process');
const path = require('node:path');

// ── ANSI truecolor helpers ───────────────────────────────────────────────────
const RESET = '\x1b[0m';
const BOLD = '\x1b[1m';
const fg = (r, g, b) => `\x1b[38;2;${r};${g};${b}m`;
const paint = (s, color, bold = false) => `${bold ? BOLD : ''}${color}${s}${RESET}`;

// Palette
const C = {
  repo: fg(88, 166, 255),
  branch: fg(189, 147, 249),
  add: fg(46, 204, 113),
  del: fg(231, 76, 60),
  dim: fg(96, 100, 116),
  track: fg(58, 62, 74),
  time: fg(130, 200, 230),
  fiveHr: fg(255, 170, 100),
  sevenDay: fg(150, 220, 150),
  model: fg(200, 130, 240),
};

const SEP = `${C.dim}  ${RESET}`; // airy divider between segments

// ── Read stdin ────────────────────────────────────────────────────────────────
function readStdin() {
  try {
    return require('node:fs').readFileSync(0, 'utf8');
  } catch {
    return '';
  }
}

let data = {};
try {
  data = JSON.parse(readStdin() || '{}');
} catch {
  data = {};
}

const get = (obj, dotted, dflt) =>
  dotted.split('.').reduce((o, k) => (o == null ? o : o[k]), obj) ?? dflt;

const cwd = get(data, 'workspace.current_dir', get(data, 'cwd', process.cwd()));
const projectDir = get(data, 'workspace.project_dir', '');
const model = get(data, 'model.display_name', '');
const usedPct = get(data, 'context_window.used_percentage', null);
const sessionMs = get(data, 'cost.total_duration_ms', null);
const fiveHrPct = get(data, 'rate_limits.five_hour.used_percentage', null);
const fiveHrReset = get(data, 'rate_limits.five_hour.resets_at', null);
const sevenDayPct = get(data, 'rate_limits.seven_day.used_percentage', null);
const sevenDayReset = get(data, 'rate_limits.seven_day.resets_at', null);

const repoName = path.basename(projectDir || cwd || '') || 'workspace';

// ── Git (best-effort, silent on failure) ─────────────────────────────────────
function git(args) {
  try {
    return execFileSync('git', ['-C', cwd, ...args], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
      env: { ...process.env, GIT_OPTIONAL_LOCKS: '0' },
    }).trim();
  } catch {
    return '';
  }
}

let branch = '';
let added = 0;
let removed = 0;
if (git(['rev-parse', '--git-dir'])) {
  branch = git(['symbolic-ref', '--short', 'HEAD']) || git(['rev-parse', '--short', 'HEAD']);
  const numstat = git(['diff', '--numstat', 'HEAD']);
  if (numstat) {
    for (const line of numstat.split('\n')) {
      const [a, r] = line.split('\t');
      added += parseInt(a, 10) || 0;
      removed += parseInt(r, 10) || 0;
    }
  }
}

// ── Gauge renderer (green→red gradient bar) ──────────────────────────────────
function renderBar(pct, blocks) {
  const filled = Math.min(blocks, Math.round((pct * blocks) / 100));
  let bar = '';
  for (let i = 0; i < blocks; i++) {
    if (i < filled) {
      const t = blocks > 1 ? i / (blocks - 1) : 0;
      let r, g, b;
      if (t < 0.5) {
        const u = t * 2;
        r = Math.round(0 + 220 * u);
        g = 200;
        b = Math.round(80 + (0 - 80) * u);
      } else {
        const u = (t - 0.5) * 2;
        r = 220;
        g = Math.round(200 + (40 - 200) * u);
        b = Math.round(0 + 20 * u);
      }
      bar += `${fg(r, g, b)}█`;
    } else {
      bar += `${C.track}░`;
    }
  }
  return bar + RESET;
}

// ── Context gauge ────────────────────────────────────────────────────────────
const BLOCKS = 10;
const RL_BLOCKS = 8;
function contextGauge() {
  if (usedPct == null || isNaN(usedPct)) {
    return `${C.track}${'░'.repeat(BLOCKS)}${RESET} ${C.dim}--%${RESET}`;
  }
  const pct = Math.round(usedPct);
  const bar = renderBar(pct, BLOCKS);

  let emoji, pc;
  if (pct < 50) { emoji = '🟢'; pc = fg(46, 204, 113); }
  else if (pct < 75) { emoji = '🟡'; pc = fg(241, 196, 15); }
  else if (pct < 90) { emoji = '🟠'; pc = fg(230, 126, 34); }
  else { emoji = '🔴'; pc = fg(231, 76, 60); }

  return `${bar} ${paint(`${pct}%`, pc, true)} ${emoji}`;
}

// ── Relative-time formatter for rate-limit resets ────────────────────────────
function relTime(ts) {
  if (ts == null) return '';
  let ms;
  if (typeof ts === 'number') {
    ms = ts < 1e12 ? ts * 1000 : ts; // seconds vs milliseconds
  } else {
    const parsed = Date.parse(ts);
    if (isNaN(parsed)) {
      const asNum = Number(ts);
      if (isNaN(asNum)) return '';
      ms = asNum < 1e12 ? asNum * 1000 : asNum;
    } else {
      ms = parsed;
    }
  }
  const diff = Math.floor((ms - Date.now()) / 1000);
  if (diff <= 0) return 'now';
  const d = Math.floor(diff / 86400);
  const h = Math.floor((diff % 86400) / 3600);
  const m = Math.floor((diff % 3600) / 60);
  if (d > 0) return `${d}d${h}h`;
  if (h > 0) return `${h}h${m}m`;
  return `${m}m`;
}

// ── Build segments ───────────────────────────────────────────────────────────
const segments = [];

segments.push(paint(repoName, C.repo, true));

if (branch) segments.push(`🌿 ${paint(branch, C.branch)}`);

segments.push(contextGauge());

if (added > 0 || removed > 0) {
  segments.push(`${paint(`+${added}`, C.add)} ${paint(`-${removed}`, C.del)}`);
} else {
  segments.push(paint('clean', C.dim));
}

if (sessionMs != null && !isNaN(sessionMs)) {
  const s = Math.floor(sessionMs / 1000);
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  segments.push(`⏱️ ${paint(h > 0 ? `${h}h${m}m` : `${m}m`, C.time)}`);
}

if (fiveHrPct != null && !isNaN(fiveHrPct)) {
  const pct = Math.round(fiveHrPct);
  const rt = relTime(fiveHrReset);
  let s = `📊 ${renderBar(pct, RL_BLOCKS)} ${paint(`5h ${pct}%`, C.fiveHr)}`;
  if (rt) s += `${C.dim}·${rt}${RESET}`;
  segments.push(s);
}

if (sevenDayPct != null && !isNaN(sevenDayPct)) {
  const pct = Math.round(sevenDayPct);
  const rt = relTime(sevenDayReset);
  let s = `📅 ${renderBar(pct, RL_BLOCKS)} ${paint(`7d ${pct}%`, C.sevenDay)}`;
  if (rt) s += `${C.dim}·${rt}${RESET}`;
  segments.push(s);
}

if (model) segments.push(`🤖 ${paint(model, C.model)}`);

process.stdout.write(segments.join(SEP) + '\n');
