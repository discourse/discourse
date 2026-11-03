import { execFileSync, spawnSync } from "child_process";
import {
  cpSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  renameSync,
  rmSync,
} from "fs";
import { tmpdir } from "os";
import { dirname, join } from "path";
import { GRAPH_PATH } from "./graph.mjs";

/** Everything that can change the core JS build. */
export const JS_INPUTS = [
  "frontend",
  "package.json",
  "pnpm-lock.yaml",
  "pnpm-workspace.yaml",
  "patches",
  ".pnpmfile.cjs",
  ".npmrc",
];

// What script/assemble_ember_build.rb hashes into BUILD_INFO.json.
const TREE_HASH_PATHS = ["frontend", "package.json", "pnpm-lock.yaml"];
const RELEASES =
  "https://github.com/discourse/discourse-assets/releases/download";
const CANDIDATES = 50;

function git(args, { cwd, input } = {}) {
  return execFileSync("git", args, { cwd, input, encoding: "utf8" }).trim();
}

export function sameJsInputs(a, b, cwd) {
  const result = spawnSync(
    "git",
    ["diff", "--quiet", a, b, "--", ...JS_INPUTS],
    {
      cwd,
    }
  );
  // 1 means the inputs differ; anything else (e.g. 128 for a commit beyond a
  // shallow clone) means they cannot be compared.
  return result.status === 0;
}

export function treeHash(commit, cwd) {
  const listing = git(["ls-tree", commit, "--", ...TREE_HASH_PATHS], { cwd });
  return git(["mktree", "--missing"], { cwd, input: `${listing}\n` });
}

export function versionAt(commit, cwd) {
  const source = git(["show", `${commit}:lib/version.rb`], { cwd });
  const match = source.match(/STRING\s*=\s*"([^"]+)"/);
  if (!match) {
    throw new Error(`No version string in lib/version.rb at ${commit}`);
  }
  return match[1];
}

export function releaseUrl(version, commit) {
  return `${RELEASES}/v${version}-${commit.slice(0, 8)}/production.tar.gz`;
}

/**
 * Downloads a published build and extracts its `core/` directory to `outDir`
 * if it was built from `expectedTreeHash` and, unless `requireGraph` is
 * false, has a bundle graph. Builds published before the bundle-graph plugin
 * have none.
 */
export function tryDownload(
  url,
  outDir,
  expectedTreeHash,
  { log = () => {}, requireGraph = true } = {}
) {
  // Next to outDir, so the final rename stays on one filesystem: in CI the
  // system temp dir and the output dir are different mounts.
  mkdirSync(dirname(outDir), { recursive: true });
  const work = mkdtempSync(join(dirname(outDir), ".bundle-baseline-"));
  try {
    const tarball = join(work, "production.tar.gz");
    const curl = spawnSync(
      "curl",
      [
        "--fail",
        "--silent",
        "--show-error",
        "--location",
        "--output",
        tarball,
        url,
      ],
      {
        encoding: "utf8",
      }
    );
    if (curl.status !== 0) {
      log(`No published build at ${url}`);
      return false;
    }
    let info;
    try {
      execFileSync("tar", ["-xzf", tarball, "-C", work, "core"]);
      info = JSON.parse(
        readFileSync(join(work, "core/BUILD_INFO.json"), "utf8")
      );
    } catch (error) {
      log(`Published build at ${url} is unreadable: ${error.message}`);
      return false;
    }
    if (info.core_tree_hash !== expectedTreeHash) {
      log(`Published build at ${url} is from different JS inputs`);
      return false;
    }
    if (requireGraph && !existsSync(join(work, "core", GRAPH_PATH))) {
      log(`Published build at ${url} predates the bundle graph`);
      return false;
    }
    rmSync(outDir, { recursive: true, force: true });
    renameSync(join(work, "core"), outDir);
    return true;
  } finally {
    rmSync(work, { recursive: true, force: true });
  }
}

/** Builds `commit` in a temporary worktree and copies its dist to `outDir`. */
export function buildInWorktree(commit, outDir, { cwd, log = () => {} } = {}) {
  const worktree = mkdtempSync(join(tmpdir(), "bundle-baseline-worktree-"));
  log(`Building ${commit.slice(0, 8)} in ${worktree}`);
  git(["worktree", "add", "--detach", worktree, commit], { cwd });
  try {
    const run = (command, args, options) =>
      execFileSync(command, args, {
        stdio: ["ignore", process.stderr, process.stderr],
        ...options,
      });
    run("pnpm", ["install", "--frozen-lockfile"], { cwd: worktree });
    run("pnpm", ["build"], {
      cwd: join(worktree, "frontend/discourse"),
      env: { ...process.env, EMBER_ENV: "production", CI: "1" },
    });
    rmSync(outDir, { recursive: true, force: true });
    mkdirSync(outDir, { recursive: true });
    cpSync(join(worktree, "frontend/discourse/dist"), outDir, {
      recursive: true,
    });
  } finally {
    git(["worktree", "remove", "--force", worktree], { cwd });
  }
}

/**
 * Puts a production build of `commit` in `outDir`. The build is reproducible,
 * so a published build of any recent commit with identical JS inputs is
 * exact. Candidates come in topological order, not first-parent: a fork that
 * merges upstream has upstream's commits on the second parent.
 */
export function findBaseline(
  commit,
  outDir,
  { cwd, log = () => {}, build = buildInWorktree, urlFor = releaseUrl } = {}
) {
  const expected = treeHash(commit, cwd);
  const candidates = git(
    ["rev-list", "--topo-order", "-n", String(CANDIDATES), commit],
    {
      cwd,
    }
  ).split("\n");

  for (const candidate of candidates) {
    if (!sameJsInputs(candidate, commit, cwd)) {
      continue;
    }
    const url = urlFor(versionAt(candidate, cwd), candidate);
    if (tryDownload(url, outDir, expected, { log })) {
      log(`Using the published build of ${candidate.slice(0, 8)}`);
      return { source: "download", commit: candidate };
    }
  }

  log("No usable published build; building the base.");
  build(commit, outDir, { cwd, log });
  return { source: "build", commit };
}
