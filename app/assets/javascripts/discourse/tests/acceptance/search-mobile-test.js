import { queryAll } from "discourse/tests/helpers/qunit-helpers";
import { exists } from "discourse/tests/helpers/qunit-helpers";
import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Search - Mobile", function (needs) {
  needs.mobileView();

  test("search", async (assert) => {
    await visit("/");

    await click("#search-button");

    assert.ok(
      exists("input.full-page-search"),
      "it shows the full page search form"
    );

    assert.ok(!exists(".search-results .fps-topic"), "no results by default");

    await click(".search-advanced-title");

    assert.ok(
      queryAll(".search-advanced-filters").length === 1,
      "it should expand advanced search filters"
    );

    await fillIn(".search-query", "posts");
    await click(".search-cta");

    assert.ok(queryAll(".fps-topic").length === 1, "has one post");

    assert.ok(
      queryAll(".search-advanced-filters").length === 0,
      "it should collapse advanced search filters"
    );

    await click("#search-button");

    assert.equal(
      queryAll("input.full-page-search").val(),
      "posts",
      "it does not reset input when hitting search icon again"
    );
  });
});
