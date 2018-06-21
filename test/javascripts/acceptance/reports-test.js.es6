import { acceptance } from "helpers/qunit-helpers";

acceptance("Reports", {
  loggedIn: true
});

QUnit.test("Visit reports page", assert => {
  visit("/admin/reports");

  andThen(() => {
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
});
