import { mkdtempSync, writeFileSync } from "fs";
import assert from "node:assert/strict";
import { test } from "node:test";
import { tmpdir } from "os";
import { join } from "path";
import { fileURLToPath } from "url";
import { REPORT_SCHEMA } from "../lib/analyze.mjs";
import {
  decideAction,
  hashKey,
  marker,
  parseMarker,
  readReport,
  run,
} from "../lib/comment.mjs";
import { emptyReport, NO_JS_REPORT } from "./helpers.mjs";

const BUDGET_PATH = fileURLToPath(new URL("../budget.json", import.meta.url));
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
  const many = Array.from({ length: 400 }, (_, i) => `k${i}`);
  const comment = (state, keys) => ({
    id: 1,
    marker: parseMarker(marker(state, keys)),
  });

  for (const [keys, existing, type] of [
    [["a"], comment("resolved", []), "create"],
    [["a"], comment("active", ["a", "b"]), "update"],
    [["a", "c"], comment("active", ["a"]), "supersede"],
    // Over the marker's cap, the same findings still match.
    [many, comment("active", many), "update"],
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

function artifact(report) {
  const dir = mkdtempSync(join(tmpdir(), "bundle-artifact-"));
  if (report) {
    writeFileSync(join(dir, "report.json"), JSON.stringify(report));
  }
  return dir;
}

const PR = {
  number: 7,
  state: "open",
  head: { sha: SHA, repo: { full_name: "fork/discourse" } },
};

function fakeGitHub({ comments = [], listed = [PR] } = {}) {
  const calls = [];
  let nextId = 100;
  const github = {
    calls,
    comments,
    paginate: async (_method, params) => {
      calls.push(["comments", params.issue_number]);
      return comments;
    },
    rest: {
      pulls: {
        list: async ({ head, base }) => {
          calls.push(["pulls", `${head} → ${base}`]);
          return { data: listed };
        },
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
          return { data: comment };
        },
        updateComment: async ({ comment_id, body }) => {
          comments.find((c) => c.id === comment_id).body = body;
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
    repository: { default_branch: "main" },
    workflow_run: {
      head_sha: SHA,
      head_branch: "feature",
      head_repository: {
        full_name: "fork/discourse",
        owner: { login: "fork" },
      },
      html_url: "https://github.com/cvx/discourse/actions/runs/1",
    },
  },
};
const core = { info() {} };

function go(github, report) {
  return run({
    github,
    context,
    core,
    artifactDir: artifact(report),
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
  assert.deepEqual(github.calls[0], ["pulls", "fork:feature → main"]);
  assert.match(github.comments[1].body, /Grew over the threshold/);
  assert.equal((await go(github, FINDINGS_REPORT)).type, "update");
  assert.equal((await go(github, NO_JS_REPORT)).type, "resolve");
  assert.match(github.comments[1].body, /Resolved as of aaaaaaa/);
  assert.equal((await go(github, NO_JS_REPORT)).type, "none");
  assert.equal(github.comments.length, 2);
});

test("run skips unless an open PR is at the analyzed commit", async () => {
  const elsewhere = { ...PR, head: { ...PR.head, sha: "b".repeat(40) } };
  const github = fakeGitHub({ listed: [elsewhere] });

  assert.equal((await go(github, FINDINGS_REPORT)).type, "skipped");
  assert.deepEqual(github.calls, [["pulls", "fork:feature → main"]]);
});

test("readReport rejects a missing report or another schema", () => {
  assert.throws(() => readReport(artifact(null)), /missing/);
  assert.throws(
    () => readReport(artifact({ ...NO_JS_REPORT, schema: REPORT_SCHEMA + 1 })),
    /schema/
  );
});
