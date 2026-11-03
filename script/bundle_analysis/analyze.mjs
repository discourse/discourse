#!/usr/bin/env node
/* eslint-disable no-console */
import { mkdirSync, readFileSync, writeFileSync } from "fs";
import { join, resolve } from "path";
import { parseArgs } from "util";
import { analyze, REPORT_SCHEMA } from "./lib/analyze.mjs";
import { buildBaseline, git } from "./lib/baseline.mjs";
import { findReport } from "./lib/graph.mjs";
import { renderComment, renderSummary } from "./lib/render.mjs";

const USAGE = `Compares two production JS builds.

  node script/bundle_analysis/analyze.mjs --base <dist> --head <dist> [--out <dir>]
  node script/bundle_analysis/analyze.mjs --base-ref origin/main --head frontend/discourse/dist
  node script/bundle_analysis/analyze.mjs --no-js-changes --out <dir>

--base-ref builds the merge base of HEAD and the ref in a worktree, once per
commit.
Build the head first with: cd frontend/discourse && EMBER_ENV=production pnpm build

Writes report.json and summary.md to --out, or prints the summary and the
PR comment it would post.`;

const { values: args } = parseArgs({
  options: {
    base: { type: "string" },
    "base-ref": { type: "string" },
    head: { type: "string" },
    out: { type: "string" },
    budget: {
      type: "string",
      default: join(import.meta.dirname, "budget.json"),
    },
    "no-js-changes": { type: "boolean", default: false },
    help: { type: "boolean", default: false },
  },
});

if (
  args.help ||
  (!args["no-js-changes"] && (!args.head || !(args.base || args["base-ref"])))
) {
  console.log(USAGE);
  process.exit(args.help ? 0 : 1);
}

const budget = JSON.parse(readFileSync(args.budget, "utf8"));
let report;

if (args["no-js-changes"]) {
  report = { schema: REPORT_SCHEMA, noJsChanges: true };
} else {
  let baseDir = args.base && resolve(args.base);
  if (!baseDir) {
    const repo = git(["rev-parse", "--show-toplevel"]);
    const commit = git(["merge-base", "HEAD", args["base-ref"]], {
      cwd: repo,
    });
    baseDir = join(repo, "tmp/bundle-analysis", commit);
    if (findReport(baseDir)) {
      console.error(
        `Reusing the baseline for ${commit.slice(0, 8)} in ${baseDir}`
      );
    } else {
      buildBaseline(commit, baseDir, {
        cwd: repo,
        log: (m) => console.error(m),
      });
    }
  }
  report = analyze({ baseDir, headDir: resolve(args.head) });
}

const summary = renderSummary(report, budget);
if (args.out) {
  mkdirSync(args.out, { recursive: true });
  writeFileSync(join(args.out, "report.json"), JSON.stringify(report, null, 1));
  writeFileSync(join(args.out, "summary.md"), summary);
} else {
  console.log(summary);
  const { body } = renderComment(report, budget);
  console.log("---\n\nPR comment:\n");
  console.log(body ?? "(none: nothing over the thresholds)");
}
