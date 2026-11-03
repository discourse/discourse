import { execFileSync, spawnSync } from "child_process";
import { mkdirSync, mkdtempSync, renameSync, rmSync } from "fs";
import { dirname, join } from "path";

/** Everything that can change the core JS build. */
const JS_INPUTS = [
  "frontend",
  "package.json",
  "pnpm-lock.yaml",
  "pnpm-workspace.yaml",
  "patches",
  ".pnpmfile.cjs",
  ".npmrc",
];

export function git(args, { cwd } = {}) {
  return execFileSync("git", args, { cwd, encoding: "utf8" }).trim();
}

export function jsInputsChanged(a, b, cwd) {
  // 1 means the inputs differ; anything else (e.g. 128 for a commit beyond a
  // shallow clone) means they cannot be compared, so count as changed.
  const args = ["diff", "--quiet", a, b, "--", ...JS_INPUTS];
  return spawnSync("git", args, { cwd }).status !== 0;
}

// CI builds both sides like this; `CI` is a build-time flag in the code too.
const BUILD_ENV = { EMBER_ENV: "production", CI: "1" };

function run(command, args, options) {
  execFileSync(command, args, {
    stdio: ["ignore", process.stderr, process.stderr],
    ...options,
  });
}

/** Builds the core JS of the checkout at `root` as CI does; returns its dist. */
export function buildCore(root) {
  const app = join(root, "frontend/discourse");
  run("pnpm", ["build"], { cwd: app, env: { ...process.env, ...BUILD_ENV } });
  return join(app, "dist");
}

/** Builds `commit` in a temporary worktree and moves its dist to `outDir`. */
export function buildBaseline(commit, outDir) {
  // Next to outDir, so the final rename stays on one filesystem: in CI the
  // system temp dir and the output dir are different mounts.
  mkdirSync(dirname(outDir), { recursive: true });
  const worktree = mkdtempSync(
    join(dirname(outDir), ".bundle-baseline-worktree-")
  );
  // eslint-disable-next-line no-console
  console.error(`Building ${commit.slice(0, 8)} in ${worktree}`);
  git(["worktree", "add", "--detach", worktree, commit]);
  try {
    // Install scripts generate types and vendored assets the build does not use.
    run("pnpm", ["install", "--frozen-lockfile", "--ignore-scripts"], {
      cwd: worktree,
    });
    const dist = buildCore(worktree);
    rmSync(outDir, { recursive: true, force: true });
    renameSync(dist, outDir);
  } finally {
    git(["worktree", "remove", "--force", worktree]);
  }
}
