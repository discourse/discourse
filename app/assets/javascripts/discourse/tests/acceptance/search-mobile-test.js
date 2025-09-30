import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Search - Mobile", function (needs) {
  needs.mobileView();

  test("search", async function (assert) {
    await visit("/");

    await click("#search-button");

    assert
      .dom("input.full-page-search")
      .exists("it shows the full page search form");

    assert
      .dom("#search-button")
      .doesNotExist("does not show icon search button on the full page search");

    assert
      .dom(".search-results .fps-topic")
      .doesNotExist("no results by default");

    await click(".advanced-filters summary");

    assert
      .dom(".advanced-filters[open]")
      .exists("it should expand advanced search filters");

    await fillIn(".search-query", "consectetur");
    await click(".search-cta");

    assert.dom(".fps-topic").exists({ count: 1 }, "has one post");

    assert
      .dom(".advanced-filters[open]")
      .doesNotExist("it should collapse advanced search filters");

    await click(".search-cta");

    assert
      .dom("input.full-page-search")
      .hasValue(
        "consectetur",
        "does not reset input when hitting search button again"
      );
  });
});
