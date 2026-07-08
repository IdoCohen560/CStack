#!/usr/bin/env bash
# ============================================================================
#  CStack uninstaller — removes the hooks, custom skills, and plugins CStack
#  added. Leaves the Codex/GitNexus CLIs, your logins, and CLAUDE.md in place
#  (remove those by hand if you want them gone). Safe to re-run.
# ============================================================================
set -uo pipefail
say(){ printf "\n\033[1;36m==> %s\033[0m\n" "$*"; }
CLAUDE_DIR="$HOME/.claude"

say "Removing CStack hooks"
rm -f "$CLAUDE_DIR"/hooks/review-sig.sh \
      "$CLAUDE_DIR"/hooks/review-guard.sh \
      "$CLAUDE_DIR"/hooks/review-mark.sh \
      "$CLAUDE_DIR"/hooks/review-baseline.sh \
      "$CLAUDE_DIR"/hooks/graph-refresh.sh \
      "$CLAUDE_DIR"/hooks/skill-router.sh

say "Removing CStack skills"
rm -rf "$CLAUDE_DIR"/skills/orchestrated-build "$CLAUDE_DIR"/skills/llm-council
rm -rf "$CLAUDE_DIR"/skills/threejs-*
command -v agent-reach >/dev/null 2>&1 && agent-reach skill --uninstall >/dev/null 2>&1
rm -rf "$CLAUDE_DIR"/skills/agent-reach

say "Uninstalling plugins"
for p in taste-skill@taste-skill impeccable@impeccable gsap-skills@gsap-skills \
         agent-browser@agent-browser claude-video-vision@claude-video-vision \
         andrej-karpathy-skills@karpathy-skills codex@openai-codex; do
  claude plugin uninstall "$p" >/dev/null 2>&1 && echo "  removed $p" || true
done

say "Reversing GitNexus editor wiring"
command -v gitnexus >/dev/null 2>&1 && gitnexus uninstall >/dev/null 2>&1 && echo "  gitnexus unwired" || true

say "Removing CStack hooks from settings.json"
S="$CLAUDE_DIR/settings.json"
if [ -f "$S" ] && command -v jq >/dev/null 2>&1; then
  tmp="$(mktemp)"
  if jq '
      if .hooks then
        .hooks = ( .hooks
          | del(.SessionStart)
          | del(.UserPromptSubmit)
          | (if has("Stop")
             then .Stop = ( .Stop | map(select( (.hooks[0].command // "") | test("review-guard|graph-refresh") | not )) )
             else . end)
          | (if has("Stop") and (.Stop | length) == 0 then del(.Stop) else . end) )
      else . end
    ' "$S" > "$tmp" 2>/dev/null; then mv "$tmp" "$S"; echo "  cleaned settings.json"; else rm -f "$tmp"; echo "  (couldn't auto-clean settings.json — edit .hooks by hand)"; fi
fi

say "Done."
cat <<'NOTE'
  Left in place (remove by hand if you want):
    npm rm -g @openai/codex gitnexus mcporter   # the CLIs
    pipx uninstall agent-reach                   # Agent Reach CLI (+ rm -rf ~/.agent-reach ~/.mcporter)
    rm "$HOME/.claude/CLAUDE.md"                 # the operating doctrine
  Your gh / codex logins are untouched. Restart Claude Code to apply.
NOTE
