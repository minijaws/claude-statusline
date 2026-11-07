#!/bin/bash
# Claude Code subagent rows: name modeleffort · label | context tokens/window (pct) | elapsed
# One JSON line out per task: {"id": ..., "content": ...}. Colors match statusline.sh.
jq -c --argjson now "$(date +%s)" '
  def fmt: if . >= 1000000 then (. / 100000 | floor / 10 | tostring) + "M"
           elif . >= 1000 then (. / 100 | floor / 10 | tostring) + "k"
           else tostring end;
  def color(p): if p >= 80 then "\u001b[31m" elif p >= 60 then "\u001b[33m" else "\u001b[32m" end;
  def dur: if . >= 3600 then "\(. / 3600 | floor)h\(. % 3600 / 60 | floor)m"
           elif . >= 60 then "\(. / 60 | floor)m" else "\(.)s" end;
  "\u001b[0m" as $r | "\u001b[2m" as $dim |
  (.columns // 100) as $cols |
  .tasks[] |
  # model family + effort, e.g. "haikul" (family dim, effort plain): claude-haiku-5-5 -> haiku;
  # a numeric effort is a token budget
  (.model // "" | sub("^claude-"; "") | split("-")[0]) as $fam |
  (.effort // "" | if type == "number" then fmt
   else {low:"l",medium:"m",high:"h",xhigh:"xh",max:"max"}[.] // . end) as $eff |
  ($fam + $eff) as $me |
  (.name // .agentType // "agent") as $who |
  (.tokenCount // 0) as $used |
  (if (.contextWindowSize // 0) > 0 then ($used * 100 / .contextWindowSize | floor) else null end) as $pct |
  (if $pct == null then "⧉ \($used | fmt)"
   else "\(color($pct))⧉ \($used | fmt)/\(.contextWindowSize | fmt) (\($pct)%)\($r)" end) as $ctx |
  (($now - ((.startTime // ($now * 1000)) / 1000 | floor)) | if . < 0 then 0 else . end | dur) as $age |
  (if .status == "running" then "" else " \($dim)[\(.status)]\($r)" end) as $st |
  # leave room for the fixed segments (~40 cols) before truncating the label
  ([$cols - ($who | length) - ($me | length) - 41, 10] | max) as $room |
  ((.label // .description // "") | if length > $room then .[0:$room-1] + "…" else . end) as $label |
  (if $me == "" then "" else " \($dim)\($fam)\($r)\($eff)" end) as $mes |
  {id, content: "\($who)\($mes) \($dim)·\($r) \($label) \($dim)|\($r) \($ctx) \($dim)| \($age)\($r)\($st)"}
'
