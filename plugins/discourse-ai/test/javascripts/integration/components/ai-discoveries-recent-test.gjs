import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import RecentSearches from "discourse/components/search-menu/results/recent-searches";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | AiDiscoveriesRecent", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.currentUser.set("recent_searches", ["miyazaki"]);
    this.siteSettings.log_search_queries = true;
  });

  test("clearing offers itself at the end of the list", async function (assert) {
    await render(<template><RecentSearches @location="header" /></template>);

    assert
      .dom(".search-menu-recent .heading")
      .doesNotExist("the history no longer announces itself");
    assert
      .dom(".search-menu-recent > *:last-child")
      .hasClass(
        "clear-recent-searches",
        "clearing closes out the list instead of heading it"
      );
  });
});
