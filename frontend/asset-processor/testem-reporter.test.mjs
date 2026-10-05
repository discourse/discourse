/* eslint-disable qunit/require-expect */
import { createRequire } from "node:module";
import { afterEach, expect, test, vi } from "vitest";

const require = createRequire(import.meta.url);

afterEach(() => vi.unstubAllGlobals());

test("count-only updates preserve deprecation details and the highest count", () => {
  vi.stubGlobal("fetch", vi.fn().mockResolvedValue({}));
  const { reporter: Reporter } = require("../discourse/testem.js");
  const reporter = new Reporter(true, { write() {} }, { get() {} });
  const detail = {
    key: "browser-deprecation",
    id: "reported.deprecation",
    origin: "core",
    stack: "source stack",
    module: "Unit | Lib | example",
    testName: "example test",
    testStack: "test stack",
    count: 1,
  };

  reporter.reportMetadata("deprecation-details", { details: [{ ...detail }] });
  reporter.reportMetadata("deprecation-details", {
    details: [{ key: detail.key, count: 3 }],
  });
  reporter.reportMetadata("deprecation-details", {
    details: [{ key: detail.key, count: 2 }],
  });

  expect([...reporter.deprecationDetails.values()]).toEqual([
    { ...detail, count: 3 },
  ]);
});
