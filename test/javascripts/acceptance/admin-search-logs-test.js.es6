import { acceptance } from "helpers/qunit-helpers";
acceptance("Admin - Search Logs", { loggedIn: true });

QUnit.skip("show search logs", async assert => {
  await visit("/admin/logs/search_logs");

  assert.ok($("table.search-logs-list.grid").length, "has the div class");

  assert.ok(
    exists(".search-logs-list .admin-list-item .col"),
    "has a list of search logs"
  );

  await click(".term a");

  assert.ok(
    $("div.search-logs-filter").length,
    "it should show the search log term page"
  );
});
