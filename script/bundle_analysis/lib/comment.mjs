import { createHash } from "crypto";
import { readdirSync, readFileSync, statSync } from "fs";
import { join } from "path";
import { renderComment } from "./render.mjs";
import { validateReport } from "./validate.mjs";

const MARKER =
  /<!-- bundle-analysis:v1 state=(active|resolved|superseded) keys=([0-9a-f,]*) -->/g;
const BOT_LOGIN = "github-actions[bot]";
const ARTIFACT_FILES = { "report.json": 20 * 1024 * 1024, "pr.json": 1024 };

export function hashKey(key) {
  return createHash("sha256").update(key).digest("hex").slice(0, 12);
}

export function marker(state, keys) {
  return `<!-- bundle-analysis:v1 state=${state} keys=${[...new Set(keys.map(hashKey))].sort().join(",")} -->`;
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
  const known = keys.every((key) => active.marker.keys.has(hashKey(key)));
  return known
    ? { type: "update", comment: active }
    : { type: "supersede", comment: active };
}

/** Reads the artifact from workflow A, accepting only the expected files. */
export function readArtifact(dir) {
  const files = readdirSync(dir);
  for (const file of files) {
    if (!(file in ARTIFACT_FILES)) {
      throw new Error(`Unexpected file in artifact: ${JSON.stringify(file)}`);
    }
  }
  const read = (file) => {
    const path = join(dir, file);
    if (
      !statSync(path).isFile() ||
      statSync(path).size > ARTIFACT_FILES[file]
    ) {
      throw new Error(`${file} is missing or too large`);
    }
    return JSON.parse(readFileSync(path, "utf8"));
  };
  return {
    pr: validatePr(read("pr.json")),
    report: validateReport(read("report.json")),
  };
}

function validatePr(pr) {
  if (
    !Number.isSafeInteger(pr?.number) ||
    pr.number <= 0 ||
    typeof pr.head_sha !== "string" ||
    !/^[0-9a-f]{40}$/.test(pr.head_sha) ||
    typeof pr.head_repo !== "string" ||
    !/^[\w.-]+\/[\w.-]+$/.test(pr.head_repo)
  ) {
    throw new Error("pr.json is invalid");
  }
  return { number: pr.number, headSha: pr.head_sha, headRepo: pr.head_repo };
}

/**
 * Entry point for the trusted comment workflow (actions/github-script). The
 * artifact comes from a run of untrusted PR code, so every field is checked
 * against the workflow_run event and the PR itself before anything is
 * written.
 */
export async function run({ github, context, core, artifactDir, budgetPath }) {
  const workflowRun = context.payload.workflow_run;
  const { pr, report } = readArtifact(artifactDir);
  const { owner, repo } = context.repo;

  if (
    pr.headSha !== workflowRun.head_sha ||
    pr.headRepo !== workflowRun.head_repository?.full_name
  ) {
    core.warning("Artifact does not match the workflow run; skipping.");
    return { type: "skipped" };
  }

  const currentHead = async () => {
    const { data } = await github.rest.pulls.get({
      owner,
      repo,
      pull_number: pr.number,
    });
    return data.state === "open" &&
      data.head.sha === workflowRun.head_sha &&
      data.head.repo?.full_name === workflowRun.head_repository.full_name
      ? data
      : null;
  };

  if (!(await currentHead())) {
    core.info("PR is closed or has newer commits; skipping.");
    return { type: "skipped" };
  }

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

  // A push while this ran would make the comment stale; its own run follows.
  if (!(await currentHead())) {
    core.info("PR changed while rendering; skipping.");
    return { type: "skipped" };
  }

  const shortSha = workflowRun.head_sha.slice(0, 7);
  const fullBody = body && `${body}\n\n${marker("active", keys)}`;

  if (action.type === "resolve") {
    await github.rest.issues.updateComment({
      owner,
      repo,
      comment_id: action.comment.id,
      body: `### 📦 JS bundle changes\n\n✅ Resolved as of ${shortSha}: nothing over the thresholds.\n\n${marker("resolved", [])}`,
    });
  } else if (action.type === "update") {
    await github.rest.issues.updateComment({
      owner,
      repo,
      comment_id: action.comment.id,
      body: fullBody,
    });
  } else {
    const { data: created } = await github.rest.issues.createComment({
      owner,
      repo,
      issue_number: pr.number,
      body: fullBody,
    });
    if (action.type === "supersede") {
      await github.rest.issues.updateComment({
        owner,
        repo,
        comment_id: action.comment.id,
        body: `### 📦 JS bundle changes\n\nSuperseded by [a newer report](${created.html_url}).\n\n${marker("superseded", [])}`,
      });
    }
  }
  core.info(`Comment action: ${action.type}`);
  return action;
}
