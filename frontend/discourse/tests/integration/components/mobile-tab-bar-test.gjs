import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import MobileTabBar from "discourse/components/mobile-tab-bar";
import { forceMobile } from "discourse/lib/mobile";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

function addTabPanel(panelKey, { primary = false, createActions } = {}) {
  withPluginApi((api) => {
    api.addSidebarPanel(
      (BaseCustomSidebarPanel) =>
        class extends BaseCustomSidebarPanel {
          key = panelKey;
          hidden = true;

          get mobileTab() {
            return {
              label: panelKey,
              icon: "star",
              url: "/",
              primary,
              createActions,
            };
          }
        }
    );
  });
}

const tabKeys = () =>
  [
    ...document.querySelectorAll(".mobile-tab-bar__tabs .mobile-tab-bar__tab"),
  ].map((tab) => tab.dataset.key);

module("Integration | Component | mobile-tab-bar", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    forceMobile();
    this.siteSettings.enable_mobile_tab_bar = true;
    this.siteSettings.sidebar_user_navigation = true;
    this.currentUser.set("admin", false);
  });

  test("keeps every section in the bar, which scrolls when they don't fit", async function (assert) {
    ["one", "two", "three", "four"].forEach((key) => addTabPanel(key));

    await render(<template><MobileTabBar /></template>);

    assert.deepEqual(tabKeys(), ["main", "one", "two", "three", "four"]);
    assert.dom(".mobile-tab-bar__tab[data-key='more']").doesNotExist();
  });

  test("leads with primary tabs, between the menu and create buttons", async function (assert) {
    this.currentUser.set("can_create_topic", true);
    ["one", "two", "three"].forEach((key) => addTabPanel(key));
    addTabPanel("primary", { primary: true });

    await render(<template><MobileTabBar /></template>);

    assert.deepEqual(tabKeys(), ["main", "primary", "one", "two", "three"]);
    assert
      .dom(".mobile-tab-bar > :first-child")
      .hasClass("mobile-tab-bar__menu", "the menu button leads the bar");
    assert
      .dom(".mobile-tab-bar > :last-child")
      .hasClass("mobile-tab-bar__create", "the create button ends the bar");
  });

  test("offers every section's create actions, the current section's first", async function (assert) {
    this.currentUser.setProperties({
      can_create_topic: true,
      can_send_private_messages: false,
    });
    let created;
    addTabPanel("docs", {
      createActions: [
        { label: "New doc", icon: "file", action: () => (created = "doc") },
      ],
    });

    await render(<template><MobileTabBar /></template>);
    await click(".mobile-tab-bar__create");

    const buttons = [
      ...document.querySelectorAll(".mobile-tab-bar__create-action"),
    ];

    assert.deepEqual(
      buttons.map((button) => button.textContent.trim()),
      ["New topic", "New doc"]
    );

    await click(buttons.at(-1));

    assert.strictEqual(created, "doc");
  });

  test("runs the only create action without a menu", async function (assert) {
    this.currentUser.setProperties({
      can_create_topic: false,
      can_send_private_messages: true,
    });

    await render(<template><MobileTabBar /></template>);

    assert
      .dom(".mobile-tab-bar__create")
      .hasAttribute("aria-label", "New personal message");
  });

  test("opens the forum's menu from the menu button, wherever the user is", async function (assert) {
    addTabPanel("one");
    const mobileTabBar = this.owner.lookup("service:mobile-tab-bar");
    mobileTabBar.sectionTabKey = "one";

    await render(<template><MobileTabBar /></template>);
    await click(".mobile-tab-bar__menu");

    assert.true(this.owner.lookup("service:header").hamburgerVisible);
    assert.strictEqual(
      this.owner.lookup("service:sidebar-state").currentPanel.key,
      "main"
    );
    assert.dom(".mobile-tab-bar__menu").hasAria("expanded", "true");

    await click(".mobile-tab-bar__menu");

    assert.false(this.owner.lookup("service:header").hamburgerVisible);
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
