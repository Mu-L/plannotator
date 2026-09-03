#!/bin/bash
# Read-only inventory of the local Plannotator install footprint across ALL
# agent integrations. Run it BEFORE and AFTER a local smoke test, then diff the
# two manifests to see exactly what was added / removed / changed.
#
#   scripts/plannotator-inventory.sh              # prints report + writes manifest
#   scripts/plannotator-inventory.sh /tmp/before  # explicit manifest path
#
# Touches nothing. Plan/history/session DATA is intentionally excluded (it is
# user content, not install footprint) — we list its counts only.

DATA="${PLANNOTATOR_DATA_DIR:-$HOME/.plannotator}"
case "$DATA" in "~") DATA="$HOME";; "~/"*) DATA="$HOME/${DATA#\~/}";; esac
CLAUDE="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
CODEX="${CODEX_HOME:-$HOME/.codex}"
XDG="${XDG_CONFIG_HOME:-$HOME/.config}"

OUT="${1:-/tmp/plannotator-inventory-$(date +%Y%m%d-%H%M%S).manifest}"
hashof() { shasum -a 256 "$1" 2>/dev/null | cut -d' ' -f1 || sha256sum "$1" | cut -d' ' -f1; }

# --- the manifest: every install-relevant file as "<sha256>  <path>" -------
: > "$OUT"
roots=(
  "$HOME/.local/bin/plannotator" "$HOME/.local/bin/plannotator.exe"
  "$CLAUDE/skills" "$CLAUDE/commands"
  "$CLAUDE/plugins/marketplaces/plannotator"
  "$HOME/.agents/skills"
  "$CODEX/skills"
  "$XDG/opencode/commands"
  "$HOME/.gemini/commands"
  "$HOME/.kiro/skills" "$HOME/.kiro/agents"
  "$XDG/amp/plugins"
  "$DATA/migrations" "$DATA/install-prefs" "$DATA/config.json"
)
for r in "${roots[@]}"; do
  [ -e "$r" ] || continue
  if [ -f "$r" ]; then
    echo "$(hashof "$r")  $r" >> "$OUT"
  else
    while IFS= read -r f; do echo "$(hashof "$f")  $f" >> "$OUT"; done \
      < <(find "$r" -type f \( -iname '*plannotator*' -o -path '*plannotator*' \) 2>/dev/null)
  fi
done
# hook configs reference plannotator but aren't named it — track their hashes too
for cfg in "$CLAUDE/settings.json" "$CODEX/hooks.json" "$CODEX/config.toml"; do
  [ -f "$cfg" ] && grep -qi plannotator "$cfg" 2>/dev/null && echo "$(hashof "$cfg")  $cfg" >> "$OUT"
done
sort -k2 -o "$OUT" "$OUT"

# --- the human-readable report --------------------------------------------
echo "================ PLANNOTATOR INVENTORY  $(date '+%Y-%m-%d %H:%M:%S') ================"
echo "binary on PATH : $(command -v plannotator || echo '(none)')"
echo "version        : $(plannotator --version 2>/dev/null | head -1 || echo '?')"
echo "manifest       : $OUT   ($(wc -l < "$OUT" | tr -d ' ') files tracked)"
echo
section() { echo "── $1"; }
listdir() { # $1 label, $2 dir, $3 glob
  if [ -d "$2" ]; then
    local hits; hits=$(ls -1d "$2"/$3 2>/dev/null)
    if [ -n "$hits" ]; then echo "$hits" | sed "s#^#   #"; else echo "   (none)"; fi
  else echo "   (dir absent: $2)"; fi
}

section "Binary";                 [ -x "$HOME/.local/bin/plannotator" ] && echo "   $HOME/.local/bin/plannotator ($(wc -c <"$HOME/.local/bin/plannotator" | tr -d ' ') bytes)" || echo "   (absent)"
section "Claude Code skills";     listdir claude "$CLAUDE/skills" 'plannotator-*'
section "Claude Code commands (legacy)"; listdir claudecmd "$CLAUDE/commands" 'plannotator-*'
section "Claude marketplace plugin"; [ -d "$CLAUDE/plugins/marketplaces/plannotator" ] && echo "   present" || echo "   (absent)"
section "Codex / OpenAI agents skills (~/.agents)"; listdir agents "$HOME/.agents/skills" 'plannotator-*'
section "Codex skills (~/.codex)"; listdir codex "$CODEX/skills" 'plannotator-*'
section "OpenCode commands";      listdir opencode "$XDG/opencode/commands" 'plannotator-*'
section "Gemini commands";        listdir gemini "$HOME/.gemini/commands" 'plannotator-*'
section "Kiro skills + agent";    listdir kiro "$HOME/.kiro/skills" 'plannotator-*'; [ -f "$HOME/.kiro/agents/plannotator.json" ] && echo "   agent: present" || echo "   agent: (absent)"
section "Amp plugin";             [ -f "$XDG/amp/plugins/plannotator.ts" ] && echo "   present" || echo "   (absent)"
section "Data dir ($DATA)"
  echo "   migrations    : $(ls -1 "$DATA/migrations" 2>/dev/null | tr '\n' ' ')"
  echo "   install-prefs : $([ -f "$DATA/install-prefs" ] && echo present || echo absent)"
  echo "   config.json   : $([ -f "$DATA/config.json" ] && echo present || echo absent)"
  echo "   plans/history : $(ls -1 "$DATA/plans" 2>/dev/null | wc -l | tr -d ' ') plan files, $(find "$DATA/history" -type f 2>/dev/null | wc -l | tr -d ' ') history files (DATA, not touched)"
section "npm globals"
  npm ls -g --depth=0 2>/dev/null | grep -i plannotator | sed 's/^/   /' || echo "   (none or npm unavailable)"
section "Hook configs referencing plannotator"
  for cfg in "$CLAUDE/settings.json" "$CODEX/hooks.json" "$CODEX/config.toml"; do
    [ -f "$cfg" ] && grep -qi plannotator "$cfg" 2>/dev/null && echo "   $cfg" || true
  done
echo "==========================================================================="
