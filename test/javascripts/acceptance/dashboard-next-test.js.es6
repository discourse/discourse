import { acceptance } from "helpers/qunit-helpers";

acceptance("Dashboard Next", {
  loggedIn: true,
  settings: {
    dashboard_general_tab_activity_metrics: "page_view_total_reqs"
  }
});

QUnit.test("Dashboard", async assert => {
  await visit("/admin");
  assert.ok(exists(".dashboard-next"), "has dashboard-next class");
});

QUnit.test("tabs", async assert => {
  await visit("/admin");

  assert.ok(exists(".dashboard-next .navigation-item.general"), "general tab");
  assert.ok(
    exists(".dashboard-next .navigation-item.moderation"),
    "moderation tab"
  );
  assert.ok(
    exists(".dashboard-next .navigation-item.security"),
    "security tab"
  );
  assert.ok(exists(".dashboard-next .navigation-item.reports"), "reports tab");
});

QUnit.test("general tab", async assert => {
  await visit("/admin");
  assert.ok(exists(".admin-report.signups"), "signups report");
  assert.ok(exists(".admin-report.posts"), "posts report");
  assert.ok(exists(".admin-report.dau-by-mau"), "dau-by-mau report");
  assert.ok(
    exists(".admin-report.daily-engaged-users"),
    "daily-engaged-users report"
  );
  assert.ok(
    exists(".admin-report.new-contributors"),
    "new-contributors report"
  );

  assert.equal(
    $(".section.dashboard-problems .problem-messages ul li:first-child")
      .html()
      .trim(),
    "Houston...",
    "displays problems"
  );
});

QUnit.test("general tab - activity metrics", async assert => {
  await visit("/admin");

  assert.equal(
    $(".admin-report.page-view-total-reqs .today-count")
      .text()
      .trim(),
    "1.1k"
  );
  assert.equal(
    $(".admin-report.page-view-total-reqs .yesterday-count")
      .text()
      .trim(),
    "2.5k"
  );
  assert.equal(
    $(".admin-report.page-view-total-reqs .sevendays-count")
      .text()
      .trim(),
    "18.6k"
  );
  assert.equal(
    $(".admin-report.page-view-total-reqs .thirty-days-count")
      .text()
      .trim(),
    "80.8k"
  );
});

QUnit.test("reports tab", async assert => {
  await visit("/admin");
  await click(".dashboard-next .navigation-item.reports .navigation-link");

  assert.equal(
    find(".dashboard-next .reports-index.section .reports-list .report").length,
    1
  );

  await fillIn(".dashboard-next .filter-reports-input", "flags");

  assert.equal(
    find(".dashboard-next .reports-index.section .reports-list .report").length,
    0
  );

  await click(".dashboard-next .navigation-item.security .navigation-link");
  await click(".dashboard-next .navigation-item.reports .navigation-link");

  assert.equal(
    find(".dashboard-next .reports-index.section .reports-list .report").length,
    1,
    "navigating back and forth resets filter"
  );

  await fillIn(".dashboard-next .filter-reports-input", "activities");

  assert.equal(
    find(".dashboard-next .reports-index.section .reports-list .report").length,
    1,
    "filter is case insensitive"
  );
});
