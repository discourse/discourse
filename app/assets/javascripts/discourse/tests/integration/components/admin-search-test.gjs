import { click, fillIn, render, triggerKeyEvent } from "@ember/test-helpers";
import { module, skip, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import AdminSearch from "admin/components/admin-search";

function filterButtonCss(filterType) {
  return `.admin-search__filter.--${filterType} button`;
}

function assertFilterActive(assert, filterType, isActive = true) {
  if (isActive) {
    assert
      .dom(`${filterButtonCss(filterType)}.admin-search__filter-item.is-active`)
      .exists();
  } else {
    assert
      .dom(`${filterButtonCss(filterType)}.admin-search__filter-item.is-active`)
      .doesNotExist();
  }
}

module("Integration | Component | AdminSearch", function (hooks) {
  setupRenderingTest(hooks);

  test("remembers last toggled filters, and opens filter controls by default", async function (assert) {
    await render(<template><AdminSearch /></template>);

    assert.dom(".admin-search__filters").exists();
    assertFilterActive(assert, "page");
    assertFilterActive(assert, "setting");
    assertFilterActive(assert, "theme");
    assertFilterActive(assert, "component");
    assertFilterActive(assert, "report");

    await click(filterButtonCss("page"));
    await click(filterButtonCss("setting"));

    assertFilterActive(assert, "page", false);
    assertFilterActive(assert, "setting", false);

    await render(<template><AdminSearch /></template>);

    assertFilterActive(assert, "page", false);
    assertFilterActive(assert, "setting", false);
  });

  test("filters different types of search results", async function (assert) {
    await render(<template><AdminSearch /></template>);
    await fillIn(".admin-search__input-field", "title");

    assert.dom(".admin-search__results").exists();
    assert.dom(".admin-search__result").exists({ count: 1 });

    await click(filterButtonCss("setting"));
    assert.dom(".admin-search__result").doesNotExist();

    await fillIn(".admin-search__input-field", "admin logins");
    assert.dom(".admin-search__result").exists({ count: 1 });

    await click(filterButtonCss("report"));
    assert.dom(".admin-search__result").doesNotExist();
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
