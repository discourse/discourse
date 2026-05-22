#!/usr/bin/env bash
# Standardize rspec spec files to the writing guidelines. Resumable: state
# lives in $STATE_DIR. Run, kill, re-run — the loop picks up where it left
# off via state/done.txt, failed.txt, skipped.txt, no_op.txt.
#
# To run in the background:
#   nohup ./standardize/run.sh >> standardize/state/run.log 2>&1 &
# To stop: Ctrl-C or kill the pid; the file currently being processed will
# complete (commit-or-revert) before the next one starts.

set -euo pipefail
shopt -s inherit_errexit   # so subshell failures actually propagate

DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/config.sh"

mkdir -p "$STATE_DIR/runs"

require() {
  command -v "$1" >/dev/null 2>&1 || { echo "missing dependency: $1" >&2; exit 1; }
}
require gh
require jq
require git
require timeout

# ------------------------------------------------------------------ helpers

log() { printf '[%s] %s\n' "$(date -Iseconds)" "$*" >&2; }

log_row() {
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$@" >> "$RESULTS_TSV"
}

file_id() { echo "$1" | tr '/' '_'; }

mark_done()    { echo "$1" >> "$DONE_FILE"; }
mark_failed()  { echo "$1" >> "$FAILED_FILE"; }
mark_skipped() { echo "$1" >> "$SKIPPED_FILE"; }
mark_noop()    { echo "$1" >> "$NOOP_FILE"; }

is_processed() {
  grep -qxF "$1" "$DONE_FILE"    2>/dev/null && return 0
  grep -qxF "$1" "$FAILED_FILE"  2>/dev/null && return 0
  grep -qxF "$1" "$SKIPPED_FILE" 2>/dev/null && return 0
  grep -qxF "$1" "$NOOP_FILE"    2>/dev/null && return 0
  return 1
}

count_examples_in_file() {
  grep -cE '^[[:space:]]*(it|scenario|specify|example|feature)[[:space:](\"'"'"']' "$1" 2>/dev/null || echo 0
}

build_queue() {
  local patterns=()
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue
    patterns+=("$line")
  done < "$SCOPE_FILE"

  cd "$REPO_ROOT"
  for pat in "${patterns[@]}"; do
    find . -path "./$pat" -type f 2>/dev/null | sed 's|^\./||'
  done | sort -u > "$QUEUE_FILE.raw"

  : > "$QUEUE_FILE"
  while IFS= read -r f; do
    is_processed "$f" && continue
    printf '%s\n' "$f" >> "$QUEUE_FILE"
  done < "$QUEUE_FILE.raw"
  rm -f "$QUEUE_FILE.raw"
}

run_rspec() {
  local file="$1" log_path="$2"
  ( cd "$REPO_ROOT" \
    && timeout --preserve-status "$RSPEC_TIMEOUT_SEC" \
       bin/rspec "$file" --format progress --no-color \
  ) > "$log_path" 2>&1
}

check_forbidden_constructs() {
  local file="$1"
  local diff_added
  diff_added=$(git -C "$REPO_ROOT" diff HEAD --unified=0 -- "$file" \
    | grep -E '^\+' | grep -vE '^\+\+\+ ' || true)

  local bad=0
  if echo "$diff_added" | grep -qE '\b(xit|xspecify|xfeature|xdescribe|xcontext|fit|fdescribe|fcontext)\b'; then
    log "  forbidden: x-/f-prefixed example/group introduced"
    bad=1
  fi
  if echo "$diff_added" | grep -qE '(,[[:space:]]*skip:|,[[:space:]]*:skip\b|,[[:space:]]*pending:)'; then
    log "  forbidden: skip:/pending: metadata introduced"
    bad=1
  fi
  if echo "$diff_added" | grep -qE '^\+[[:space:]]*(skip|pending)([[:space:]]|$|\()'; then
    log "  forbidden: bare skip/pending call introduced"
    bad=1
  fi
  return "$bad"
}

# ------------------------------------------------------------------ bootstrap

