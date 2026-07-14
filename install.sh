#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  Installer for the standalone Claude Code status line (macOS / Linux / Git-Bash)
#  - Copies statusline.js into ~/.claude/
#  - Wires the statusLine block into ~/.claude/settings.json (uses Node, no jq)
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SETTINGS="$CLAUDE_DIR/settings.json"

if ! command -v node >/dev/null 2>&1; then
  echo "❌ Node.js not found on PATH. Node ships with Claude Code — make sure it is available." >&2
  exit 1
fi

mkdir -p "$CLAUDE_DIR"
cp "$SRC_DIR/statusline.js" "$CLAUDE_DIR/statusline.js"
echo "✅ Copied statusline.js → $CLAUDE_DIR/statusline.js"

TARGET="$CLAUDE_DIR/statusline.js"

# Merge the statusLine block into settings.json using Node (preserves existing keys).
SETTINGS="$SETTINGS" TARGET="$TARGET" node - <<'NODE'
const fs = require('fs');
const file = process.env.SETTINGS;
const target = process.env.TARGET;
let cfg = {};
try { cfg = JSON.parse(fs.readFileSync(file, 'utf8')); } catch {}
cfg.statusLine = { type: 'command', command: `node "${target}"` };
fs.mkdirSync(require('path').dirname(file), { recursive: true });
fs.writeFileSync(file, JSON.stringify(cfg, null, 2) + '\n');
console.log('✅ Updated ' + file);
NODE

echo ""
echo "🎉 Done. Restart Claude Code (or run /statusline) to see it."
