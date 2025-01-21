import { click, render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module("Integration | Component | admin-report", function (hooks) {
  setupRenderingTest(hooks);

  test("default", async function (assert) {
    await render(hbs`<AdminReport @dataSourceName="signups" />`);

    assert.dom(".admin-report.signups").exists();
    assert.dom(".admin-report-table").exists("defaults to table mode");
    assert
      .dom(".d-page-subheader .d-page-subheader__title")
      .hasText("Signups", "has a title");
    assert
      .dom(".d-page-subheader .d-page-subheader__description")
      .hasText(
        "New account registrations for this period",
        "has a description"
      );

    assert
      .dom(".admin-report-table thead tr th:first-child .title")
      .hasText("Day", "has col headers");

    assert
      .dom(".admin-report-table thead tr th:nth-child(2) .title")
      .hasText("Count", "has col headers");

    assert
      .dom(".admin-report-table tbody tr:nth-child(1) td:nth-child(1)")
      .hasText("June 16, 2018", "has rows");

    assert
      .dom(".admin-report-table tbody tr:nth-child(1) td:nth-child(2)")
      .hasText("12", "has rows");

    assert.dom(".total-row").exists("has totals");

    await click(".admin-report-table-header.y .sort-btn");

    assert
      .dom(".admin-report-table tbody tr:nth-child(1) td:nth-child(2)")
      .hasText("7", "can sort rows");
  });

  test("options", async function (assert) {
    this.set("options", {
      table: {
        perPage: 4,
        total: false,
      },
    });

    await render(
      hbs`<AdminReport @dataSourceName="signups" @reportOptions={{this.options}} />`
    );

    assert.dom(".pagination").exists("paginates the results");
    assert
      .dom(".pagination button")
      .exists({ count: 3 }, "creates the correct number of pages");

    assert.dom(".totals-sample-table").doesNotExist("hides totals");
  });

  test("switch modes", async function (assert) {
    await render(
      hbs`<AdminReport @dataSourceName="signups" @showFilteringUI={{true}} />`
    );

    await click(".mode-btn.chart");

    assert.dom(".admin-report-table").doesNotExist("removes the table");
    assert.dom(".admin-report-chart").exists("shows the chart");
  });

  test("timeout", async function (assert) {
    await render(hbs`<AdminReport @dataSourceName="signups_timeout" />`);

    assert.dom(".alert-error.timeout").exists("displays a timeout error");
  });

  test("no data", async function (assert) {
    await render(hbs`<AdminReport @dataSourceName="posts" />`);

    assert.dom(".no-data").exists("displays a no data alert");
  });

  test("exception", async function (assert) {
    await render(hbs`<AdminReport @dataSourceName="signups_exception" />`);

    assert.dom(".alert-error.exception").exists("displays an error");
  });

  test("rate limited", async function (assert) {
    pretender.get("/admin/reports/bulk", () =>
      response(429, {
        errors: [
          "You’ve performed this action too many times. Please wait 10 seconds before trying again.",
        ],
        error_type: "rate_limit",
        extras: { wait_seconds: 10 },
      })
    );

    await render(hbs`<AdminReport @dataSourceName="signups_rate_limited" />`);

    assert
      .dom(".alert-error.rate-limited")
      .exists("displays a rate limited error");
  });

  test("post edits", async function (assert) {
    await render(hbs`<AdminReport @dataSourceName="post_edits" />`);

    assert
      .dom(".admin-report.post-edits")
      .exists("displays the post edits report");
  });

  test("not found", async function (assert) {
    await render(hbs`<AdminReport @dataSourceName="not_found" />`);

    assert.dom(".alert-error.not-found").exists("displays a not found error");
  });
});
