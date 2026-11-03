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

/** Builds `commit` in a temporary worktree and moves its dist to `outDir`. */
export function buildBaseline(commit, outDir, { cwd, log = () => {} } = {}) {
  // Next to outDir, so the final rename stays on one filesystem: in CI the
  // system temp dir and the output dir are different mounts.
  mkdirSync(dirname(outDir), { recursive: true });
  const worktree = mkdtempSync(
    join(dirname(outDir), ".bundle-baseline-worktree-")
  );
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
    renameSync(join(worktree, "frontend/discourse/dist"), outDir);
  } finally {
    git(["worktree", "remove", "--force", worktree], { cwd });
  }
}
