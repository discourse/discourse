import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import GoogleSearch from "discourse/components/google-search";
import getURL from "discourse/lib/get-url";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | GoogleSearch", function (hooks) {
  setupRenderingTest(hooks);

  test("scopes the search to this site", async function (assert) {
    await render(<template><GoogleSearch @searchTerm="cats" /></template>);

    assert.dom("input[name='q']").hasValue("cats", "carries the search term");
    assert
      .dom("input[name='as_sitesearch']")
      .hasValue(
        `${location.protocol}//${location.host}${getURL("/")}`,
        "restricts the search to this site's url"
      );
  });

  test("hides itself when login is required", async function (assert) {
    this.siteSettings.login_required = true;

    await render(<template><GoogleSearch @searchTerm="cats" /></template>);

    assert.dom(".google-search-form").hasClass("hidden");
  });
});
