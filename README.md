# Claude Code Status Line

A stylish, modern, single-line status line for [Claude Code](https://claude.com/claude-code) —
**standalone, zero dependencies, no plugins required.**

```
 claude-status-line  🌿 main  ▓▓▓▓░░░░ 42% 🟢  +12 -3  ⏱️ 8m  📊 5h 18%·1h59m  📅 7d 63%·2d23h  🤖 Opus 4.8
```

It's a single Node.js file (`statusline.js`). Node ships with Claude Code, so there is
**nothing else to install** — no `jq`, no `bc`, no marketplace plugins. Works on
macOS, Linux, and Windows.

## What it shows

| Segment | Meaning |
| --- | --- |
| **repo** | Current repository / workspace name |
| 🌿 branch | Git branch (or short SHA when detached) |
| gauge | Context-window usage as a truecolor gradient bar + `%` + severity dot (🟢🟡🟠🔴) |
| `+ / -` | Uncommitted diff velocity vs `HEAD` (`clean` when none) |
| ⏱️ time | Session duration |
| 📊 5h | 5-hour rate-limit usage · time to reset |
| 📅 7d | 7-day rate-limit usage · time to reset |
| 🤖 model | Active model |

Segments hide themselves automatically when Claude Code doesn't provide that data.

## Install

### macOS / Linux / Git-Bash

```bash
./install.sh
```

### Windows (PowerShell)

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

The installer copies `statusline.js` into your Claude config directory
(`~/.claude`, or `$CLAUDE_CONFIG_DIR` if set) and wires the `statusLine` block into
`settings.json` — **preserving any settings you already have.**

Restart Claude Code (or run `/statusline`) to see it.

### Manual install

1. Copy `statusline.js` to `~/.claude/statusline.js`.
2. Add this to `~/.claude/settings.json` (see `settings-statusline.json`):

   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "node ~/.claude/statusline.js"
     }
   }
   ```

## Customizing

Everything lives in `statusline.js`:

- **Colors** — edit the `C` palette object (truecolor RGB).
- **Gauge width** — change `BLOCKS` (default `12`).
- **Icons** — swap the emoji in the "Build segments" section.
- **Segments** — comment out any block you don't want.

## Requirements

- **Node.js** — bundled with Claude Code.
- **git** — optional; the branch and diff segments simply disappear outside a repo.
- A terminal with **truecolor** support (virtually all modern terminals).

## Preview it without Claude Code

```bash
echo '{"workspace":{"project_dir":"/path/to/repo"},"model":{"display_name":"Opus 4.8"},"context_window":{"used_percentage":42},"cost":{"total_duration_ms":512000}}' | node statusline.js
```
