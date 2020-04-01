import selectKit from "helpers/select-kit-helper";
import { acceptance } from "helpers/qunit-helpers";

acceptance("Dashboard", {
  loggedIn: true,
  settings: {
    dashboard_general_tab_activity_metrics: "page_view_total_reqs"
  },
  site: {
    groups: [
      {
        id: 88,
        name: "tl1"
      },
      {
        id: 89,
        name: "tl2"
      }
    ]
  }
});

QUnit.test("Dashboard", async assert => {
  await visit("/admin");
  assert.ok(exists(".dashboard"), "has dashboard-next class");
});

QUnit.test("tabs", async assert => {
  await visit("/admin");

  assert.ok(exists(".dashboard .navigation-item.general"), "general tab");
  assert.ok(exists(".dashboard .navigation-item.moderation"), "moderation tab");
  assert.ok(exists(".dashboard .navigation-item.security"), "security tab");
  assert.ok(exists(".dashboard .navigation-item.reports"), "reports tab");
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

  assert.ok(exists(".admin-report.page-view-total-reqs .today-count"));
  assert.ok(exists(".admin-report.page-view-total-reqs .yesterday-count"));
  assert.ok(exists(".admin-report.page-view-total-reqs .sevendays-count"));
  assert.ok(exists(".admin-report.page-view-total-reqs .thirty-days-count"));
});

QUnit.test("reports tab", async assert => {
  await visit("/admin");
  await click(".dashboard .navigation-item.reports .navigation-link");

  assert.equal(
    find(".dashboard .reports-index.section .reports-list .report").length,
    1
  );

  await fillIn(".dashboard .filter-reports-input", "flags");

  assert.equal(
    find(".dashboard .reports-index.section .reports-list .report").length,
    0
  );

  await click(".dashboard .navigation-item.security .navigation-link");
  await click(".dashboard .navigation-item.reports .navigation-link");

  assert.equal(
    find(".dashboard .reports-index.section .reports-list .report").length,
    1,
    "navigating back and forth resets filter"
  );

  await fillIn(".dashboard .filter-reports-input", "activities");

  assert.equal(
    find(".dashboard .reports-index.section .reports-list .report").length,
    1,
    "filter is case insensitive"
  );
});

QUnit.test("report filters", async assert => {
  await visit(
    '/admin/reports/signups?end_date=2018-07-16&filters=%7B"group"%3A88%7D&start_date=2018-06-16'
  );

  const groupFilter = selectKit(".group-filter .combo-box");

  assert.equal(
    groupFilter.header().value(),
    88,
    "its set the value of the filter from the query params"
  );
});
