import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import SidebarTabBar from "discourse/components/sidebar/tab-bar";
import { withPluginApi } from "discourse/lib/plugin-api";
import DiscourseURL from "discourse/lib/url";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

function addTabPanel(panelKey) {
  withPluginApi((api) => {
    api.addSidebarPanel(
      (BaseCustomSidebarPanel) =>
        class extends BaseCustomSidebarPanel {
          key = panelKey;
          hidden = true;

          get mobileTab() {
            return { label: panelKey, icon: "star", url: `/${panelKey}` };
          }
        }
    );
  });
}

module("Integration | Component | Sidebar | tab-bar", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.enable_sidebar_tab_bar = true;
  });

  test("leaves search out and folds extra panels into More", async function (assert) {
    ["one", "two", "three", "four", "five"].forEach(addTabPanel);

    await render(<template><SidebarTabBar /></template>);

    const keys = [...document.querySelectorAll(".mobile-tab-bar__tab")].map(
      (tab) => tab.dataset.key
    );

    assert.deepEqual(keys, ["main", "one", "two", "three", "more"]);
  });

  test("goes to the tab's section and shows its panel", async function (assert) {
    addTabPanel("one");
    const routeTo = sinon.stub(DiscourseURL, "routeTo");
    const sidebarState = this.owner.lookup("service:sidebar-state");

    await render(<template><SidebarTabBar /></template>);

    assert.dom(".mobile-tab-bar__tab[data-key='main']").hasClass("--active");

    await click(".mobile-tab-bar__tab[data-key='one']");

    assert.true(routeTo.calledWith("/one"));
    assert.strictEqual(sidebarState.currentPanelKey, "one");
    assert.dom(".mobile-tab-bar__tab[data-key='one']").hasClass("--active");
    assert.false(sidebarState.combinedMode, "panels stay separate");
  });

  test("gives way to the footer tab bar on mobile", async function (assert) {
    this.siteSettings.enable_mobile_tab_bar = true;
    this.site.mobileView = true;
    addTabPanel("one");

    await render(<template><SidebarTabBar /></template>);

    assert.dom(".mobile-tab-bar.--sidebar").doesNotExist();
  });
});
