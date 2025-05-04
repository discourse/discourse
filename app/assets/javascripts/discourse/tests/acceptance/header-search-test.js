import { visit, waitFor } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Header Search - Desktop Narrow", function (needs) {
  needs.user();
  needs.settings({
    search_experience: "search_field",
  });

  needs.hooks.afterEach(function () {
    document.body.style.width = null;
  });

  test("toggles search field when on narrow desktop", async function (assert) {
    await visit("/");
    assert.dom(".floating-search-input").exists("header search is displayed");

    assert.dom(".search-dropdown").doesNotExist("search icon is not displayed");

    document.body.style.width = "500px";

    await waitFor(".d-header-icons .search-dropdown", {
      timeout: 5000,
    });

    assert
      .dom(".floating-search-input")
      .doesNotExist("header search is not displayed");

    assert.dom(".search-dropdown").exists("search icon is displayed");

    document.body.style.width = "1000px";

    await waitFor(
      ".floating-search-input",
      {
        timeout: 5000,
      },
      "header search is displayed"
    );

    assert.dom(".search-dropdown").doesNotExist("search icon is not displayed");
  });
});