cd "$REPO_ROOT"

if [ ! -f "$STATE_DIR/initialized" ]; then
  log "bootstrapping"

  gh auth status >/dev/null

  [ -f "$GUIDELINES_FILE" ] || {
    echo "guidelines file missing: $GUIDELINES_FILE" >&2
    exit 1
  }

  log "creating $WORKING_BRANCH from origin/main"
  git fetch origin main --quiet
  git checkout -B "$WORKING_BRANCH" origin/main --quiet
  git push --force-with-lease -u origin "$WORKING_BRANCH"

  printf 'About to open a DRAFT pull request titled:\n  %s\nbase: main, head: %s, repo: %s\nProceed? [y/N] ' \
    "$PR_TITLE" "$WORKING_BRANCH" "$GH_REPO"
  read -r confirm
  if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
    pr_url=$(gh pr create --draft \
      --repo "$GH_REPO" \
      --base main \
      --head "$WORKING_BRANCH" \
      --title "$PR_TITLE" \
      --body-file "$PR_BODY_FILE" 2>&1 || true)
    echo "$pr_url" > "$STATE_DIR/pr_url"
    log "PR: $pr_url"
  else
    log "skipping PR creation (you can open it manually later)"
  fi

  if [ ! -f "$RESULTS_TSV" ]; then
    printf 'file\tresult\tpre_examples\tpost_examples\tduration_sec\tnote\n' > "$RESULTS_TSV"
  fi

  touch "$DONE_FILE" "$FAILED_FILE" "$SKIPPED_FILE" "$NOOP_FILE"
  touch "$STATE_DIR/initialized"
fi

build_queue
total=$(wc -l < "$QUEUE_FILE")
log "queue: $total file(s) pending"
[ "$total" -eq 0 ] && { log "nothing to do; exit"; exit 0; }

# ------------------------------------------------------------------ main loop

trap 'log "interrupted"; exit 130' INT TERM

