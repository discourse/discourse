#!/usr/bin/env node
"use strict";

// Builds a deprecation report from entries supplied on stdin, so the Ruby
// system-spec formatter can reuse the same sourcemap resolution as the testem
// reporter.
//
// Usage: node deprecation-report-cli.js <group> <output-file> < entries.json

const fs = require("fs");
const { buildReport } = require("./deprecation-report");

const [group, outputFile] = process.argv.slice(2);

if (!group || !outputFile) {
  process.stderr.write(
    "Usage: deprecation-report-cli.js <group> <output-file> < entries.json\n"
  );
  process.exit(1);
}

const entries = JSON.parse(fs.readFileSync(0, "utf8"));
fs.writeFileSync(
  outputFile,
  JSON.stringify(buildReport({ group, entries }), null, 2)
);
