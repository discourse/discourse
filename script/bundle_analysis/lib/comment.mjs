import { createHash } from "crypto";
import { readFileSync, statSync } from "fs";
import { join } from "path";
import { REPORT_SCHEMA } from "./analyze.mjs";
import { HEADING, renderComment } from "./render.mjs";

const MARKER =
  /<!-- bundle-analysis:v1 state=(active|resolved|superseded) keys=([0-9a-f,]*) -->/g;
const BOT_LOGIN = "github-actions[bot]";
const MAX_REPORT_BYTES = 20 * 1024 * 1024;
const MAX_KEYS = 300;

export function hashKey(key) {
  return createHash("sha256").update(key).digest("hex").slice(0, 12);
}

/** What a marker stores and compares: capped, to stay inside GitHub's comment limit. */
function keyHashes(keys) {
  return [...new Set(keys.map(hashKey))].sort().slice(0, MAX_KEYS);
}

export function marker(state, keys) {
  return `<!-- bundle-analysis:v1 state=${state} keys=${keyHashes(keys).join(",")} -->`;
}

/**
 * The marker is always appended last. The body also holds strings from the
 * untrusted report, which could imitate a marker, so only the last one counts.
 */
export function parseMarker(body) {
  const match = [...(body ?? "").matchAll(MARKER)].at(-1);
  return match
    ? { state: match[1], keys: new Set(match[2].split(",").filter(Boolean)) }
    : null;
}

/**
 * What to do with the PR comment, given the current findings and the newest
 * existing bundle-analysis comment. Edits notify nobody, so a finding the
 * comment does not already have gets a new comment.
 */
export function decideAction({ keys, existing }) {
  const active = existing?.marker.state === "active" ? existing : null;
  if (keys.length === 0) {
    return active ? { type: "resolve", comment: active } : { type: "none" };
  }
  if (!active) {
    return { type: "create" };
  }
  const known = keyHashes(keys).every((hash) => active.marker.keys.has(hash));
  return known
    ? { type: "update", comment: active }
    : { type: "supersede", comment: active };
}

/**
 * The report from bundle-analysis.yml. It comes from untrusted PR code;
 * rendering escapes every string in it and rejects anything else where a
 * size belongs.
 */
export function readReport(dir) {
  const path = join(dir, "report.json");
  const stat = statSync(path, { throwIfNoEntry: false });
  if (!stat?.isFile() || stat.size > MAX_REPORT_BYTES) {
    throw new Error("report.json is missing or too large");
  }
  const report = JSON.parse(readFileSync(path, "utf8"));
  if (report?.schema !== REPORT_SCHEMA) {
    throw new Error(`Unsupported report schema: ${report?.schema}`);
  }
  return report;
}

/**
 * Entry point for the trusted comment workflow (actions/github-script). The
 * PR comes from the workflow_run event, which the PR's code cannot change:
 * the open PR whose head is the commit that was analyzed.
 */
export async function run({ github, context, core, artifactDir, budgetPath }) {
  const workflowRun = context.payload.workflow_run;
  const headRepo = workflowRun.head_repository;
  const { owner, repo } = context.repo;

  const { data: open } = await github.rest.pulls.list({
    owner,
    repo,
    state: "open",
    head: `${headRepo.owner.login}:${workflowRun.head_branch}`,
    base: context.payload.repository.default_branch,
  });
  const pr = open.find(
    ({ head }) =>
      head.sha === workflowRun.head_sha &&
      head.repo?.full_name === headRepo.full_name
  );
  if (!pr) {
    core.info("No open PR is at the analyzed commit; skipping.");
    return { type: "skipped" };
  }
  const report = readReport(artifactDir);

  const budget = JSON.parse(readFileSync(budgetPath, "utf8"));
  const { keys, body } = renderComment(report, budget, {
    runUrl: workflowRun.html_url,
  });

  const comments = await github.paginate(github.rest.issues.listComments, {
    owner,
    repo,
    issue_number: pr.number,
    per_page: 100,
  });
  const existing = comments
    .filter((comment) => comment.user?.login === BOT_LOGIN)
    .map((comment) => ({ ...comment, marker: parseMarker(comment.body) }))
    .filter((comment) => comment.marker)
    .at(-1);

  const action = decideAction({ keys, existing });
  if (action.type === "none") {
    core.info("No findings and no active comment.");
    return action;
  }

  const update = (comment, text) =>
    github.rest.issues.updateComment({
      owner,
      repo,
      comment_id: comment.id,
      body: text,
    });
  const stub = (text, state) => `${HEADING}\n\n${text}\n\n${marker(state, [])}`;
  const fullBody = body && `${body}\n\n${marker("active", keys)}`;

  if (action.type === "resolve") {
    const sha = workflowRun.head_sha.slice(0, 7);
    await update(
      action.comment,
      stub(`✅ Resolved as of ${sha}: nothing over the thresholds.`, "resolved")
    );
  } else if (action.type === "update") {
    await update(action.comment, fullBody);
  } else {
    const { data: created } = await github.rest.issues.createComment({
      owner,
      repo,
      issue_number: pr.number,
      body: fullBody,
    });
    if (action.type === "supersede") {
      await update(
        action.comment,
        stub(
          `Superseded by [a newer report](${created.html_url}).`,
          "superseded"
        )
      );
    }
  }
  core.info(`Comment action: ${action.type}`);
  return action;
}
