import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Admin - Search Logs", function (needs) {
  needs.user();

  test("show search logs", async function (assert) {
    await visit("/admin/logs/search_logs");

    assert.dom("table.search-logs-list.grid").exists("has the div class");

    assert
      .dom(".search-logs-list .admin-list-item .col")
      .exists("has a list of search logs");

    await click(".term a");

    assert.dom(".search-logs-filter").exists("shows the search log term page");
  });
});
