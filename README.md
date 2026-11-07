# claude-statusline

A status line for [Claude Code](https://claude.com/claude-code), plus a matching
row format for subagents.

## Main status line — `statusline.sh`

```
Opus 5.5h | my-project:main* | ⧉ 50k/200k (25%) | ⧗ 22:05 | 2h14m 31% · 3d 12% | $1.84
```

| Segment | Source |
|---|---|
| Model + effort | `model.display_name`, `effort.level` as `l` `m` `h` `xh` `max`; dimmed, no separator; hidden when the model has none |
| `dir:branch` | `workspace.current_dir`, `git status`; branch shown only when the repo has a remote, hidden when detached. Markers as in git's prompt: `*` unstaged, `+` staged, `>` ahead, `<` behind, `<>` diverged. Untracked files aren't checked, to keep it fast in big repos |
| `⧉` context used / window (pct) | `context_window.*`, green < 60% ≤ yellow < 80% ≤ red |
| `⧗` time the prompt cache goes cold | `prompt_cache.expires_at`; yellow in the last 5 minutes, red `cold` once expired. Hidden until the first response, or if the provider doesn't report caching |
| Rate-limit windows, labelled with time to reset | `rate_limits.five_hour`, `rate_limits.seven_day`; omitted when not reported |
| Session cost (API-equivalent estimate) | `cost.total_cost_usd` |

## Subagent rows — `subagent-statusline.sh`

Each agent in the panel below the prompt shows its **own** context, not the main
conversation's:

```
Explore haikul · Searching the repo for statusline handl… | ⧉ 143.2k/200k (71%) | 3m
```

Name (or agent type), model family (dimmed) and effort (same letters, or the token budget like `16k`; each shown once known), progress label (truncated to fit), context tokens/window with
the same colour thresholds, elapsed time, and `[completed]` / `[failed]` once an
agent stops.

## Install

Requires `bash` and `jq`.

```bash
git clone https://github.com/minijaws/claude-statusline.git
cp claude-statusline/*.sh ~/.claude/
chmod +x ~/.claude/statusline.sh ~/.claude/subagent-statusline.sh
```

Then add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh",
    "padding": 0
  },
  "subagentStatusLine": {
    "type": "command",
    "command": "~/.claude/subagent-statusline.sh"
  }
}
```

The subagent rows need a Claude Code version with `subagentStatusLine`; the `⧗`
segment needs one that sends `prompt_cache` (v2.1.251+). See the
[status line docs](https://code.claude.com/docs/en/statusline) for the input fields.

## License

MIT — see [LICENSE](LICENSE).
