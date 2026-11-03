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
import { emptyReport, NO_JS_REPORT } from "./helpers.mjs";

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

test("decideAction notifies only for findings the comment lacks", () => {
  const comment = (state, keys) => ({
    id: 1,
    marker: parseMarker(marker(state, keys)),
  });

  for (const [keys, existing, type] of [
    [["a"], comment("resolved", []), "create"],
    [["a"], comment("active", ["a", "b"]), "update"],
    [["a", "c"], comment("active", ["a"]), "supersede"],
  ]) {
    assert.equal(decideAction({ keys, existing }).type, type);
  }
});

const FINDINGS_REPORT = emptyReport({
  initialLoad: {
    ...emptyReport().initialLoad,
    head: 1_050_000,
    entryOwn: { base: 600_000, head: 650_000 },
    topModules: [{ id: "app/lib/big.js", delta: 50_000, added: true }],
  },
  totals: { base: 3_000_000, head: 3_050_000, chunks: { base: 50, head: 50 } },
});

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

function go(github, report, pr) {
  return run({
    github,
    context,
    core,
    artifactDir: artifact(report, pr),
    budgetPath: BUDGET_PATH,
  });
}

test("run creates, updates and resolves its own comment", async () => {
  const github = fakeGitHub({
    comments: [
      {
        id: 1,
        body: marker("active", ["initial"]),
        user: { login: "someone" },
      },
    ],
  });

  assert.equal((await go(github, FINDINGS_REPORT)).type, "create");
  assert.match(github.comments[1].body, /Grew over the threshold/);
  assert.equal((await go(github, FINDINGS_REPORT)).type, "update");
  assert.equal((await go(github, NO_JS_REPORT)).type, "resolve");
  assert.match(github.comments[1].body, /Resolved as of aaaaaaa/);
  assert.equal((await go(github, NO_JS_REPORT)).type, "none");
  assert.equal(github.comments.length, 2);
});

test("run skips an artifact for another commit or a PR that moved on", async () => {
  const github = fakeGitHub();
  const moved = fakeGitHub({
    pull: {
      head: { sha: "c".repeat(40), repo: { full_name: "fork/discourse" } },
    },
  });

  const stale = await go(github, FINDINGS_REPORT, { head_sha: "b".repeat(40) });
  assert.equal(stale.type, "skipped");
  assert.deepEqual(github.calls, []);
  assert.equal((await go(moved, FINDINGS_REPORT)).type, "skipped");
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
