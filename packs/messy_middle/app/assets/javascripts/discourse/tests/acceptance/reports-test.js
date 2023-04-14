import {
  acceptance,
  count,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";

acceptance("Reports", function (needs) {
  needs.user();

  test("Visit reports page", async function (assert) {
    await visit("/admin/reports");

    assert.strictEqual(count(".reports-list .report"), 1);

    const report = query(".reports-list .report:first-child");

    assert.strictEqual(
      report.querySelector(".report-title").innerHTML.trim(),
      "My report"
    );

    assert.strictEqual(
      report.querySelector(".report-description").innerHTML.trim(),
      "List of my activities"
    );
  });

  test("Visit report page", async function (assert) {
    await visit("/admin/reports/staff_logins");

    assert.ok(exists(".export-csv-btn"));
  });
});
