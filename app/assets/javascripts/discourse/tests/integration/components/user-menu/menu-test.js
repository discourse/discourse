import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { query, queryAll } from "discourse/tests/helpers/qunit-helpers";
import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";

module("Integration | Component | user-menu", function (hooks) {
  setupRenderingTest(hooks);

  const template = hbs`<UserMenu::Menu/>`;

  test("notifications panel has a11y attributes", async function (assert) {
    await render(template);
    const panel = query("#quick-access-all-notifications");
    assert.strictEqual(panel.getAttribute("tabindex"), "-1");
    assert.strictEqual(
      panel.getAttribute("aria-labelledby"),
      "user-menu-button-all-notifications"
    );
  });

  test("active tab has a11y attributes that indicate it's active", async function (assert) {
    await render(template);
    const activeTab = query(".top-tabs.tabs-list .btn.active");
    assert.strictEqual(activeTab.getAttribute("tabindex"), "0");
    assert.strictEqual(activeTab.getAttribute("aria-selected"), "true");
  });

  test("the menu has a group of tabs at the top", async function (assert) {
    await render(template);
    const tabs = queryAll(".top-tabs.tabs-list .btn");
    assert.strictEqual(tabs.length, 1);
    ["all-notifications"].forEach((tab, index) => {
      assert.strictEqual(tabs[index].id, `user-menu-button-${tab}`);
      assert.strictEqual(
        tabs[index].getAttribute("data-tab-number"),
        index.toString()
      );
      assert.strictEqual(
        tabs[index].getAttribute("aria-controls"),
        `quick-access-${tab}`
      );
    });
  });

  test("the menu has a group of tabs at the bottom", async function (assert) {
    await render(template);
    const tabs = queryAll(".bottom-tabs.tabs-list .btn");
    assert.strictEqual(tabs.length, 1);
    const preferencesTab = tabs[0];
    assert.ok(preferencesTab.href.endsWith("/u/eviltrout/preferences"));
    assert.strictEqual(preferencesTab.getAttribute("data-tab-number"), "1");
    assert.strictEqual(preferencesTab.getAttribute("tabindex"), "-1");
  });
});
