import assert from "node:assert/strict";
import { test } from "node:test";
import { REPORT_SCHEMA } from "../lib/analyze.mjs";
import { validateReport } from "../lib/validate.mjs";
import { analyzedReport, baseApp, NO_JS_REPORT } from "./helpers.mjs";

test("accepts what the analyzer writes", () => {
  const roundTripped = analyzedReport();

  assert.deepEqual(
    JSON.parse(JSON.stringify(validateReport(roundTripped))),
    roundTripped
  );
});

test("accepts reports with new and removed bundles", () => {
  const head = baseApp();
  delete head.chunks["assets/js/codemirror-dddd4444.digested.js"];
  head.chunks["assets/js/admin-cccc3333.digested.js"].dynamicImports = [
    "assets/js/rrule-eeee5555.digested.js",
  ];
  head.chunks["assets/js/rrule-eeee5555.digested.js"] = {
    kind: "lazy",
    facade: "rrule@2.8.1/dist/esm/index.js",
    modules: { "rrule@2.8.1/dist/esm/index.js": 8000 },
  };
  const report = analyzedReport(baseApp(), head);

  const statuses = report.bundles.map((bundle) => bundle.status).sort();
  assert.deepEqual(statuses, ["new", "removed", "same", "same"]);
  assert.deepEqual(JSON.parse(JSON.stringify(validateReport(report))), report);
});

test("rejects wrong types and unknown schemas", () => {
  const report = analyzedReport();

  assert.throws(
    () => validateReport({ ...report, schema: REPORT_SCHEMA + 1 }),
    /schema/
  );
  assert.throws(
    () =>
      validateReport({
        ...report,
        initialLoad: { ...report.initialLoad, head: "1" },
      }),
    /initialLoad.head must be a number/
  );
  report.bundles[0].kind = "<script>";
  assert.throws(() => validateReport(report), /kind must be one of/);
});

test("drops unknown fields", () => {
  const report = analyzedReport();
  report.extra = "x";
  report.bundles[0] = {
    ...report.bundles[0],
    ...JSON.parse('{"__proto__": {"polluted": true}}'),
  };

  const result = validateReport(report);

  assert.equal(result.extra, undefined);
  assert.equal(Object.getPrototypeOf(result.bundles[0]), null);
  assert.equal({}.polluted, undefined);
});

test("a no-JS-changes report needs nothing else", () => {
  assert.deepEqual({ ...validateReport(NO_JS_REPORT) }, NO_JS_REPORT);
});
