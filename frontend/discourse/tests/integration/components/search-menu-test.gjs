import {
  click,
  fillIn,
  render,
  settled,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import SearchMenu, {
  DEFAULT_TYPE_FILTER,
} from "discourse/components/search-menu";
import searchFixtures from "discourse/tests/fixtures/search-fixtures";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
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

    await render(
      <template>
        <SearchMenu @location="test" @searchInputId="icon-search-input" />
      </template>
    );

    assert
      .dom(".show-advanced-search")
      .exists("it shows full page search button");

    assert.dom(".menu-panel").doesNotExist("Menu panel is not rendered yet");

    await click("#icon-search-input");

    assert
      .dom(".menu-panel .search-menu-initial-options")
      .exists("Menu panel is rendered with initial options");

    await fillIn("#icon-search-input", "test");

    assert
      .dom(".label-suffix")
      .hasText(
        i18n("search.in_topics_posts"),
        "search label reflects context of search"
      );

    await triggerKeyEvent("#icon-search-input", "keyup", "Enter");

    assert
      .dom(".search-result-topic")
      .exists("search result is a list of topics");

    await triggerKeyEvent("#icon-search-input", "keydown", "Escape");

    assert.dom(".menu-panel").doesNotExist("Menu panel is gone");

    await click("#icon-search-input");
    await click("#icon-search-input");

    assert
      .dom(".search-result-topic")
      .exists("Clicking the term brought back search results");
  });

  test("clicking outside results hides and blurs input", async function (assert) {
    await render(
      <template>
        <div id="click-me"><SearchMenu
            @location="test"
            @searchInputId="icon-search-input"
          /></div>
      </template>
    );
    await click("#icon-search-input");

    assert
      .dom("#icon-search-input")
      .isFocused("Clicking the search term input focuses it");

    await click("#click-me");

    assert
      .dom(document.body)
      .isFocused("Clicking outside blurs focus and closes panel");
    assert
      .dom(".menu-panel .search-menu-initial-options")
      .doesNotExist("Menu panel is hidden");
  });

  test("rendering without a searchInputId provided", async function (assert) {
    await render(<template><SearchMenu @location="test" /></template>);

    assert
      .dom("#search-term.search-term__input")
      .exists("input defaults to id of search-term");
  });

  test("search-context state changes updates the UI", async function (assert) {
    const searchService = this.owner.lookup("service:search");

    searchService.searchContext = null;
    searchService.inTopicContext = false;
    await render(<template><SearchMenu @location="test" /></template>);

    assert
      .dom(".search-context")
      .doesNotExist("no search context button when searchContext is null");

    searchService.searchContext = { type: "private_messages" };
    await settled();

    assert
      .dom(".search-context")
      .exists(
        "PM context button appears when searchContext.type changes to private_messages"
      );

    await click(".search-context");

    assert
      .dom(".search-context")
      .doesNotExist("PM context button disappears when clear btn is pressed");
  });

  test("PM inbox context can be restored after being cleared", async function (assert) {
    const searchService = this.owner.lookup("service:search");

    searchService.searchContext = { type: "private_messages" };
    searchService.inTopicContext = false;

    await render(<template><SearchMenu @location="test" /></template>);

    assert.dom(".search-context").exists("PM context button appears initially");

    await click(".search-context");
    assert
      .dom(".search-context")
      .doesNotExist("PM context button disappears when cleared");

    await click("#search-term");

    await click(".search-menu-assistant-item .search-item-slug");

    assert
      .dom(".search-context")
      .exists(
        "PM context button reappears after selecting 'in:messages' suggestion"
      );
  });
});
