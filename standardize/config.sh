#!/usr/bin/env bash
# Configuration for the rspec-test standardization loop.
# Override any of these from the environment when invoking run.sh.

REPO_ROOT="${REPO_ROOT:-/var/www/discourse}"
GH_REPO="${GH_REPO:-discourse/discourse}"

WORKING_BRANCH="${WORKING_BRANCH:-tgxworld/standardize-rspec}"
PR_TITLE="${PR_TITLE:-DEV: standardize rspec tests per writing guidelines}"
PR_BODY_FILE="${PR_BODY_FILE:-$REPO_ROOT/standardize/PR_BODY.md}"

STATE_DIR="${STATE_DIR:-$REPO_ROOT/standardize/state}"
SCOPE_FILE="${SCOPE_FILE:-$REPO_ROOT/standardize/SCOPE}"
PROMPT_FILE="${PROMPT_FILE:-$REPO_ROOT/standardize/PROMPT.md}"
GUIDELINES_FILE="${GUIDELINES_FILE:-$REPO_ROOT/.skills/discourse-writing-rspec-tests/SKILL.md}"

RESULTS_TSV="$STATE_DIR/results.tsv"
QUEUE_FILE="$STATE_DIR/queue.txt"
DONE_FILE="$STATE_DIR/done.txt"
FAILED_FILE="$STATE_DIR/failed.txt"
SKIPPED_FILE="$STATE_DIR/skipped.txt"
NOOP_FILE="$STATE_DIR/no_op.txt"

# Coverage guard: reject a candidate file if `it`/`scenario`/etc. count
# drops by more than this percentage. Generous default because the
# guidelines explicitly endorse consolidating examples.
COVERAGE_LOSS_TOLERANCE_PCT="${COVERAGE_LOSS_TOLERANCE_PCT:-50}"

# Time budget per rspec invocation (seconds). Files that exceed this
# get killed and marked as `skipped`.
RSPEC_TIMEOUT_SEC="${RSPEC_TIMEOUT_SEC:-600}"

# Pacing.
SLEEP_BETWEEN_FILES="${SLEEP_BETWEEN_FILES:-1}"

# Claude Code invocation.
CLAUDE_BIN="${CLAUDE_BIN:-claude}"
CLAUDE_MODEL="${CLAUDE_MODEL:-claude-opus-4-7}"
CLAUDE_EFFORT="${CLAUDE_EFFORT:-high}"  # low | medium | high | xhigh | max
