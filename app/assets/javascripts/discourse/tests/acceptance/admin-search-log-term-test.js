import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Admin - Search Log Term", function (needs) {
  needs.user();

  test("show search log term details", async function (assert) {
    await visit("/admin/logs/search_logs/term?term=ruby");

    assert.dom(".search-logs-filter").exists("has the search type filter");
    assert.dom("canvas").exists("has graph canvas");
    assert.dom("div.header-search-results").exists("has header search results");
  });
});
