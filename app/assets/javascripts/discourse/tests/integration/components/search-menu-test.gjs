import { click, fillIn, render, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import SearchMenu from "discourse/components/search-menu";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import I18n from "discourse-i18n";

// Note this isn't a full-fledge test of the search menu. Those tests are in
// acceptance/glimmer-search-test.js. This is simply about the rendering of the
// menu panel separate from the search input.
module("Integration | Component | search-menu", function (hooks) {
  setupRenderingTest(hooks);

  test("rendering standalone", async function (assert) {
    await render(<template><SearchMenu /></template>);

    assert.ok(
      exists(".show-advanced-search"),
      "it shows full page search button"
    );

    assert.notOk(exists(".menu-panel"), "Menu panel is not rendered yet");

    await click("#search-term");

    assert.ok(
      exists(".menu-panel .search-menu-initial-options"),
      "Menu panel is rendered with initial options"
    );

    await fillIn("#search-term", "test");

    assert.strictEqual(
      query(".label-suffix").textContent.trim(),
      I18n.t("search.in_topics_posts"),
      "search label reflects context of search"
    );

    await triggerKeyEvent("#search-term", "keyup", "Enter");

    assert.ok(
      exists(".search-result-topic"),
      "search result is a list of topics"
    );

    await triggerKeyEvent("#search-term", "keyup", "Escape");

    assert.notOk(exists(".menu-panel"), "Menu panel is gone");

    await click("#search-term");
    await click("#search-term");

    assert.ok(
      exists(".search-result-topic"),
      "Clicking the term brought back search results"
    );
  });
});
