import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { click, render } from "@ember/test-helpers";
import { count, exists, query } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module("Integration | Component | admin-report", function (hooks) {
  setupRenderingTest(hooks);

  test("default", async function (assert) {
    await render(hbs`<AdminReport @dataSourceName="signups" />`);

    assert.ok(exists(".admin-report.signups"));

    assert.ok(exists(".admin-report.signups", "it defaults to table mode"));

    assert.strictEqual(
      query(".header .item.report").innerText.trim(),
      "Signups",
      "it has a title"
    );

    assert.strictEqual(
      query(".header .info").getAttribute("data-tooltip"),
      "New account registrations for this period",
      "it has a description"
    );

    assert.strictEqual(
      query(
        ".admin-report-table thead tr th:first-child .title"
      ).innerText.trim(),
      "Day",
      "it has col headers"
    );

    assert.strictEqual(
      query(
        ".admin-report-table thead tr th:nth-child(2) .title"
      ).innerText.trim(),
      "Count",
      "it has col headers"
    );

    assert.strictEqual(
      query(
        ".admin-report-table tbody tr:nth-child(1) td:nth-child(1)"
      ).innerText.trim(),
      "June 16, 2018",
      "it has rows"
    );

    assert.strictEqual(
      query(
        ".admin-report-table tbody tr:nth-child(1) td:nth-child(2)"
      ).innerText.trim(),
      "12",
      "it has rows"
    );

    assert.ok(exists(".total-row"), "it has totals");

    await click(".admin-report-table-header.y .sort-btn");

    assert.strictEqual(
      query(
        ".admin-report-table tbody tr:nth-child(1) td:nth-child(2)"
      ).innerText.trim(),
      "7",
      "it can sort rows"
    );
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

    assert.ok(exists(".pagination"), "it paginates the results");
    assert.strictEqual(
      count(".pagination button"),
      3,
      "it creates the correct number of pages"
    );

    assert.notOk(exists(".totals-sample-table"), "it hides totals");
  });

  test("switch modes", async function (assert) {
    await render(
      hbs`<AdminReport @dataSourceName="signups" @showFilteringUI={{true}} />`
    );

    await click(".mode-btn.chart");

    assert.notOk(exists(".admin-report-table"), "it removes the table");
    assert.ok(exists(".admin-report-chart"), "it shows the chart");
  });

  test("timeout", async function (assert) {
    await render(hbs`<AdminReport @dataSourceName="signups_timeout" />`);

    assert.ok(exists(".alert-error.timeout"), "it displays a timeout error");
  });

  test("no data", async function (assert) {
    await render(hbs`<AdminReport @dataSourceName="posts" />`);

    assert.ok(exists(".no-data"), "it displays a no data alert");
  });

  test("exception", async function (assert) {
    await render(hbs`<AdminReport @dataSourceName="signups_exception" />`);

    assert.ok(exists(".alert-error.exception"), "it displays an error");
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

    assert.ok(
      exists(".alert-error.rate-limited"),
      "it displays a rate limited error"
    );
  });

  test("post edits", async function (assert) {
    await render(hbs`<AdminReport @dataSourceName="post_edits" />`);

    assert.ok(
      exists(".admin-report.post-edits"),
      "it displays the post edits report"
    );
  });

  test("not found", async function (assert) {
    await render(hbs`<AdminReport @dataSourceName="not_found" />`);

    assert.ok(
      exists(".alert-error.not-found"),
      "it displays a not found error"
    );
  });
});
