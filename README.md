# Claude Code Statusline

Two options — use one or both.

## Option 1: claude-hud plugin (active setup)

A rich HUD powered by the [claude-hud](https://github.com/jarrodwatts/claude-hud) plugin.

### Install

1. Merge `settings-statusline.json` into your `~/.claude/settings.json`:
   - Add the `statusLine`, `enabledPlugins`, and `extraKnownMarketplaces` blocks.
2. Restart Claude Code — the plugin installs automatically on first run.

## Option 2: custom bash script

A standalone truecolor bash statusline (`statusline-command.sh`) with no external dependencies beyond `jq`, `git`, and `bc`.

Shows: repo name · git branch · context bar (gradient) · diff velocity · tokens · cost · session duration · rate limits · model.

### Install

1. Copy `statusline-command.sh` to `~/.claude/statusline-command.sh`
2. Make it executable: `chmod +x ~/.claude/statusline-command.sh`
3. Add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  }
}
```

### Requirements

- `jq`
- `git`
- `bc`
- A terminal with truecolor support
