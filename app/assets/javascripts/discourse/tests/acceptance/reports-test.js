import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";

acceptance("Reports", function (needs) {
  needs.user();

  test("Visit reports page", async function (assert) {
    await visit("/admin/reports");

    assert.equal($(".reports-list .report").length, 1);

    const $report = $(".reports-list .report:first-child");

    assert.equal($report.find(".report-title").html().trim(), "My report");

    assert.equal(
      $report.find(".report-description").html().trim(),
      "List of my activities"
    );
  });

  test("Visit report page", async function (assert) {
    await visit("/admin/reports/staff_logins");

    assert.ok(exists(".export-csv-btn"));
  });
});
