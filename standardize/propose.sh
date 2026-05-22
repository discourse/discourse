#!/usr/bin/env bash
# Invoke claude -p to standardize ONE spec file for this iteration.
# Usage: propose.sh <iter_dir> <target_file>
# Exits 0 on success (summary.txt + rationale.md written),
# non-zero on failure (no summary.txt produced).

set -euo pipefail
shopt -s inherit_errexit

iter_dir="$1"
target_file="$2"
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/config.sh"

mkdir -p "$iter_dir"

# Build the prompt: base instructions + target file + recent results context.
{
  cat "$PROMPT_FILE"
  echo
  echo "## This iteration's target"
  echo
  echo "TARGET_FILE: $target_file"
  echo "iter_dir:    $iter_dir"
  echo
  echo "## Recent results (tail of standardization log)"
  echo
  if [ -f "$RESULTS_TSV" ]; then
    tail -n 20 "$RESULTS_TSV"
  else
    echo "(none yet — first file in this run)"
  fi
} > "$iter_dir/prompt.txt"

claude_args=(-p --permission-mode bypassPermissions)
[ -n "${CLAUDE_MODEL:-}" ] && claude_args+=(--model "$CLAUDE_MODEL")
[ -n "${CLAUDE_EFFORT:-}" ] && claude_args+=(--effort "$CLAUDE_EFFORT")

# Forbid GitHub MCP write tools. The proposer is reviewing and editing local
# files only; the driver handles commits.
disallowed_github_writes="\
mcp__github__push_files,\
mcp__github__create_pull_request,\
mcp__github__create_pull_request_with_copilot,\
mcp__github__create_or_update_file,\
mcp__github__delete_file,\
mcp__github__create_branch,\
mcp__github__create_repository,\
mcp__github__update_pull_request,\
mcp__github__update_pull_request_branch,\
mcp__github__merge_pull_request,\
mcp__github__pull_request_review_write,\
mcp__github__add_issue_comment,\
mcp__github__add_comment_to_pending_review,\
mcp__github__add_reply_to_pull_request_comment,\
mcp__github__issue_write,\
mcp__github__sub_issue_write,\
mcp__github__assign_copilot_to_issue,\
mcp__github__fork_repository,\
mcp__github__request_copilot_review,\
mcp__github__run_secret_scanning"
claude_args+=(--disallowed-tools "$disallowed_github_writes")

# Stream-json output so each tool call shows live progress in the operator's
# terminal. Full event stream lands in claude_stdout.log.
claude_args+=(--output-format stream-json --verbose)

file_label=$(basename "$iter_dir")
stream_filter='
  if .type == "assistant" then
    (.message.content // []) | .[] |
      if .type == "tool_use" then
        "  '"$file_label"' [" + (.name // "?") + "] "
        + ((.input // {}) | tojson | .[0:240])
      elif .type == "text" then
        "  '"$file_label"' [text] "
        + ((.text // "") | gsub("\n"; "↵") | .[0:240])
      else empty end
  elif .type == "result" then
    "  '"$file_label"' [done] cost=$" + ((.total_cost_usd // 0) | tostring)
      + " duration=" + (((.duration_ms // 0) / 1000 | floor) | tostring) + "s"
  else empty end
'

cd "$REPO_ROOT"
export TARGET_FILE="$target_file"

claude_rc=0
set -o pipefail
env -u GH_TOKEN -u GITHUB_TOKEN \
  "$CLAUDE_BIN" "${claude_args[@]}" \
  < "$iter_dir/prompt.txt" \
  2> "$iter_dir/claude_stderr.log" \
  | tee "$iter_dir/claude_stdout.log" \
  | jq -rc --unbuffered "$stream_filter" >&2 \
  || claude_rc=${PIPESTATUS[0]}
set +o pipefail

if [ ! -s "$iter_dir/summary.txt" ]; then
  echo "no summary.txt written by claude (rc=$claude_rc)" >&2
  exit 2
fi

if [ "$claude_rc" -ne 0 ]; then
  echo "WARNING: claude -p exited rc=$claude_rc but summary.txt present; using it" >&2
fi

# Normalise summary: trim trailing whitespace + newlines.
summary="$(tr -d '\r\n' < "$iter_dir/summary.txt" | sed 's/[[:space:]]*$//')"
printf '%s' "$summary" > "$iter_dir/summary.txt"

exit 0
