import { fillIn, render, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import AdminSearch from "discourse/admin/components/admin-search";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | AdminSearch", function (hooks) {
  setupRenderingTest(hooks);

  test("shows search results", async function (assert) {
    await render(<template><AdminSearch /></template>);
    await fillIn(".admin-search__input-field", "title");

    assert.dom(".admin-search__results").exists();
    assert.dom(".admin-search__result").exists({ count: 1 });
  });

  test("navigates search results with keyboard, getting back to the input when reaching the end of results", async function (assert) {
    await render(<template><AdminSearch /></template>);

    await fillIn(".admin-search__input-field", "site");
    assert.dom(".admin-search__results").exists();

    await triggerKeyEvent(".admin-search__input-field", "keydown", "ArrowDown");
    assert
      .dom(".admin-search__result:nth-of-type(1) .admin-search__result-link")
      .isFocused();

    await triggerKeyEvent(document.activeElement, "keydown", "ArrowDown");
    assert
      .dom(".admin-search__result:nth-of-type(2) .admin-search__result-link")
      .isFocused();

    await triggerKeyEvent(document.activeElement, "keydown", "ArrowUp");
    assert
      .dom(".admin-search__result:nth-of-type(1) .admin-search__result-link")
      .isFocused();

    await triggerKeyEvent(document.activeElement, "keydown", "ArrowUp");
    assert.dom(".admin-search__input-field").isFocused();
  });
});
