#!/bin/bash
# Focuses the window a Claude Code session runs in: the claude process
# working in <cwd>, then up its parents to the first one Hyprland has a
# window for (the terminal). Several in the same folder: the one used last.
# Nothing in a terminal (Claude's desktop app runs its own): that app.
cwd=${1:?usage: focus.sh <cwd>}
clients=$(hyprctl clients -j 2>/dev/null) || exit 1
address=$(
  for pid in $(pgrep -x claude); do
    [[ $(readlink "/proc/$pid/cwd" 2>/dev/null) == "$cwd" ]] || continue
    p=$pid
    while [[ -n $p && $p -gt 1 ]]; do
      hit=$(jq -r --argjson p "$p" '.[] | select(.pid == $p) | "\(.focusHistoryID) \(.address)"' <<<"$clients" | sort -n | head -1)
      [[ -n $hit ]] && { echo "$hit"; break; }
      p=$(awk '{print $4}' "/proc/$p/stat" 2>/dev/null)
    done
  done | sort -n | head -1 | cut -d' ' -f2
)
if [[ -z $address ]]; then
  exec omarchy-hyprland-focus-app com.anthropic.Claude
fi
hyprctl dispatch "hl.dsp.focus({ window = \"address:$address\" })" >/dev/null 2>&1 ||
  hyprctl dispatch focuswindow "address:$address" >/dev/null