processed=0
while IFS= read -r target_file; do
  processed=$(( processed + 1 ))
  iter_dir="$STATE_DIR/runs/$(file_id "$target_file")"
  mkdir -p "$iter_dir"

  log "=== $processed/$total: $target_file ==="

  if is_processed "$target_file"; then
    log "already processed; skip"
    continue
  fi

  [ -f "$target_file" ] || {
    log "file no longer exists; skip"
    mark_skipped "$target_file"
    log_row "$target_file" "skipped" "" "" "" "file missing"
    continue
  }

  cp "$target_file" "$iter_dir/before.rb"
  pre_examples=$(count_examples_in_file "$target_file")

  log "  baseline rspec ($pre_examples examples)"
  start=$(date +%s)
  rc=0
  run_rspec "$target_file" "$iter_dir/pre.log" || rc=$?
  duration=$(( $(date +%s) - start ))
  if [ "$rc" -ne 0 ]; then
    log "  baseline FAILED (rc=$rc, ${duration}s); marking skipped"
    mark_skipped "$target_file"
    log_row "$target_file" "skipped" "$pre_examples" "" "$duration" "baseline rspec failed (rc=$rc)"
    sleep "$SLEEP_BETWEEN_FILES"
    continue
  fi
  log "  baseline passed (${duration}s)"

  log "  proposing changes"
  if ! "$DIR/propose.sh" "$iter_dir" "$target_file"; then
    log "  propose.sh failed"
    git checkout -- "$target_file" 2>/dev/null || true
    mark_failed "$target_file"
    log_row "$target_file" "failed" "$pre_examples" "" "" "propose.sh exit non-zero"
    sleep "$SLEEP_BETWEEN_FILES"
    continue
  fi

  summary=$(cat "$iter_dir/summary.txt")

  if git -C "$REPO_ROOT" diff --quiet -- "$target_file"; then
    log "  no edits ($summary)"
    mark_noop "$target_file"
    log_row "$target_file" "no_op" "$pre_examples" "$pre_examples" "" "$summary"
    sleep "$SLEEP_BETWEEN_FILES"
    continue
  fi

  out_of_scope=$(git -C "$REPO_ROOT" diff --name-only HEAD \
    | grep -vxF "$target_file" || true)
  if [ -n "$out_of_scope" ]; then
    log "  out-of-scope edits detected, reverting:"
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      log "    $f"
      git -C "$REPO_ROOT" checkout HEAD -- "$f" 2>/dev/null || true
    done <<< "$out_of_scope"
    if git -C "$REPO_ROOT" diff --quiet -- "$target_file"; then
      mark_failed "$target_file"
      log_row "$target_file" "failed" "$pre_examples" "" "" "only out-of-scope edits made"
      sleep "$SLEEP_BETWEEN_FILES"
      continue
    fi
  fi

  post_examples=$(count_examples_in_file "$target_file")
  min_examples=$(awk -v b="$pre_examples" -v t="$COVERAGE_LOSS_TOLERANCE_PCT" \
    'BEGIN{printf "%d", b * (100 - t) / 100}')
  if [ "$post_examples" -lt "$min_examples" ]; then
    log "  coverage regression: $post_examples < $min_examples (was $pre_examples); reverting"
    git -C "$REPO_ROOT" checkout -- "$target_file"
    mark_failed "$target_file"
    log_row "$target_file" "failed" "$pre_examples" "$post_examples" "" "coverage regression: $summary"
    sleep "$SLEEP_BETWEEN_FILES"
    continue
  fi

  if ! check_forbidden_constructs "$target_file"; then
    log "  forbidden construct introduced; reverting"
    git -C "$REPO_ROOT" checkout -- "$target_file"
    mark_failed "$target_file"
    log_row "$target_file" "failed" "$pre_examples" "$post_examples" "" "forbidden construct: $summary"
    sleep "$SLEEP_BETWEEN_FILES"
    continue
  fi

  log "  verifying rspec ($post_examples examples)"
  start=$(date +%s)
  rc=0
  run_rspec "$target_file" "$iter_dir/post.log" || rc=$?
  duration=$(( $(date +%s) - start ))
  if [ "$rc" -ne 0 ]; then
    log "  POST-EDIT FAIL (rc=$rc, ${duration}s); reverting"
    git -C "$REPO_ROOT" checkout -- "$target_file"
    mark_failed "$target_file"
    log_row "$target_file" "failed" "$pre_examples" "$post_examples" "$duration" "rspec broke: $summary"
    sleep "$SLEEP_BETWEEN_FILES"
    continue
  fi

  cp "$target_file" "$iter_dir/after.rb"
  git -C "$REPO_ROOT" add -- "$target_file"
  if ! git -C "$REPO_ROOT" \
       -c user.name="autoresearch" \
       -c user.email="autoresearch@invalid" \
       commit -m "DEV: standardize $target_file"$'\n\n'"$summary" --quiet; then
    log "  commit failed (lint hook?); reverting"
    git -C "$REPO_ROOT" checkout -- "$target_file"
    mark_failed "$target_file"
    log_row "$target_file" "failed" "$pre_examples" "$post_examples" "$duration" "commit hook failed: $summary"
    sleep "$SLEEP_BETWEEN_FILES"
    continue
  fi

  git -C "$REPO_ROOT" push origin "$WORKING_BRANCH" --quiet 2>/dev/null \
    || log "  WARNING: push failed (you may need to push manually)"

  mark_done "$target_file"
  log_row "$target_file" "done" "$pre_examples" "$post_examples" "$duration" "$summary"
  log "  DONE ($pre_examples → $post_examples examples)"

  sleep "$SLEEP_BETWEEN_FILES"
done < "$QUEUE_FILE"

# ------------------------------------------------------------------ summary

log "queue exhausted"
log "summary:"
log "  done:    $(wc -l < "$DONE_FILE")"
log "  no_op:   $(wc -l < "$NOOP_FILE")"
log "  failed:  $(wc -l < "$FAILED_FILE")"
log "  skipped: $(wc -l < "$SKIPPED_FILE")"
