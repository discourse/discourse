import { click, fillIn, findAll, visit } from "@ember/test-helpers";
import { module, test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Search - Mobile", function (needs) {
  needs.mobileView();

  module("search behaviour", function () {
    test("on initial render (empty input search)", async function (assert) {
      await visit("/");
      await click("#search-button");

      assert
        .dom('[data-test-button="mobile-search"]')
        .isVisible("should show search button");
      assert
        .dom('[data-test-item="random-quick-tip"]')
        .doesNotExist("should not show random quick tip");
      assert
        .dom('[data-test-assistant-item^="recent-search-"]')
        .doesNotExist("should not show recent search suggestions");
      assert
        .dom('[data-test-selector="search-menu-initial-options"]')
        .doesNotExist("should not show initial options");
    });

    test("with search term present", async function (assert) {
      await visit("/");
      await click("#search-button");
      await fillIn('[data-test-input="search-term"]', "find");

      assert.strictEqual(
        findAll('[data-test-type-item^="search-result-topic-"]').length,
        5,
        "search results are listed on search value present"
      );
      assert
        .dom('[data-test-anchor="show-more"]')
        .exists("should show 'Show more' link");
    });

    test("on search term clear", async function (assert) {
      await visit("/");
      await click("#search-button");
      await fillIn('[data-test-input="search-term"]', "find");

      assert.strictEqual(
        findAll('[data-test-type-item^="search-result-topic-"]').length,
        5,
        "search results are listed on search value present"
      );

      await click('[data-test-anchor="clear-search-input"]');

      assert
        .dom('[data-test-selector="search-menu-results"]')
        .hasNoText("search results should be empty");
    });
  });

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
