import { acceptance } from "helpers/qunit-helpers";

acceptance("Reports", {
  loggedIn: true
});

QUnit.test("Visit reports page", async assert => {
  await visit("/admin/reports");

  assert.equal($(".reports-list .report").length, 1);

  const $report = $(".reports-list .report:first-child");

  assert.equal(
    $report
      .find(".report-title")
      .html()
      .trim(),
    "My report"
  );

  assert.equal(
    $report
      .find(".report-description")
      .html()
      .trim(),
    "List of my activities"
  );
});

QUnit.test("Visit report page", async assert => {
  await visit("/admin/reports/staff_logins");

  assert.ok(exists(".export-csv-btn"));
});
