import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  count,
  exists,
} from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

acceptance("Dashboard", function (needs) {
  needs.user();
  needs.settings({
    dashboard_visible_tabs: "moderation|security|reports|features",
    dashboard_general_tab_activity_metrics: "page_view_total_reqs",
  });
  needs.site({
    groups: [
      {
        id: 88,
        name: "tl1",
      },
      {
        id: 89,
        name: "tl2",
      },
    ],
  });

  test("default", async function (assert) {
    await visit("/admin");

    assert.ok(exists(".dashboard"), "has dashboard-next class");
  });

  test("tabs", async function (assert) {
    await visit("/admin");

    assert.ok(exists(".dashboard .navigation-item.general"), "general tab");
    assert.ok(
      exists(".dashboard .navigation-item.moderation"),
      "moderation tab"
    );
    assert.ok(exists(".dashboard .navigation-item.security"), "security tab");
    assert.ok(exists(".dashboard .navigation-item.reports"), "reports tab");
  });

  test("general tab", async function (assert) {
    await visit("/admin");

    assert.ok(exists(".custom-date-range-button"), "custom date range button");
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
  });

  test("moderation tab", async function (assert) {
    await visit("/admin");
    await click(".dashboard .navigation-item.moderation .navigation-link");

    assert.ok(exists(".custom-date-range-button"), "custom date range button");
    assert.ok(
      exists(".admin-report.moderators-activity"),
      "moderators activity report"
    );
  });

  test("activity metrics", async function (assert) {
    await visit("/admin");

    assert.dom(".admin-report.page-view-total-reqs .today-count").exists();
    assert.dom(".admin-report.page-view-total-reqs .yesterday-count").exists();
    assert.dom(".admin-report.page-view-total-reqs .sevendays-count").exists();
    assert
      .dom(".admin-report.page-view-total-reqs .thirty-days-count")
      .exists();
  });

  test("reports tab", async function (assert) {
    await visit("/admin");
    await click(".dashboard .navigation-item.reports .navigation-link");

    assert.strictEqual(count(".dashboard .admin-reports-list__report"), 1);

    await fillIn(".dashboard .admin-reports-header__filter", "flags");

    assert.strictEqual(count(".dashboard .admin-reports-list__report"), 0);

    await click(".dashboard .navigation-item.security .navigation-link");
    await click(".dashboard .navigation-item.reports .navigation-link");

    assert.strictEqual(
      count(".dashboard .admin-reports-list__report"),
      1,
      "navigating back and forth resets filter"
    );

    await fillIn(".dashboard .admin-reports-header__filter", "activities");

    assert.strictEqual(
      count(".dashboard .admin-reports-list__report"),
      1,
      "filter is case insensitive"
    );
  });

  test("reports filters", async function (assert) {
    await visit(
      '/admin/reports/signups_with_groups?end_date=2018-07-16&filters=%7B"group"%3A88%7D&start_date=2018-06-16'
    );

    const groupFilter = selectKit(".group-filter .combo-box");

    assert.strictEqual(
      groupFilter.header().value(),
      "88",
      "its set the value of the filter from the query params"
    );
  });
});

acceptance("Dashboard: dashboard_visible_tabs", function (needs) {
  needs.user();
  needs.settings({ dashboard_visible_tabs: "general|security|reports" });

  test("visible tabs", async function (assert) {
    await visit("/admin");

    assert.ok(exists(".dashboard .navigation-item.general"), "general tab");
    assert.notOk(
      exists(".dashboard .navigation-item.moderation"),
      "moderation tab"
    );
    assert.ok(exists(".dashboard .navigation-item.security"), "security tab");
    assert.ok(exists(".dashboard .navigation-item.reports"), "reports tab");
  });
});

acceptance("Dashboard: dashboard_hidden_reports", function (needs) {
  needs.user();
  needs.settings({
    dashboard_visible_tabs: "reports",
    dashboard_hidden_reports: "posts|dau_by_mau",
  });

  test("hidden reports", async function (assert) {
    await visit("/admin");

    assert.ok(exists(".admin-report.signups.is-visible"), "signups report");
    assert.notOk(exists(".admin-report.is-visible.posts"), "posts report");
    assert.notOk(
      exists(".admin-report.is-visible.dau-by-mau"),
      "dau-by-mau report"
    );
  });
});
