/* eslint-disable qunit/require-expect */
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { SourceMapGenerator } from "source-map-js";
import { afterEach, expect, test } from "vitest";
import deprecationReport from "../discourse/lib/deprecation-report.js";

const {
  DeprecationStackResolver,
  buildReport,
  mergeReports,
  parseStack,
  renderReportSummary,
} = deprecationReport;

let temporaryDirectory;

afterEach(() => {
  if (temporaryDirectory) {
    fs.rmSync(temporaryDirectory, { recursive: true, force: true });
    temporaryDirectory = null;
  }
});

function addSource(generator, generatedLine, source, originalLine, code) {
  generator.addMapping({
    generated: { line: generatedLine, column: 0 },
    original: { line: originalLine, column: 0 },
    source,
  });
  generator.setSourceContent(
    source,
    `${"\n".repeat(originalLine - 1)}${code}\n`
  );
}

test("builds an actionable compact report from browser stacks", () => {
  temporaryDirectory = fs.mkdtempSync(
    path.join(os.tmpdir(), "discourse-deprecation-report-")
  );
  const sourceMap = new SourceMapGenerator({ file: "bundle.js" });
  addSource(
    sourceMap,
    1,
    "frontend/discourse/app/lib/deprecated.js",
    10,
    "deprecated(message, options);"
  );
  addSource(
    sourceMap,
    2,
    "frontend/discourse/app/models/user.js",
    427,
    "get groups() {}"
  );
  addSource(
    sourceMap,
    3,
    "discourse/plugins/poll/discourse/components/poll.gjs",
    71,
    "return user.groups;"
  );
  addSource(
    sourceMap,
    4,
    "discourse/plugins/poll/component/poll-test.gjs",
    12,
    'test("shows a poll");'
  );
  fs.writeFileSync(
    path.join(temporaryDirectory, "bundle.js.map"),
    sourceMap.toString()
  );

  const report = buildReport({
    group: "frontend-plugins",
    entries: [
      {
        id: "discourse.user.groups",
        origin: "poll",
        count: 2,
        stack: [
          "Error",
          "    at deprecated (http://localhost/bundle.js:1:1)",
          "    at get groups (http://localhost/bundle.js:2:1)",
          "    at Poll.groups (http://localhost/bundle.js:3:1)",
        ].join("\n"),
        testStack: "    at test (http://localhost/bundle.js:4:1)",
      },
    ],
    totals: { "discourse.user.groups": 3 },
    totalsByOrigin: { poll: { "discourse.user.groups": 3 } },
    resolver: new DeprecationStackResolver({
      mapRoots: [temporaryDirectory],
    }),
  });

  expect(report).toEqual({
    format: 1,
    files: [
      {
        file: "plugins/poll/assets/javascripts/discourse/components/poll.gjs",
        deprecations: [
          {
            id: "discourse.user.groups",
            line: 71,
            code: "return user.groups;",
            count: 2,
            origins: { poll: 2 },
            groups: ["frontend-plugins"],
            specCount: 1,
            specs: ["plugins/poll/test/javascripts/component/poll-test.gjs:12"],
          },
        ],
      },
    ],
    unresolved: [
      {
        id: "discourse.user.groups",
        count: 1,
        origins: { poll: 1 },
        groups: ["frontend-plugins"],
        specCount: 0,
        specs: [],
      },
    ],
  });
  expect(JSON.stringify(report)).not.toContain("stack");
});

test("merges compact reports and renders the shared summary", () => {
  const first = {
    format: 1,
    files: [
      {
        file: "frontend/discourse/app/models/user.js",
        deprecations: [
          {
            id: "discourse.user.groups",
            line: 10,
            code: "user.groups;",
            count: 2,
            origins: { core: 2 },
            groups: ["frontend-core"],
            specCount: 1,
            specs: ["frontend/discourse/tests/unit/user-test.js:20"],
          },
        ],
      },
    ],
    unresolved: [],
  };
  const second = {
    format: 1,
    files: [
      {
        file: "frontend/discourse/app/models/user.js",
        deprecations: [
          {
            id: "discourse.user.groups",
            line: 10,
            code: "user.groups;",
            count: 1,
            origins: { chat: 1 },
            groups: ["system-chat"],
            specCount: 1,
            specs: ["plugins/chat/spec/system/user_spec.rb:8"],
          },
        ],
      },
    ],
    unresolved: [],
  };

  const merged = mergeReports([first, second]);
  const deprecation = merged.files[0].deprecations[0];
  expect(deprecation.count).toBe(3);
  expect(deprecation.origins).toEqual({ chat: 1, core: 2 });
  expect(deprecation.groups).toEqual(["frontend-core", "system-chat"]);
  expect(deprecation.specCount).toBe(2);

  const summary = renderReportSummary(merged);
  expect(summary).toContain("| discourse.user.groups | 3 |");
  expect(summary).toContain(
    "| discourse.user.groups | frontend/discourse/app/models/user.js:10 | 3 | 2 |"
  );
});

test("parses Chrome and Firefox stack frames", () => {
  expect(
    parseStack(
      "    at run (http://localhost/assets/app.js:10:2)\nnext@http://localhost/assets/app.js:20:3"
    )
  ).toEqual([
    {
      fn: "run",
      url: "http://localhost/assets/app.js",
      line: 10,
      column: 2,
    },
    {
      fn: "next",
      url: "http://localhost/assets/app.js",
      line: 20,
      column: 3,
    },
  ]);
});
