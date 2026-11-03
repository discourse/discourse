import { mkdtempSync, writeFileSync } from "fs";
import assert from "node:assert/strict";
import { test } from "node:test";
import { tmpdir } from "os";
import { join } from "path";
import {
  decideAction,
  hashKey,
  marker,
  parseMarker,
  readArtifact,
  run,
} from "../lib/comment.mjs";

const BUDGET_PATH = new URL("../budget.json", import.meta.url).pathname;
const SHA = "a".repeat(40);

test("markers round-trip their state and hashed keys", () => {
  const parsed = parseMarker(`text\n${marker("active", ["b", "a", "a"])}`);

  assert.equal(parsed.state, "active");
  assert.deepEqual(
    [...parsed.keys].sort(),
    [hashKey("a"), hashKey("b")].sort()
  );
  assert.equal(parseMarker("no marker"), null);

  const forged = `| \`${marker("resolved", [])}\` |\n\n${marker("active", ["a"])}`;
  assert.equal(parseMarker(forged).state, "active");
});

test("decideAction", () => {
  const comment = (state, keys) => ({
    id: 1,
    marker: parseMarker(marker(state, keys)),
  });

  assert.equal(decideAction({ keys: [], existing: undefined }).type, "none");
  assert.equal(
    decideAction({ keys: [], existing: comment("resolved", []) }).type,
    "none"
  );
  assert.equal(
    decideAction({ keys: [], existing: comment("active", ["a"]) }).type,
    "resolve"
  );
  assert.equal(
    decideAction({ keys: ["a"], existing: undefined }).type,
    "create"
  );
  assert.equal(
    decideAction({ keys: ["a"], existing: comment("resolved", []) }).type,
    "create"
  );
  assert.equal(
    decideAction({ keys: ["a"], existing: comment("active", ["a", "b"]) }).type,
    "update"
  );
  assert.equal(
    decideAction({ keys: ["a", "c"], existing: comment("active", ["a"]) }).type,
    "supersede"
  );
});

const FINDINGS_REPORT = {
  schema: 2,
  noJsChanges: false,
  initialLoad: {
    base: 1_000_000,
    head: 1_050_000,
    entryOwn: { base: 600_000, head: 650_000 },
    chunks: { base: 20, head: 20 },
    topModules: [{ id: "app/lib/big.js", delta: 50_000, added: true }],
  },
  totals: { base: 3_000_000, head: 3_050_000, chunks: { base: 50, head: 50 } },
  bundles: [],
  movedIntoInitialLoad: [],
  edges: { added: [], removed: [] },
  assets: [],
  duplicatePackages: [],
};

function artifact(report, pr = {}) {
  const dir = mkdtempSync(join(tmpdir(), "bundle-artifact-"));
  writeFileSync(join(dir, "report.json"), JSON.stringify(report));
  writeFileSync(
    join(dir, "pr.json"),
    JSON.stringify({
      number: 7,
      head_sha: SHA,
      head_repo: "fork/discourse",
      ...pr,
    })
  );
  return dir;
}

function fakeGitHub({ comments = [], pull = {} } = {}) {
  const calls = [];
  let nextId = 100;
  const github = {
    calls,
    comments,
    paginate: async (_method, params) => {
      calls.push(["list", params.issue_number]);
      return comments;
    },
    rest: {
      pulls: {
        get: async () => ({
          data: {
            state: "open",
            head: { sha: SHA, repo: { full_name: "fork/discourse" } },
            ...pull,
          },
        }),
      },
      issues: {
        listComments: () => {},
        createComment: async ({ body }) => {
          const comment = {
            id: nextId++,
            body,
            user: { login: "github-actions[bot]" },
            html_url: "https://example.test/c",
          };
          comments.push(comment);
          calls.push(["create", comment.id]);
          return { data: comment };
        },
        updateComment: async ({ comment_id, body }) => {
          comments.find((c) => c.id === comment_id).body = body;
          calls.push(["update", comment_id]);
          return { data: {} };
        },
      },
    },
  };
  return github;
}

const context = {
  repo: { owner: "cvx", repo: "discourse" },
  payload: {
    workflow_run: {
      head_sha: SHA,
      head_repository: { full_name: "fork/discourse" },
      html_url: "https://github.com/cvx/discourse/actions/runs/1",
    },
  },
};
const core = { info() {}, warning() {} };

test("run creates, updates and resolves one comment", async () => {
  const github = fakeGitHub();
  const go = (report) =>
    run({
      github,
      context,
      core,
      artifactDir: artifact(report),
      budgetPath: BUDGET_PATH,
    });

  assert.equal((await go(FINDINGS_REPORT)).type, "create");
  assert.match(github.comments[0].body, /Grew over the threshold/);
  assert.match(github.comments[0].body, /state=active/);

  assert.equal((await go(FINDINGS_REPORT)).type, "update");
  assert.equal(github.comments.length, 1);

  assert.equal((await go({ schema: 2, noJsChanges: true })).type, "resolve");
  assert.match(github.comments[0].body, /Resolved as of aaaaaaa/);

  assert.equal((await go({ schema: 2, noJsChanges: true })).type, "none");
});

test("run ignores comments from other users", async () => {
  const github = fakeGitHub({
    comments: [
      {
        id: 1,
        body: marker("active", ["initial"]),
        user: { login: "someone" },
      },
    ],
  });

  const action = await run({
    github,
    context,
    core,
    artifactDir: artifact(FINDINGS_REPORT),
    budgetPath: BUDGET_PATH,
  });

  assert.equal(action.type, "create");
});

test("run skips an artifact that does not match the workflow run", async () => {
  const github = fakeGitHub();
  const action = await run({
    github,
    context,
    core,
    artifactDir: artifact(FINDINGS_REPORT, { head_sha: "b".repeat(40) }),
    budgetPath: BUDGET_PATH,
  });

  assert.equal(action.type, "skipped");
  assert.deepEqual(github.calls, []);
});

test("run skips a PR that moved on", async () => {
  const github = fakeGitHub({
    pull: {
      head: { sha: "c".repeat(40), repo: { full_name: "fork/discourse" } },
    },
  });
  const action = await run({
    github,
    context,
    core,
    artifactDir: artifact(FINDINGS_REPORT),
    budgetPath: BUDGET_PATH,
  });

  assert.equal(action.type, "skipped");
});

test("readArtifact rejects unexpected files and invalid PR data", () => {
  const extra = artifact(FINDINGS_REPORT);
  writeFileSync(join(extra, "render-comment.mjs"), "evil");
  assert.throws(() => readArtifact(extra), /Unexpected file/);

  assert.throws(
    () => readArtifact(artifact(FINDINGS_REPORT, { number: "7" })),
    /pr.json is invalid/
  );
  assert.throws(
    () =>
      readArtifact(artifact(FINDINGS_REPORT, { head_repo: "a/b; rm -rf /" })),
    /pr.json is invalid/
  );
});
