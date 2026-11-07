#!/bin/bash
# Claude Code status line: model | cwd | git branch | context tokens | rate-limit usage | cost
input=$(cat)
now=$(date +%s)

r=$'\033[0m'; dim=$'\033[2m'

model=$(jq -r '.model.display_name // "?"' <<<"$input")
cwd=$(jq -r '.workspace.current_dir // .cwd // ""' <<<"$input")
dir=$(basename "$cwd")

fmt() { # bytes-style k/M formatting
  awk -v n="$1" 'BEGIN{
    if (n >= 1000000) { v=n/1000000; u="M" }
    else if (n >= 1000) { v=n/1000; u="k" }
    else { printf "%d", n; exit }
    if (v == int(v)) printf "%d%s", v, u; else printf "%.1f%s", v, u
  }'
}

pressure() { # green < 60% <= yellow < 80% <= red
  if   [ "$1" -ge 80 ]; then printf '\033[31m'
  elif [ "$1" -ge 60 ]; then printf '\033[33m'
  else                       printf '\033[32m'
  fi
}

hhmm() { # epoch -> HH:MM; BSD date takes -r, GNU takes -d @
  date -r "$1" +%H:%M 2>/dev/null || date -d "@$1" +%H:%M
}

# --- context window ---
used=$(jq -r '.context_window.total_input_tokens // 0' <<<"$input")
size=$(jq -r '.context_window.context_window_size // 0' <<<"$input")
pct=$(jq -r '.context_window.used_percentage // 0 | floor' <<<"$input")

ctx="$(fmt "$used")"
[ "$size" -gt 0 ] && ctx="$ctx/$(fmt "$size") (${pct}%)"
cc=$(pressure "$pct")

remaining() { # seconds -> "3d" / "2h14m" / "47m"; rounded up, so it never
  awk -v s="$1" 'BEGIN{    # claims the window resets sooner than it does
    if (s <= 0) { printf "<1m"; exit }
    m = int((s + 59) / 60)
    if (m >= 1440)   printf "%dd", int((m + 1439) / 1440)
    else if (m >= 60) printf "%dh%02dm", int(m / 60), m % 60
    else              printf "%dm", m
  }'
}

# --- rate-limit usage (each window labelled with its time left), omitted entirely when not reported ---
usage=""
for w in five_hour:5h seven_day:7d; do
  key=${w%%:*}; label=${w##*:}
  p=$(jq -r --arg k "$key" '.rate_limits[$k].used_percentage // empty | floor' <<<"$input")
  [ -z "$p" ] && continue
  reset=$(jq -r --arg k "$key" '.rate_limits[$k].resets_at // empty' <<<"$input")
  [ -n "$reset" ] && label="$(remaining "$((reset - now))")"
  seg="$(pressure "$p")${label} ${p}%${r}"
  if [ -z "$usage" ]; then usage="$seg"; else usage="$usage ${dim}·${r} $seg"; fi
done
[ -n "$usage" ] && usage=" ${dim}|${r} $usage"

# --- session cost (API-equivalent estimate, resets each session) ---
cost=$(jq -r '.cost.total_cost_usd // empty' <<<"$input")
if [ -n "$cost" ]; then
  cost=$(awk -v c="$cost" 'BEGIN{ printf "$%.2f", c }')
  cost=" ${dim}|${r} ${dim}${cost}${r}"
fi

# --- prompt cache: wall-clock time the main conversation's cache goes cold ---
# Claude Code reports this in .prompt_cache (main thread only, subagents excluded)
# with the real TTL, so a drop to 5m in overage is handled. It also re-runs the
# status line at expires_at, so "cold" appears on time. Omitted before the first
# response, or when the provider doesn't report caching.
cache=""
read -r observed warm exp < <(jq -r '.prompt_cache // empty
  | "\(.caching_observed) \(.warm) \(.expires_at // 0 | floor)"' <<<"$input")
if [ "$observed" = "true" ]; then
  left=$((exp - now))
  [ "$warm" = "true" ] || left=0
  if   [ "$left" -le 0 ]; then cache="$(pressure 100)cold${r}"
  elif [ "$left" -le 300 ]; then cache="$(pressure 60)$(hhmm "$exp")${r}"
  else                          cache="$(pressure 0)$(hhmm "$exp")${r}"
  fi
  cache=" ${dim}|${r} ${dim}⧗${r} $cache"
fi

# --- git branch: only for repos with a remote, so a fresh local `git init` stays quiet ---
branch=""
if [ -n "$cwd" ] && [ -n "$(git -C "$cwd" remote 2>/dev/null)" ]; then
  b=$(git -C "$cwd" branch --show-current 2>/dev/null)
  [ -n "$b" ] && branch=" ${dim}|${r} ${b}"
fi

printf '%s %s|%s %s%s %s|%s %s⧉ %s%s%s%s%s' \
  "$model" "$dim" "$r" "$dir" "$branch" "$dim" "$r" "$cc" "$ctx" "$r" "$cache" "$usage" "$cost"
