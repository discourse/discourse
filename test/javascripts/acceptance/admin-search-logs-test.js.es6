import { acceptance } from "helpers/qunit-helpers";
acceptance("Admin - Search Logs", { loggedIn: true });

QUnit.test("show search logs", assert => {
  visit("/admin/logs/search_logs");
  andThen(() => {
    assert.ok($("table.search-logs-list.grid").length, "has the div class");
    assert.ok(
      exists(".search-logs-list .admin-list-item .col"),
      "has a list of search logs"
    );
  });
});
