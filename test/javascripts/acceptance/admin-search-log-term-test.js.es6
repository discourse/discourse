import { acceptance } from "helpers/qunit-helpers";
acceptance("Admin - Search Log Term", { loggedIn: true });

QUnit.test("show search log term details", assert => {
  visit("/admin/logs/search_logs/term/ruby");
  andThen(() => {
    assert.ok($('div.search-logs-filter').length, "has the search type filter");
    assert.ok(exists('iframe.chartjs-hidden-iframe'), "has graph iframe");
  });
});
