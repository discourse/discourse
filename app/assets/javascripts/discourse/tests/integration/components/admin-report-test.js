import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  count,
  discourseModule,
  exists,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import { click } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import pretender from "discourse/tests/helpers/create-pretender";

discourseModule("Integration | Component | admin-report", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("default", {
    template: hbs`{{admin-report dataSourceName='signups'}}`,

    async test(assert) {
      assert.ok(exists(".admin-report.signups"));

      assert.ok(exists(".admin-report.signups", "it defaults to table mode"));

      assert.equal(
        queryAll(".header .item.report").text().trim(),
        "Signups",
        "it has a title"
      );

      assert.equal(
        queryAll(".header .info").attr("data-tooltip"),
        "New account registrations for this period",
        "it has a description"
      );

      assert.equal(
        queryAll(".admin-report-table thead tr th:first-child .title")
          .text()
          .trim(),
        "Day",
        "it has col headers"
      );

      assert.equal(
        queryAll(".admin-report-table thead tr th:nth-child(2) .title")
          .text()
          .trim(),
        "Count",
        "it has col headers"
      );

      assert.equal(
        queryAll(".admin-report-table tbody tr:nth-child(1) td:nth-child(1)")
          .text()
          .trim(),
        "June 16, 2018",
        "it has rows"
      );

      assert.equal(
        queryAll(".admin-report-table tbody tr:nth-child(1) td:nth-child(2)")
          .text()
          .trim(),
        "12",
        "it has rows"
      );

      assert.ok(exists(".total-row"), "it has totals");

      await click(".admin-report-table-header.y .sort-btn");

      assert.equal(
        queryAll(".admin-report-table tbody tr:nth-child(1) td:nth-child(2)")
          .text()
          .trim(),
        "7",
        "it can sort rows"
      );
    },
  });

  componentTest("options", {
    template: hbs`{{admin-report dataSourceName='signups' reportOptions=options}}`,

    beforeEach() {
      this.set("options", {
        table: {
          perPage: 4,
          total: false,
        },
      });
    },

    test(assert) {
      assert.ok(exists(".pagination"), "it paginates the results");
      assert.equal(
        count(".pagination button"),
        3,
        "it creates the correct number of pages"
      );

      assert.notOk(exists(".totals-sample-table"), "it hides totals");
    },
  });

  componentTest("switch modes", {
    template: hbs`{{admin-report dataSourceName='signups' showFilteringUI=true}}`,

    async test(assert) {
      await click(".mode-btn.chart");

      assert.notOk(exists(".admin-report-table"), "it removes the table");
      assert.ok(exists(".admin-report-chart"), "it shows the chart");
    },
  });

  componentTest("timeout", {
    template: hbs`{{admin-report dataSourceName='signups_timeout'}}`,

    test(assert) {
      assert.ok(exists(".alert-error.timeout"), "it displays a timeout error");
    },
  });

  componentTest("no data", {
    template: hbs`{{admin-report dataSourceName='posts'}}`,

    test(assert) {
      assert.ok(exists(".no-data"), "it displays a no data alert");
    },
  });

  componentTest("exception", {
    template: hbs`{{admin-report dataSourceName='signups_exception'}}`,

    test(assert) {
      assert.ok(exists(".alert-error.exception"), "it displays an error");
    },
  });

  componentTest("rate limited", {
    beforeEach() {
      pretender.get("/admin/reports/bulk", () => {
        return [
          429,
          { "Content-Type": "application/json" },
          {
            errors: [
              "You’ve performed this action too many times. Please wait 10 seconds before trying again.",
            ],
            error_type: "rate_limit",
            extras: { wait_seconds: 10 },
          },
        ];
      });
    },

    template: hbs`{{admin-report dataSourceName='signups_rate_limited'}}`,

    test(assert) {
      assert.ok(
        exists(".alert-error.rate-limited"),
        "it displays a rate limited error"
      );
    },
  });

  componentTest("not found", {
    template: hbs`{{admin-report dataSourceName='not_found'}}`,

    test(assert) {
      assert.ok(
        exists(".alert-error.not-found"),
        "it displays a not found error"
      );
    },
  });
});
