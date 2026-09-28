import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import MobileTabBar from "discourse/components/mobile-tab-bar";
import { forceMobile } from "discourse/lib/mobile";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

function addTabPanel(panelKey, { primary = false } = {}) {
  withPluginApi((api) => {
    api.addSidebarPanel(
      (BaseCustomSidebarPanel) =>
        class extends BaseCustomSidebarPanel {
          key = panelKey;
          hidden = true;

          get mobileTab() {
            return { label: panelKey, icon: "star", url: "/", primary };
          }
        }
    );
  });
}

module("Integration | Component | mobile-tab-bar", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    forceMobile();
    this.siteSettings.enable_mobile_tab_bar = true;
    this.siteSettings.sidebar_user_navigation = true;
  });

  test("holds the tabs that don't fit in a More menu", async function (assert) {
    ["one", "two", "three", "four"].forEach(addTabPanel);

    await render(<template><MobileTabBar /></template>);

    assert.dom(".mobile-tab-bar__tab").exists({ count: 5 });
    assert
      .dom(".mobile-tab-bar__tab:last-child")
      .hasAttribute("data-key", "more", "More takes the last slot");

    await click(".mobile-tab-bar__tab[data-key='more']");

    assert.dom(".mobile-tab-bar__held-tab[data-key='three']").exists();
    assert.dom(".mobile-tab-bar__held-tab[data-key='four']").exists();
    assert.dom(".mobile-tab-bar__held-tab[data-key='two']").doesNotExist();
  });

  test("keeps primary tabs and search in the leading slots", async function (assert) {
    ["one", "two", "three"].forEach((key) => addTabPanel(key));
    addTabPanel("primary", { primary: true });

    await render(<template><MobileTabBar /></template>);

    const keys = [...document.querySelectorAll(".mobile-tab-bar__tab")].map(
      (tab) => tab.dataset.key
    );

    assert.deepEqual(keys, ["main", "primary", "search", "one", "more"]);
  });

  test("shows the tab's badge over its icon", async function (assert) {
    this.currentUser.set("reviewable_count", 3);
    this.currentUser.set("admin", true);
    addTabPanel("one");

    await render(<template><MobileTabBar /></template>);

    assert
      .dom(".mobile-tab-bar__tab[data-key='admin'] .mobile-tab-bar__count")
      .hasText("3");
  });
});
