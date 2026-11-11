import { mkdirSync, mkdtempSync, writeFileSync } from "fs";
import assert from "node:assert/strict";
import { test } from "node:test";
import { tmpdir } from "os";
import { join } from "path";
import { git as gitIn, jsInputsChanged } from "../lib/baseline.mjs";

function repo() {
  const dir = mkdtempSync(join(tmpdir(), "bundle-repo-"));
  const git = (...args) =>
    gitIn(["-c", "user.name=t", "-c", "user.email=t@t", ...args], { cwd: dir });
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
  const first = commit({ "frontend/discourse/app.js": "one" }, "first");
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
