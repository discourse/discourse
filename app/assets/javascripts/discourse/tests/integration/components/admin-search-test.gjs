import { fillIn, render, triggerKeyEvent } from "@ember/test-helpers";
import { module, skip, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import AdminSearch from "admin/components/admin-search";

module("Integration | Component | AdminSearch", function (hooks) {
  setupRenderingTest(hooks);

  test("shows search results", async function (assert) {
    await render(<template><AdminSearch /></template>);
    await fillIn(".admin-search__input-field", "title");

    assert.dom(".admin-search__results").exists();
    assert.dom(".admin-search__result").exists({ count: 1 });
  });

  skip("navigates search results with keyboard, getting back to the input when reaching the end of results", async function (assert) {
    await render(<template><AdminSearch /></template>);
    await fillIn(".admin-search__input-field", "site");
    assert.dom(".admin-search__results").exists();

    await triggerKeyEvent(".admin-search__input-field", "keydown", "ArrowDown");
    assert
      .dom(
        ".admin-search__result .admin-search__result-link[href='/admin/site_settings']"
      )
      .isFocused();
    await triggerKeyEvent(document.activeElement, "keydown", "ArrowDown");
    assert
      .dom(
        ".admin-search__result .admin-search__result-link[href='/admin/backups']"
      )
      .isFocused();
    await triggerKeyEvent(document.activeElement, "keydown", "ArrowUp");
    assert
      .dom(
        ".admin-search__result .admin-search__result-link[href='/admin/site_settings']"
      )
      .isFocused();
    await triggerKeyEvent(document.activeElement, "keydown", "ArrowUp");
    assert.dom(".admin-search__input-field").isFocused();
  });
});
