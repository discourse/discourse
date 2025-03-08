import { click, fillIn, findAll, visit } from "@ember/test-helpers";
import { module, test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Search - Mobile", function (needs) {
  needs.mobileView();

  module("cancel search", function () {
    test("with empty input search", async function (assert) {
      await visit("/");
      await click("#search-button");
      await click('[data-test-button="cancel-search-mobile"]');

      assert
        .dom('[data-test-selector="menu-panel"]')
        .doesNotExist("cancel button should close search panel");
    });

    test("with search term present", async function (assert) {
      await visit("/");
      await click("#search-button");
      await fillIn('[data-test-input="search-term"]', "search");

      assert.strictEqual(
        findAll('[data-test-item^="search-result-"]').length,
        5,
        "search results are listed on search value present"
      );

      await click('[data-test-button="cancel-search-mobile"]');
      await click("#search-button");

      assert.dom('[data-test-input="search-term"]').hasNoValue();
      assert.strictEqual(
        findAll('[data-test-item^="search-result-"]').length,
        0,
        "search results are reset"
      );
    });
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
