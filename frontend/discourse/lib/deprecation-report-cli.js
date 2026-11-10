#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const {
  mergeReports,
  renderReportSummary,
} = require("./deprecation-report-format");

const REPO_ROOT = path.resolve(__dirname, "..", "..", "..");
const [command, outputFile, ...args] = process.argv.slice(2);

function writeReport(report) {
  fs.mkdirSync(path.dirname(outputFile), { recursive: true });
  fs.writeFileSync(outputFile, `${JSON.stringify(report, null, 2)}\n`);

  const relativePath = path.relative(REPO_ROOT, outputFile);
  process.stdout.write(
    `${renderReportSummary(report, { reportLocation: `\`${relativePath}\`` })}\n`
  );

  if (process.env.GITHUB_ACTIONS && process.env.GITHUB_STEP_SUMMARY) {
    fs.appendFileSync(
      process.env.GITHUB_STEP_SUMMARY,
      `${renderReportSummary(report, {
        reportLocation: "the `js-deprecation-report` artifact",
      })}\n`
    );
  }
}

if (command === "build") {
  const { buildReport } = require("./deprecation-report");
  const payload = JSON.parse(fs.readFileSync(0, "utf8"));
  writeReport(buildReport({ ...payload, group: args[0] }));
} else if (command === "merge" && args.length > 0) {
  const reports = args.map((file) => JSON.parse(fs.readFileSync(file, "utf8")));
  writeReport(mergeReports(reports));
} else {
  process.stderr.write(
    "Usage:\n" +
      "  deprecation-report-cli.js build <output-file> <group> < entries.json\n" +
      "  deprecation-report-cli.js merge <output-file> <report.json...>\n"
  );
  process.exitCode = 1;
}
