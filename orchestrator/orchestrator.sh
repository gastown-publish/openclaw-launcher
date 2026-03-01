#!/bin/bash
# orchestrator.sh — Hourly orchestrator launched via openclaw cron
# Brain: Kimi K2.5 (kimi-coding/k2p5) driving Claude Code AIs
#
# Responsibilities:
#   1. Review, test, approve, and merge GitHub PRs
#   2. Check for updates: openclaw, claude code, kimi code, openclaw-launcher, ais
#   3. Session maintenance via openclaw sessions cleanup
#   4. Memory-aware decisions via openclaw memory search

set -euo pipefail

# Fix: OPENCLAW_HOME must not be set
unset OPENCLAW_HOME
export PATH="${HOME}/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${HOME}/logs"
LOG_FILE="${LOG_DIR}/orchestrator-$(date -u +%Y-%m-%d).log"
LAUNCHER_REPO="${HOME}/openclaw-launcher"
REPOS_TO_WATCH=(
  "gastown-publish/openclaw-launcher"
)

mkdir -p "$LOG_DIR"

log() {
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  echo "[$ts] [orchestrator] $1" | tee -a "$LOG_FILE"
}

rotate_log() {
  if [ -f "$LOG_FILE" ]; then
    local size
    size=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
    if [ "$size" -gt 5242880 ]; then
      mv "$LOG_FILE" "$LOG_FILE.old"
      log "Log rotated"
    fi
  fi
}

# ─── 1. PR Review, Test, Approve, Merge ───────────────────────────────────────

review_and_merge_prs() {
  log "=== PR Review Cycle ==="

  for repo in "${REPOS_TO_WATCH[@]}"; do
    log "Checking PRs for $repo..."

    local prs
    prs=$(gh pr list --repo "$repo" --state open --json number,title,headRefName,author --limit 20 2>/dev/null || echo "[]")

    local count
    count=$(echo "$prs" | jq 'length')

    if [ "$count" -eq 0 ]; then
      log "No open PRs for $repo"
      continue
    fi

    log "Found $count open PR(s) for $repo"

    echo "$prs" | jq -c '.[]' | while IFS= read -r pr; do
      local pr_number pr_title pr_branch pr_author
      pr_number=$(echo "$pr" | jq -r '.number')
      pr_title=$(echo "$pr" | jq -r '.title')
      pr_branch=$(echo "$pr" | jq -r '.headRefName')
      pr_author=$(echo "$pr" | jq -r '.author.login')

      log "Reviewing PR #${pr_number}: ${pr_title} (by ${pr_author})"

      # Get the diff
      local diff
      diff=$(gh pr diff "$pr_number" --repo "$repo" 2>/dev/null || echo "")

      if [ -z "$diff" ]; then
        log "Could not fetch diff for PR #${pr_number}, skipping"
        continue
      fi

      # Search memory for relevant context
      local memory_context
      memory_context=$(openclaw memory search --query "$pr_title" 2>/dev/null | head -20 || echo "No memory context")

      # Drive Claude Code AI to review the PR
      local review_prompt
      review_prompt="You are a code reviewer for the openclaw-launcher project.

Review this pull request and determine if it should be approved and merged.

PR #${pr_number}: ${pr_title}
Author: ${pr_author}
Branch: ${pr_branch}

Memory context from previous sessions:
${memory_context}

Diff:
${diff}

Instructions:
1. Check for security issues, bugs, and code quality
2. Verify the changes make sense given the project context
3. Check if tests would pass (look for obvious breakage)
4. Output EXACTLY one of these verdicts on the last line:
   VERDICT: APPROVE
   VERDICT: REQUEST_CHANGES
   VERDICT: SKIP
5. If REQUEST_CHANGES, explain what needs fixing before the verdict line"

      local review_result
      review_result=$(claude --dangerously-skip-permissions -p "$review_prompt" --output-format text 2>/dev/null || echo "VERDICT: SKIP")

      local verdict
      verdict=$(echo "$review_result" | grep "^VERDICT:" | tail -1 | awk '{print $2}')

      case "$verdict" in
        APPROVE)
          log "PR #${pr_number} APPROVED by Claude Code AI"
          gh pr review "$pr_number" --repo "$repo" --approve --body "Automated review by OpenClaw Orchestrator (Claude Code AI). Changes look good." 2>/dev/null || true
          gh pr merge "$pr_number" --repo "$repo" --squash --auto 2>/dev/null || \
            gh pr merge "$pr_number" --repo "$repo" --squash 2>/dev/null || \
            log "Could not auto-merge PR #${pr_number} (may need manual merge)"
          ;;
        REQUEST_CHANGES)
          local review_body
          review_body=$(echo "$review_result" | grep -v "^VERDICT:" | tail -20)
          log "PR #${pr_number} CHANGES REQUESTED"
          gh pr review "$pr_number" --repo "$repo" --request-changes --body "Automated review by OpenClaw Orchestrator:

