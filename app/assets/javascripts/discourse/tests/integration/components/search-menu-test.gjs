import { click, fillIn, render, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import SearchMenu, {
  DEFAULT_TYPE_FILTER,
} from "discourse/components/search-menu";
import searchFixtures from "discourse/tests/fixtures/search-fixtures";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { query } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

// Note this isn't a full-fledge test of the search menu. Those tests are in
// acceptance/search-test.js. This is simply about the rendering of the
// menu panel separate from the search input.
module("Integration | Component | search-menu", function (hooks) {
  setupRenderingTest(hooks);

  test("rendering standalone", async function (assert) {
    pretender.get("/search/query", (request) => {
      if (request.queryParams.type_filter === DEFAULT_TYPE_FILTER) {
        // posts/topics are not present in the payload by default
        return response({
          users: searchFixtures["search/query"]["users"],
          categories: searchFixtures["search/query"]["categories"],
          groups: searchFixtures["search/query"]["groups"],
          grouped_search_result:
            searchFixtures["search/query"]["grouped_search_result"],
        });
      }
      return response(searchFixtures["search/query"]);
    });

    await render(<template><SearchMenu /></template>);

    assert
      .dom(".show-advanced-search")
      .exists("it shows full page search button");

    assert.dom(".menu-panel").doesNotExist("Menu panel is not rendered yet");

    await click("#search-term");

    assert
      .dom(".menu-panel .search-menu-initial-options")
      .exists("Menu panel is rendered with initial options");

    await fillIn("#search-term", "test");

    assert.strictEqual(
      query(".label-suffix").textContent.trim(),
      i18n("search.in_topics_posts"),
      "search label reflects context of search"
    );

    await triggerKeyEvent("#search-term", "keyup", "Enter");

    assert
      .dom(".search-result-topic")
      .exists("search result is a list of topics");

    await triggerKeyEvent("#search-term", "keydown", "Escape");

    assert.dom(".menu-panel").doesNotExist("Menu panel is gone");

    await click("#search-term");
    await click("#search-term");

    assert
      .dom(".search-result-topic")
      .exists("Clicking the term brought back search results");
  });

  test("clicking outside results hides and blurs input", async function (assert) {
    await render(<template><div id="click-me"><SearchMenu /></div></template>);
    await click("#search-term");

    assert.strictEqual(
      document.activeElement,
      query("#search-term"),
      "Clicking the search term input focuses it"
    );

    await click("#click-me");

    assert.strictEqual(
      document.activeElement,
      document.body,
      "Clicking outside blurs focus and closes panel"
    );
    assert
      .dom(".menu-panel .search-menu-initial-options")
      .doesNotExist("Menu panel is hidden");
  });
});
