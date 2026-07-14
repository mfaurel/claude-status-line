# ─────────────────────────────────────────────────────────────────────────────
#  Installer for the standalone Claude Code status line (Windows / PowerShell)
#  - Copies statusline.js into %USERPROFILE%\.claude\
#  - Wires the statusLine block into settings.json (preserves existing keys)
#
#  Usage:  powershell -ExecutionPolicy Bypass -File .\install.ps1
# ─────────────────────────────────────────────────────────────────────────────
$ErrorActionPreference = 'Stop'

$SrcDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ClaudeDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.claude' }
$Settings = Join-Path $ClaudeDir 'settings.json'

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
  Write-Error "Node.js not found on PATH. Node ships with Claude Code - make sure it is available."
  exit 1
}

New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null
Copy-Item (Join-Path $SrcDir 'statusline.js') (Join-Path $ClaudeDir 'statusline.js') -Force
Write-Host "OK  Copied statusline.js -> $ClaudeDir\statusline.js"

$Target = (Join-Path $ClaudeDir 'statusline.js')

# Load, merge, and save settings.json (comment-free JSON expected).
if (Test-Path $Settings) {
  try { $cfg = Get-Content -Raw $Settings | ConvertFrom-Json } catch { $cfg = [PSCustomObject]@{} }
} else {
  $cfg = [PSCustomObject]@{}
}

# node reads the path via argv; forward slashes work everywhere and avoid escaping.
$cmd = 'node "' + ($Target -replace '\\', '/') + '"'
$statusLine = [PSCustomObject]@{ type = 'command'; command = $cmd }

if ($cfg.PSObject.Properties.Name -contains 'statusLine') {
  $cfg.statusLine = $statusLine
} else {
  $cfg | Add-Member -MemberType NoteProperty -Name 'statusLine' -Value $statusLine
}

# Write UTF-8 WITHOUT a BOM — Windows PowerShell's `Set-Content -Encoding utf8`
# prepends a BOM that some JSON parsers reject.
$json = ($cfg | ConvertTo-Json -Depth 20) + "`n"
[System.IO.File]::WriteAllText($Settings, $json, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "OK  Updated $Settings"
Write-Host ""
Write-Host "Done. Restart Claude Code (or run /statusline) to see it."
