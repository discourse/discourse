#!/usr/bin/env node
/* eslint-disable no-console */
import { resolve } from "path";
import { parseArgs } from "util";
import { buildBaseline, git, jsInputsChanged } from "./lib/baseline.mjs";

const USAGE = `Usage:
  node script/bundle_analysis/baseline.mjs --commit <sha> --out <dir>
  node script/bundle_analysis/baseline.mjs --js-changed-since <sha>   (prints true or false)`;

const { values: args } = parseArgs({
  options: {
    commit: { type: "string" },
    out: { type: "string" },
    "js-changed-since": { type: "string" },
  },
});

if (args["js-changed-since"]) {
  console.log(jsInputsChanged(args["js-changed-since"], "HEAD"));
} else if (args.commit && args.out) {
  buildBaseline(git(["rev-parse", args.commit]), resolve(args.out));
} else {
  console.error(USAGE);
  process.exit(1);
}
