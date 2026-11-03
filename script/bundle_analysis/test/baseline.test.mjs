import { execFileSync } from "child_process";
import { mkdirSync, mkdtempSync, writeFileSync } from "fs";
import assert from "node:assert/strict";
import { test } from "node:test";
import { tmpdir } from "os";
import { join } from "path";
import { jsInputsChanged } from "../lib/baseline.mjs";

function repo() {
  const dir = mkdtempSync(join(tmpdir(), "bundle-repo-"));
  const git = (...args) =>
    execFileSync("git", args, {
      cwd: dir,
      encoding: "utf8",
      env: {
        ...process.env,
        GIT_AUTHOR_NAME: "t",
        GIT_AUTHOR_EMAIL: "t@t",
        GIT_COMMITTER_NAME: "t",
        GIT_COMMITTER_EMAIL: "t@t",
      },
    }).trim();
  const commit = (files, message) => {
    for (const [path, content] of Object.entries(files)) {
      mkdirSync(join(dir, path, ".."), { recursive: true });
      writeFileSync(join(dir, path), content);
    }
    git("add", "-A");
    git("commit", "-q", "-m", message);
    return git("rev-parse", "HEAD");
  };
  git("init", "-q");
  const first = commit(
    {
      "frontend/discourse/app.js": "one",
      "package.json": "{}",
      "pnpm-lock.yaml": "",
    },
    "first"
  );
  const docs = commit({ "README.md": "docs" }, "docs only");
  const js = commit({ "frontend/discourse/app.js": "two" }, "js change");
  const patch = commit({ "patches/x.patch": "p" }, "patch");
  return { dir, first, docs, js, patch };
}

test("jsInputsChanged looks at every build input", () => {
  const { dir, first, docs, js, patch } = repo();

  assert.equal(jsInputsChanged(first, docs, dir), false);
  assert.equal(jsInputsChanged(docs, js, dir), true);
  assert.equal(jsInputsChanged(js, patch, dir), true);
  assert.equal(jsInputsChanged(first, "0".repeat(40), dir), true);
});
