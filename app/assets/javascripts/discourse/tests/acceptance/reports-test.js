import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  count,
  query,
} from "discourse/tests/helpers/qunit-helpers";

acceptance("Reports", function (needs) {
  needs.user();

  test("Visit reports page", async function (assert) {
    await visit("/admin/reports");

    assert.strictEqual(count(".admin-reports-list__report"), 1);

    const report = query(".admin-reports-list__report:first-child");

    assert.strictEqual(
      report
        .querySelector(".admin-reports-list__report-title")
        .innerHTML.trim(),
      "My report"
    );

    assert.strictEqual(
      report
        .querySelector(".admin-reports-list__report-description")
        .innerHTML.trim(),
      "List of my activities"
    );
  });

  test("Visit report page", async function (assert) {
    await visit("/admin/reports/staff_logins");

    assert.dom(".export-csv-btn").exists();
  });
});
