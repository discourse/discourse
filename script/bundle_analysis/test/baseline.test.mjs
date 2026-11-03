import { execFileSync } from "child_process";
import { existsSync, mkdirSync, mkdtempSync, writeFileSync } from "fs";
import assert from "node:assert/strict";
import { test } from "node:test";
import { tmpdir } from "os";
import { join } from "path";
import {
  findBaseline,
  sameJsInputs,
  treeHash,
  tryDownload,
  versionAt,
} from "../lib/baseline.mjs";

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
      "lib/version.rb": 'STRING = "2026.10.0-latest"',
    },
    "first"
  );
  const docs = commit({ "README.md": "docs" }, "docs only");
  const js = commit({ "frontend/discourse/app.js": "two" }, "js change");
  const patch = commit({ "patches/x.patch": "p" }, "patch");
  return { dir, git, first, docs, js, patch };
}

function tarball({ treeHash: hash, graph = true }) {
  const dir = mkdtempSync(join(tmpdir(), "bundle-tarball-"));
  mkdirSync(join(dir, "core/manifest"), { recursive: true });
  writeFileSync(
    join(dir, "core/BUILD_INFO.json"),
    JSON.stringify({ core_tree_hash: hash })
  );
  if (graph) {
    writeFileSync(join(dir, "core/manifest/bundle-graph.json"), "{}");
  }
  execFileSync("tar", [
    "-czf",
    join(dir, "production.tar.gz"),
    "-C",
    dir,
    "core",
  ]);
  return `file://${join(dir, "production.tar.gz")}`;
}

test("sameJsInputs looks at every build input", () => {
  const { dir, first, docs, js, patch } = repo();

  assert.equal(sameJsInputs(first, docs, dir), true);
  assert.equal(sameJsInputs(docs, js, dir), false);
  assert.equal(sameJsInputs(js, patch, dir), false);
  assert.equal(sameJsInputs(first, "0".repeat(40), dir), false);
});

test("treeHash matches the hash assemble_ember_build.rb records", () => {
  const { dir, git, first, docs, js } = repo();
  const expected = execFileSync("git", ["mktree", "--missing"], {
    cwd: dir,
    input: `${git("ls-tree", first, "--", "frontend", "package.json", "pnpm-lock.yaml")}\n`,
    encoding: "utf8",
  }).trim();

  assert.equal(treeHash(first, dir), expected);
  assert.equal(treeHash(docs, dir), expected);
  assert.notEqual(treeHash(js, dir), expected);
});

test("versionAt reads lib/version.rb", () => {
  const { dir, first } = repo();
  assert.equal(versionAt(first, dir), "2026.10.0-latest");
});

test("tryDownload checks the tree hash and the bundle graph", () => {
  const { dir, first } = repo();
  const hash = treeHash(first, dir);
  const out = () => join(mkdtempSync(join(tmpdir(), "bundle-out-")), "base");

  const good = out();
  assert.equal(tryDownload(tarball({ treeHash: hash }), good, hash), true);
  assert.ok(existsSync(join(good, "manifest/bundle-graph.json")));

  assert.equal(tryDownload(tarball({ treeHash: "other" }), out(), hash), false);
  assert.equal(
    tryDownload(tarball({ treeHash: hash, graph: false }), out(), hash),
    false
  );
  assert.equal(
    tryDownload(tarball({ treeHash: hash, graph: false }), out(), hash, {
      requireGraph: false,
    }),
    true
  );
  assert.equal(
    tryDownload("file:///does/not/exist.tar.gz", out(), hash),
    false
  );

  const junk = join(mkdtempSync(join(tmpdir(), "bundle-junk-")), "junk.tar.gz");
  writeFileSync(junk, "not a tarball");
  assert.equal(tryDownload(`file://${junk}`, out(), hash), false);
});

test("findBaseline uses any recent commit with the same JS inputs, else builds", () => {
  const { dir, first, docs, js } = repo();
  const published = new Map([
    [first, tarball({ treeHash: treeHash(first, dir) })],
  ]);
  const urlFor = (_version, commit) =>
    published.get(commit) ?? "file:///missing";
  const built = [];
  const build = (commit) => built.push(commit);
  const out = join(mkdtempSync(join(tmpdir(), "bundle-out-")), "base");

  assert.deepEqual(findBaseline(docs, out, { cwd: dir, urlFor, build }), {
    source: "download",
    commit: first,
  });
  assert.deepEqual(findBaseline(js, out, { cwd: dir, urlFor, build }), {
    source: "build",
    commit: js,
  });
  assert.deepEqual(built, [js]);
});
