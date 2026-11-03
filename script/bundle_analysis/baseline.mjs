#!/usr/bin/env node
/* eslint-disable no-console */
import { execFileSync } from "child_process";
import { resolve } from "path";
import { parseArgs } from "util";
import { findBaseline, sameJsInputs } from "./lib/baseline.mjs";

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

const revParse = (ref) =>
  execFileSync("git", ["rev-parse", ref], { encoding: "utf8" }).trim();

if (args["js-changed-since"]) {
  console.log(!sameJsInputs(revParse(args["js-changed-since"]), "HEAD"));
} else if (args.commit && args.out) {
  const result = findBaseline(revParse(args.commit), resolve(args.out), {
    log: (message) => console.error(message),
  });
  console.log(JSON.stringify(result));
} else {
  console.error(USAGE);
  process.exit(1);
}
