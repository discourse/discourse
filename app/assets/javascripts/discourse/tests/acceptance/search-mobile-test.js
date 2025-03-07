import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Search - Mobile", function (needs) {
  needs.mobileView();

  test("cancel search", async function (assert) {
    await visit("/");
    await click("#search-button");
    await click('[data-test-button="cancel-search-mobile"]');

    assert
      .dom('[data-test-selector="menu-panel"]')
      .doesNotExist("cancel button should close search panel");
  });

  test("full page search", async function (assert) {
    await visit("/");
    await click("#search-button");
    await click('[data-test-button="show-advanced-search"]');
    assert
      .dom("input.full-page-search")
      .exists("it shows the full page search form");

    assert
      .dom(".search-results .fps-topic")
      .doesNotExist("no results by default");

    await click(".advanced-filters summary");

    assert
      .dom(".advanced-filters[open]")
      .exists("it should expand advanced search filters");

    await fillIn(".search-query", "discourse");
    await click(".search-cta");

    assert.dom(".fps-topic").exists({ count: 1 }, "has one post");

    assert
      .dom(".advanced-filters[open]")
      .doesNotExist("it should collapse advanced search filters");

    await click("#search-button");

    assert
      .dom("input.full-page-search")
      .hasValue(
        "discourse",
        "does not reset input when hitting search icon again"
      );
  });
});
