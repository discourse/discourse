#!/usr/bin/env node
/* eslint-disable no-console */
// Baselines are published builds, which is only sound while the build is
// reproducible. Rebuilds the newest ancestor of HEAD that has a published
// build and fails if any JS, wasm or manifest file differs.
import { execFileSync } from "child_process";
import { mkdtempSync, readdirSync, readFileSync, rmSync, statSync } from "fs";
import { tmpdir } from "os";
import { join, relative } from "path";
import {
  buildInWorktree,
  releaseUrl,
  treeHash,
  tryDownload,
  versionAt,
} from "./lib/baseline.mjs";

const cwd = execFileSync("git", ["rev-parse", "--show-toplevel"], {
  encoding: "utf8",
}).trim();
const candidates = execFileSync(
  "git",
  ["rev-list", "--topo-order", "-n", "50", "HEAD"],
  {
    cwd,
    encoding: "utf8",
  }
)
  .trim()
  .split("\n");

const work = mkdtempSync(join(tmpdir(), "bundle-reproducibility-"));
try {
  const published = join(work, "published");
  const commit = candidates.find((candidate) =>
    tryDownload(
      releaseUrl(versionAt(candidate, cwd), candidate),
      published,
      treeHash(candidate, cwd),
      { requireGraph: false }
    )
  );
  if (!commit) {
    console.log(
      "No published build among the last 50 commits; nothing to check."
    );
    process.exit(0);
  }

  const built = join(work, "built");
  buildInWorktree(commit, built, { cwd, log: (m) => console.error(m) });

  const differences = [];
  for (const file of listFiles(published)) {
    const path = relative(published, file);
    if (!/\.(js|wasm|json)$/.test(path) || path === "BUILD_INFO.json") {
      continue;
    }
    let rebuilt;
    try {
      rebuilt = readFileSync(join(built, path));
    } catch {
      differences.push(`${path}: missing from the rebuild`);
      continue;
    }
    if (!rebuilt.equals(readFileSync(file))) {
      differences.push(`${path}: differs`);
    }
  }

  if (differences.length) {
    console.error(
      `Rebuilding ${commit.slice(0, 8)} does not reproduce its published build:`
    );
    console.error(differences.slice(0, 50).join("\n"));
    process.exit(1);
  }
  console.log(
    `Rebuilding ${commit.slice(0, 8)} reproduces its published build.`
  );
} finally {
  rmSync(work, { recursive: true, force: true });
}

function listFiles(dir) {
  return readdirSync(dir).flatMap((name) => {
    const path = join(dir, name);
    return statSync(path).isDirectory() ? listFiles(path) : [path];
  });
}
