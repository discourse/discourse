import componentTest from "helpers/component-test";

moduleForComponent("admin-report", {
  integration: true
});

componentTest("default", {
  template: "{{admin-report dataSourceName='signups'}}",

  async test(assert) {
    assert.ok(exists(".admin-report.signups"));

    assert.ok(
      exists(".admin-report.table.signups", "it defaults to table mode")
    );

    assert.equal(
      find(".report-header .title")
        .text()
        .trim(),
      "Signups",
      "it has a title"
    );

    assert.equal(
      find(".report-header .info").attr("data-tooltip"),
      "New account registrations for this period",
      "it has a description"
    );

    assert.equal(
      find(".report-body .report-table thead tr th:first-child")
        .text()
        .trim(),
      "Day",
      "it has col headers"
    );

    assert.equal(
      find(".report-body .report-table thead tr th:nth-child(2)")
        .text()
        .trim(),
      "Count",
      "it has col headers"
    );

    assert.equal(
      find(".report-body .report-table tbody tr:nth-child(1) td:nth-child(1)")
        .text()
        .trim(),
      "June 16, 2018",
      "it has rows"
    );

    assert.equal(
      find(".report-body .report-table tbody tr:nth-child(1) td:nth-child(2)")
        .text()
        .trim(),
      "12",
      "it has rows"
    );

    assert.ok(exists(".total-row"), "it has totals");

    await click(".admin-report-table-header.y .sort-button");
    assert.equal(
      find(".report-body .report-table tbody tr:nth-child(1) td:nth-child(2)")
        .text()
        .trim(),
      "7",
      "it can sort rows"
    );
  }
});

componentTest("options", {
  template: "{{admin-report dataSourceName='signups' reportOptions=options}}",

  beforeEach() {
    this.set("options", {
      table: {
        perPage: 4,
        total: false
      }
    });
  },

  test(assert) {
    assert.ok(exists(".pagination"), "it paginates the results");
    assert.equal(
      find(".pagination button").length,
      3,
      "it creates the correct number of pages"
    );

    assert.notOk(exists(".totals-sample-table"), "it hides totals");
  }
});

componentTest("switch modes", {
  template: "{{admin-report dataSourceName='signups'}}",

  async test(assert) {
    await click(".mode-button.chart");

    assert.notOk(exists(".admin-report.table.signups"), "it removes the table");
    assert.ok(exists(".admin-report.chart.signups"), "it shows the chart");
  }
});

componentTest("timeout", {
  template: "{{admin-report dataSourceName='signups_timeout'}}",

  test(assert) {
    assert.ok(exists(".alert-error"), "it displays a timeout error");
  }
});

componentTest("no data", {
  template: "{{admin-report dataSourceName='posts'}}",

  test(assert) {
    assert.ok(exists(".no-data-alert"), "it displays a no data alert");
  }
});
