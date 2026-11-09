import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import MobileTabBar from "discourse/components/mobile-tab-bar";
import { forceMobile } from "discourse/lib/mobile";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";

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
    this.siteSettings.mobile_footer_navigation = true;
    this.siteSettings.sidebar_user_navigation = true;
    this.currentUser.set("admin", false);
  });

  test("keeps up to four sections in the bar", async function (assert) {
    ["one", "two", "three"].forEach((key) => addTabPanel(key));

    await render(<template><MobileTabBar /></template>);

    assert.deepEqual(tabKeys(), ["main", "one", "two", "three"]);
    assert.dom(".mobile-tab-bar__more").doesNotExist();
  });

  test("gathers the sections past three under More when they don't fit", async function (assert) {
    ["one", "two", "three", "four"].forEach((key) => addTabPanel(key));

    await render(<template><MobileTabBar /></template>);

    assert.deepEqual(tabKeys(), ["main", "one", "two", "more"]);

    await click(".mobile-tab-bar__more");

    assert.deepEqual(
      [...document.querySelectorAll(".mobile-tab-bar__more-item")].map(
        (item) => item.dataset.key
      ),
      ["three", "four"]
    );
  });

  test("highlights More while one of its sections is current", async function (assert) {
    ["one", "two", "three", "four"].forEach((key) => addTabPanel(key));
    const mobileTabBar = this.owner.lookup("service:mobile-tab-bar");

    await render(<template><MobileTabBar /></template>);

    assert.dom(".mobile-tab-bar__more").doesNotHaveClass("--active");

    mobileTabBar.sectionTabKey = "four";
    await click(".mobile-tab-bar__more");

    assert.dom(".mobile-tab-bar__more").hasClass("--active");
    assert.dom(".mobile-tab-bar__more").hasAttribute("aria-current", "page");
    assert
      .dom(".mobile-tab-bar__more-item[data-key='four']")
      .hasClass("--active");
    assert
      .dom(".mobile-tab-bar__more-item[data-key='three']")
      .doesNotHaveClass("--active");
  });

  test("leads with primary tabs, between the menu and create buttons", async function (assert) {
    this.currentUser.set("can_create_topic", true);
    ["one", "two"].forEach((key) => addTabPanel(key));
    addTabPanel("primary", { primary: true });

    await render(<template><MobileTabBar /></template>);

    assert.deepEqual(tabKeys(), ["main", "primary", "one", "two"]);
    assert
      .dom(".mobile-tab-bar__controls > :first-child")
      .hasClass("mobile-tab-bar__menu", "the menu button leads the bar");
    assert
      .dom(".mobile-tab-bar__controls > :last-child")
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

  test("gives the current section a strip above the tabs for its views", async function (assert) {
    const mobileTabBar = this.owner.lookup("service:mobile-tab-bar");

    await render(<template><MobileTabBar /></template>);

    assert
      .dom(".mobile-tab-bar__views > :not(.mobile-tab-bar__views-highlight)")
      .doesNotExist("the strip waits for a section to fill it");
    assert
      .dom(".mobile-tab-bar__views")
      .isNotVisible("an empty strip stays out of the way");
    assert.strictEqual(
      mobileTabBar.viewsSlot,
      document.querySelector(".mobile-tab-bar__views"),
      "sections render into the strip through the service"
    );
  });

  test("shows the review count on the menu button for any reviewer", async function (assert) {
    this.currentUser.set("reviewable_count", 3);
    this.currentUser.set("admin", false);
    this.currentUser.set("moderator", false);
    addTabPanel("one");

    await render(<template><MobileTabBar /></template>);

    assert.dom(".mobile-tab-bar__menu .mobile-tab-bar__count").hasText("3");
    assert
      .dom(".mobile-tab-bar__menu")
      .hasAria(
        "label",
        i18n("mobile_tab_bar.menu_with_reviewables", { count: 3 }),
        "names the count, which the label would otherwise hide"
      );
  });

  test("leaves the review count off the admin tab", async function (assert) {
    this.currentUser.set("reviewable_count", 3);
    this.currentUser.set("admin", true);
    addTabPanel("one");

    await render(<template><MobileTabBar /></template>);

    assert
      .dom(".mobile-tab-bar__tab[data-key='admin'] .mobile-tab-bar__count")
      .doesNotExist();
  });

  test("leaves menu links outside the app to the menu", function (assert) {
    this.currentUser.set("admin", true);
    const mobileTabBar = this.owner.lookup("service:mobile-tab-bar");
    // Production builds return nothing for a URL outside the app, where
    // development ones assert
    sinon.stub(this.owner.lookup("service:router"), "recognize").returns(null);

    assert.false(
      mobileTabBar.leadsToSectionTab({
        href: "https://cdn.example.com/uploads/handbook.pdf",
      }),
      "a file isn't a section's page"
    );
  });
});