${review_body}" 2>/dev/null || true
          ;;
        *)
          log "PR #${pr_number} SKIPPED (verdict: ${verdict:-none})"
          ;;
      esac
    done
  done
}

# ─── 2. Update Checks ─────────────────────────────────────────────────────────

check_updates() {
  log "=== Update Check Cycle ==="

  local updates_found=0

  # OpenClaw
  local current_openclaw installed_openclaw
  current_openclaw=$(npm show openclaw version 2>/dev/null || echo "unknown")
  installed_openclaw=$(openclaw --version 2>/dev/null | grep -oP '[\d.]+' | head -1 || echo "unknown")
  if [ "$current_openclaw" != "$installed_openclaw" ] && [ "$current_openclaw" != "unknown" ]; then
    log "UPDATE AVAILABLE: openclaw $installed_openclaw -> $current_openclaw"
    npm install -g openclaw@latest 2>/dev/null && log "openclaw updated to $current_openclaw" || log "openclaw update failed"
    updates_found=$((updates_found + 1))
  else
    log "openclaw is up to date ($installed_openclaw)"
  fi

  # Claude Code
  local current_claude installed_claude
  current_claude=$(npm show @anthropic-ai/claude-code version 2>/dev/null || echo "unknown")
  installed_claude=$(claude --version 2>/dev/null | grep -oP '[\d.]+' | head -1 || echo "unknown")
  if [ "$current_claude" != "$installed_claude" ] && [ "$current_claude" != "unknown" ]; then
    log "UPDATE AVAILABLE: claude-code $installed_claude -> $current_claude"
    npm install -g @anthropic-ai/claude-code@latest 2>/dev/null && log "claude-code updated to $current_claude" || log "claude-code update failed"
    updates_found=$((updates_found + 1))
  else
    log "claude-code is up to date ($installed_claude)"
  fi

  # Kimi Code
  local current_kimi installed_kimi
  current_kimi=$(npm show kimi-code version 2>/dev/null || echo "unknown")
  installed_kimi=$(kimi --version 2>/dev/null | grep -oP '[\d.]+' | head -1 || echo "unknown")
  if [ "$current_kimi" != "$installed_kimi" ] && [ "$current_kimi" != "unknown" ]; then
    log "UPDATE AVAILABLE: kimi-code $installed_kimi -> $current_kimi"
    npm install -g kimi-code@latest 2>/dev/null && log "kimi-code updated to $current_kimi" || log "kimi-code update failed"
    updates_found=$((updates_found + 1))
  else
    log "kimi-code is up to date ($installed_kimi)"
  fi

  # OpenClaw Launcher (git pull)
  if [ -d "$LAUNCHER_REPO/.git" ]; then
    local before_hash after_hash
    before_hash=$(git -C "$LAUNCHER_REPO" rev-parse HEAD 2>/dev/null)
    git -C "$LAUNCHER_REPO" pull --ff-only origin main 2>/dev/null || true
    after_hash=$(git -C "$LAUNCHER_REPO" rev-parse HEAD 2>/dev/null)
    if [ "$before_hash" != "$after_hash" ]; then
      log "UPDATE: openclaw-launcher updated ($before_hash -> $after_hash)"
      updates_found=$((updates_found + 1))
    else
      log "openclaw-launcher is up to date ($before_hash)"
    fi
  else
    log "openclaw-launcher repo not found at $LAUNCHER_REPO"
  fi

  # AIs — check if claude/kimi binaries are functional
  if claude --version >/dev/null 2>&1; then
    log "Claude Code AI: operational"
  else
    log "WARNING: Claude Code AI not responding"
  fi

  if kimi --version >/dev/null 2>&1; then
    log "Kimi Code AI: operational"
  else
    log "WARNING: Kimi Code AI not responding"
  fi

  log "Update check complete. $updates_found update(s) applied."
}

# ─── 3. Session Maintenance ───────────────────────────────────────────────────

maintain_sessions() {
  log "=== Session Maintenance ==="

  openclaw sessions cleanup --all-agents --enforce 2>/dev/null && \
    log "Session cleanup completed" || \
    log "Session cleanup failed (gateway may be down)"

  # Reindex memory after session cleanup
  openclaw memory index 2>/dev/null && \
    log "Memory reindexed" || \
    log "Memory reindex failed"
}

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
  log "========================================"
  log "OpenClaw Orchestrator — Hourly Run"
  log "Model: Kimi K2.5 (kimi-coding/k2p5)"
  log "Executor: Claude Code AIs"
  log "========================================"

  rotate_log

  # Phase 1: Session maintenance
  maintain_sessions

  # Phase 2: PR review and merge
  review_and_merge_prs

  # Phase 3: Update checks
  check_updates

  log "Orchestrator run complete."
  log "========================================"
}

main "$@"
