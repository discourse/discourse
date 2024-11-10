import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Reports", function (needs) {
  needs.user();

  test("Visit reports page", async function (assert) {
    await visit("/admin/reports");

    assert.dom(".admin-reports-list__report").exists({ count: 1 });

    assert
      .dom(".admin-reports-list__report .admin-reports-list__report-title")
      .hasHtml("My report");

    assert
      .dom(
        ".admin-reports-list__report .admin-reports-list__report-description"
      )
      .hasHtml("List of my activities");
  });

  test("Visit report page", async function (assert) {
    await visit("/admin/reports/staff_logins");

    assert.dom(".export-csv-btn").exists();
  });
});
