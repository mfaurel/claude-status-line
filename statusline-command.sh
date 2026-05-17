#!/usr/bin/env bash
# Claude Code status line — truecolor RGB, single line

input=$(cat)

# ── Parse JSON fields ────────────────────────────────────────────────────────
cwd=$(echo "$input"           | jq -r '.workspace.current_dir // .cwd // ""')
model=$(echo "$input"         | jq -r '.model.display_name // ""')
used_pct=$(echo "$input"      | jq -r '.context_window.used_percentage // empty')
remaining_pct=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
total_tokens=$(echo "$input"       | jq -r '.context_window.total_input_tokens // empty')
cost_usd=$(echo "$input"           | jq -r '.cost.total_cost_usd // empty')
session_ms=$(echo "$input"         | jq -r '.cost.total_duration_ms // empty')
five_hr_pct=$(echo "$input"        | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_hr_reset=$(echo "$input"      | jq -r '.rate_limits.five_hour.resets_at // empty')
seven_day_pct=$(echo "$input"      | jq -r '.rate_limits.seven_day.used_percentage // empty')
seven_day_reset=$(echo "$input"    | jq -r '.rate_limits.seven_day.resets_at // empty')

# Git repo name (basename of project_dir, fallback to cwd basename)
project_dir=$(echo "$input" | jq -r '.workspace.project_dir // ""')
if [ -n "$project_dir" ]; then
  repo_name=$(basename "$project_dir")
else
  repo_name=$(basename "$cwd")
fi

# Git branch (fast, skip optional locks)
branch=""
if git_dir=$(git -C "$cwd" rev-parse --git-dir 2>/dev/null); then
  branch=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null \
           || GIT_OPTIONAL_LOCKS=0 git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
fi

# Code velocity: lines added/removed since last commit
added=0
removed=0
if [ -n "$branch" ]; then
  diff_stat=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" diff --numstat HEAD 2>/dev/null)
  if [ -n "$diff_stat" ]; then
    added=$(echo "$diff_stat"   | awk '{s+=$1} END{print s+0}')
    removed=$(echo "$diff_stat" | awk '{s+=$2} END{print s+0}')
  fi
fi

# ── ANSI helpers ─────────────────────────────────────────────────────────────
rgb()    { printf '\033[38;2;%d;%d;%dm' "$1" "$2" "$3"; }
bg_rgb() { printf '\033[48;2;%d;%d;%dm' "$1" "$2" "$3"; }
bold()   { printf '\033[1m'; }
reset()  { printf '\033[0m'; }
dim()    { printf '\033[2m'; }

# Dim gray pipe separator
pipe() { printf '%s' "$(dim)$(rgb 110 110 110) │ $(reset)"; }

# ── Context bar & percentage ─────────────────────────────────────────────────
BLOCKS=20

if [ -n "$used_pct" ]; then
  # Integer percentage
  pct_int=$(printf '%.0f' "$used_pct")

  # How many filled blocks
  filled=$(( pct_int * BLOCKS / 100 ))
  [ "$filled" -gt "$BLOCKS" ] && filled=$BLOCKS
  empty=$(( BLOCKS - filled ))

  # Build gradient bar: green(0,200,80) → yellow(220,200,0) → red(220,40,20)
  bar=""
  for i in $(seq 1 $BLOCKS); do
    t=$(echo "scale=4; ($i - 1) / ($BLOCKS - 1)" | bc)
    if [ "$i" -le "$filled" ]; then
      # Filled block — gradient colour
      if [ "$(echo "$t < 0.5" | bc)" = "1" ]; then
        # green → yellow
        t2=$(echo "scale=4; $t * 2" | bc)
        r=$(echo "scale=0; 0   + (220 - 0)   * $t2 / 1" | bc)
        g=$(echo "scale=0; 200 + (200 - 200) * $t2 / 1" | bc)
        b=$(echo "scale=0; 80  + (0   - 80)  * $t2 / 1" | bc)
      else
        # yellow → red
        t2=$(echo "scale=4; ($t - 0.5) * 2" | bc)
        r=$(echo "scale=0; 220 + (220 - 220) * $t2 / 1" | bc)
        g=$(echo "scale=0; 200 + (40  - 200) * $t2 / 1" | bc)
        b=$(echo "scale=0; 0   + (20  - 0)   * $t2 / 1" | bc)
      fi
      bar="${bar}$(rgb "$r" "$g" "$b")█"
    else
      # Empty block — dark gray
      bar="${bar}$(rgb 60 60 60)░"
    fi
  done
  bar="${bar}$(reset)"

  # Dynamic emoji by usage level
  if [ "$pct_int" -lt 20 ]; then
    ctx_emoji="🟢"
    pct_color=$(rgb 0 200 80)
  elif [ "$pct_int" -lt 70 ]; then
    ctx_emoji="⚡"
    pct_color=$(rgb 220 200 0)
  elif [ "$pct_int" -lt 90 ]; then
    ctx_emoji="🔥"
    pct_color=$(rgb 230 120 0)
  else
    ctx_emoji="🚨"
    pct_color=$(rgb 220 40 20)
  fi

  pct_str="${pct_color}$(bold)${pct_int}%$(reset)"
  ctx_block="${bar} ${ctx_emoji} ${pct_str}"
else
  ctx_block="$(rgb 60 60 60)░░░░░░░░░░░░░░░░░░░░$(reset) 🟢 $(rgb 60 60 60)--%$(reset)"
fi

# ── Repo name (bold yellow) ──────────────────────────────────────────────────
repo_str="$(bold)$(rgb 255 210 0)${repo_name}$(reset)"

# ── Git branch (bold cyan, with parentheses and leaf icon) ───────────────────
if [ -n "$branch" ]; then
  branch_str="$(rgb 80 80 80)($(bold)$(rgb 0 220 220)🌿 ${branch}$(reset)$(rgb 80 80 80))$(reset)"
else
  branch_str=""
fi

# ── Code velocity ─────────────────────────────────────────────────────────────
if [ "$added" -gt 0 ] || [ "$removed" -gt 0 ]; then
  vel_str="$(rgb 0 200 80)+${added}$(reset) $(rgb 220 40 20)-${removed}$(reset)"
else
  vel_str="$(rgb 60 60 60)+0 -0$(reset)"
fi

# ── Token usage ──────────────────────────────────────────────────────────────
if [ -n "$total_tokens" ]; then
  tok_fmt=$(echo "$total_tokens" | awk '{
    if ($1 >= 1000) printf "%.1fk", $1/1000
    else printf "%d", $1
  }')
  token_str="🪙 $(rgb 180 180 255)${tok_fmt} tok$(reset)"
else
  token_str=""
fi

# ── Session cost ──────────────────────────────────────────────────────────────
if [ -n "$cost_usd" ]; then
  cost_fmt=$(printf '%.3f' "$cost_usd")
  cost_str="💰 $(rgb 255 200 80)\$${cost_fmt}$(reset)"
else
  cost_str=""
fi

# ── Session duration ─────────────────────────────────────────────────────────
session_str=""
if [ -n "$session_ms" ]; then
  session_sec=$(echo "$session_ms" | awk '{printf "%d", $1/1000}')
  session_h=$(( session_sec / 3600 ))
  session_m=$(( (session_sec % 3600) / 60 ))
  if [ "$session_h" -gt 0 ]; then
    session_fmt="${session_h}h${session_m}m"
  else
    session_fmt="${session_m}m"
  fi
  session_str="⏱ $(rgb 160 220 255)Session (${session_fmt})$(reset)"
fi

# ── 5-hour rate limit ─────────────────────────────────────────────────────────
five_hr_str=""
if [ -n "$five_hr_pct" ]; then
  pct5=$(printf '%.0f' "$five_hr_pct")
  if [ -n "$five_hr_reset" ]; then
    now=$(date +%s)
    diff=$(( five_hr_reset - now ))
    if [ "$diff" -le 0 ]; then
      reset5="now"
    else
      rh=$(( diff / 3600 ))
      rm=$(( (diff % 3600) / 60 ))
      if [ "$rh" -gt 0 ]; then reset5="${rh}h${rm}m"; else reset5="${rm}m"; fi
    fi
    five_hr_str="📊 $(rgb 255 170 80)Session ${pct5}%$(reset) $(rgb 120 120 120)· Resets in ${reset5}$(reset)"
  else
    five_hr_str="📊 $(rgb 255 170 80)Session ${pct5}%$(reset)"
  fi
fi

# ── 7-day rate limit ──────────────────────────────────────────────────────────
seven_day_str=""
if [ -n "$seven_day_pct" ]; then
  pct7=$(printf '%.0f' "$seven_day_pct")
  if [ -n "$seven_day_reset" ]; then
    now=$(date +%s)
    diff=$(( seven_day_reset - now ))
    if [ "$diff" -le 0 ]; then
      reset7="now"
    else
      rd=$(( diff / 86400 ))
      rh=$(( (diff % 86400) / 3600 ))
      if [ "$rd" -gt 0 ]; then reset7="${rd}d${rh}h"; else reset7="${rh}h"; fi
    fi
    seven_day_str="📅 $(rgb 180 255 180)Weekly ${pct7}%$(reset) $(rgb 120 120 120)· Resets in ${reset7}$(reset)"
  else
    seven_day_str="📅 $(rgb 180 255 180)Weekly ${pct7}%$(reset)"
  fi
fi

# ── Model name (magenta, robot icon) ─────────────────────────────────────────
model_str="🤖 $(rgb 200 80 220)${model}$(reset)"

# ── Assemble line ─────────────────────────────────────────────────────────────
out=""
out="${out}${repo_str}"
[ -n "$branch_str" ] && out="${out} ${branch_str}"
out="${out} $(pipe)${ctx_block}"
out="${out} $(pipe)${vel_str}"
[ -n "$token_str"     ] && out="${out} $(pipe)${token_str}"
[ -n "$cost_str"      ] && out="${out} $(pipe)${cost_str}"
[ -n "$session_str"   ] && out="${out} $(pipe)${session_str}"
[ -n "$five_hr_str"   ] && out="${out} $(pipe)${five_hr_str}"
[ -n "$seven_day_str" ] && out="${out} $(pipe)${seven_day_str}"
out="${out} $(pipe)${model_str}"

printf '%s\n' "$out"
