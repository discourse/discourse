import { acceptance } from "helpers/qunit-helpers";
acceptance("Admin - Search Log Term", { loggedIn: true });

QUnit.test("show search log term details", assert => {
  visit("/admin/logs/search_logs/term/ruby");
  andThen(() => {
    assert.ok($("div.search-logs-filter").length, "has the search type filter");
    assert.ok(exists("canvas.chartjs-render-monitor"), "has graph canvas");
    assert.ok(exists("div.header-search-results"), "has header search results");
  });
});
