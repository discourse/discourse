import { click, currentURL, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
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

  test("tabs", async function (assert) {
    await visit("/admin");

    assert.dom(".dashboard .navigation-item.general").exists("general tab");
    assert
      .dom(".dashboard .navigation-item.moderation")
      .exists("moderation tab");
    assert.dom(".dashboard .navigation-item.security").exists("security tab");
    assert.dom(".dashboard .navigation-item.reports").exists("reports tab");
  });

  test("general tab", async function (assert) {
    await visit("/admin");

    assert.dom(".custom-date-range-button").exists("custom date range button");
    assert.dom(".admin-report.signups").exists("signups report");
    assert.dom(".admin-report.posts").exists("posts report");
    assert.dom(".admin-report.dau-by-mau").exists("dau-by-mau report");
    assert
      .dom(".admin-report.daily-engaged-users")
      .exists("daily-engaged-users report");
    assert
      .dom(".admin-report.new-contributors")
      .exists("new-contributors report");
  });

  test("custom date range updates period display", async function (assert) {
    await visit("/admin");

    const periodChooser = selectKit(".period-chooser");

    assert.strictEqual(periodChooser.header().value(), "monthly");

    await click(".custom-date-range-button");
    await click(".custom-date-range-modal .d-modal__footer .btn");

    assert.strictEqual(periodChooser.header().value(), "custom");
    assert.dom(".period-chooser-header .date-section").hasText("Custom");

    await periodChooser.expand();
    await periodChooser.selectRowByValue("yearly");

    assert.strictEqual(periodChooser.header().value(), "yearly");
    assert.dom(".period-chooser-header .date-section").hasText("Year");
  });

  test("custom date range is reflected in URL query params", async function (assert) {
    await visit("/admin");

    await click(".custom-date-range-button");
    await click(".custom-date-range-modal .d-modal__footer .btn");

    const url = currentURL();
    assert.true(url.includes("period=custom"), "period=custom is in URL");
    assert.true(url.includes("start_date="), "start_date is in URL");
    assert.true(url.includes("end_date="), "end_date is in URL");
  });

  test("URL query params restore custom date range", async function (assert) {
    await visit(
      "/admin?period=custom&start_date=2024-01-01&end_date=2024-01-31"
    );

    const periodChooser = selectKit(".period-chooser");
    assert.strictEqual(periodChooser.header().value(), "custom");
    assert.dom(".period-chooser-header .date-section").hasText("Custom");
    // The date range from query params should be displayed (dates may vary slightly due to UTC)
    assert.dom(".period-chooser-header .top-date-string").exists();
    assert.dom(".period-chooser-header .top-date-string").includesText("–");
  });

  test("moderation tab", async function (assert) {
    await visit("/admin");
    await click(".dashboard .navigation-item.moderation .navigation-link");

    assert.dom(".custom-date-range-button").exists("custom date range button");
    assert
      .dom(".admin-report.moderators-activity")
      .exists("moderators activity report");
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

    assert
      .dom(
        ".dashboard .admin-reports-list .admin-section-landing-item__content"
      )
      .exists({ count: 1 });

    await fillIn(".dashboard .admin-filter-controls__input", "flags");

    assert
      .dom(
        ".dashboard .admin-reports-list .admin-section-landing-item__content"
      )
      .doesNotExist();

    await click(".dashboard .navigation-item.security .navigation-link");
    await click(".dashboard .navigation-item.reports .navigation-link");

    assert
      .dom(
        ".dashboard .admin-reports-list .admin-section-landing-item__content"
      )
      .exists({ count: 1 }, "navigating back and forth resets filter");

    await fillIn(".dashboard .admin-filter-controls__input", "activities");

    assert
      .dom(
        ".dashboard .admin-reports-list .admin-section-landing-item__content"
      )
      .exists({ count: 1 }, "filter is case insensitive");
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

    assert.dom(".dashboard .navigation-item.general").exists("general tab");
    assert
      .dom(".dashboard .navigation-item.moderation")
      .doesNotExist("moderation tab");
    assert.dom(".dashboard .navigation-item.security").exists("security tab");
    assert.dom(".dashboard .navigation-item.reports").exists("reports tab");
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

    assert.dom(".admin-report.signups.is-visible").exists("signups report");
    assert.dom(".admin-report.is-visible.posts").doesNotExist("posts report");
    assert
      .dom(".admin-report.is-visible.dau-by-mau")
      .doesNotExist("dau-by-mau report");
  });
});
