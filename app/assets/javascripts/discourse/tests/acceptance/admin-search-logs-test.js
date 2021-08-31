import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";

acceptance("Admin - Search Logs", function (needs) {
  needs.user();

  test("show search logs", async function (assert) {
    await visit("/admin/logs/search_logs");

    assert.ok(exists("table.search-logs-list.grid"), "has the div class");

    assert.ok(
      exists(".search-logs-list .admin-list-item .col"),
      "has a list of search logs"
    );

    await click(".term a");

    assert.ok(
      exists(".search-logs-filter"),
      "it should show the search log term page"
    );
  });
});
