import { click, find, findAll, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import MobileTabBar from "discourse/components/mobile-tab-bar";
import MobileTabBarViews from "discourse/components/mobile-tab-bar/views";
import { forceMobile } from "discourse/lib/mobile";
import { withPluginApi } from "discourse/lib/plugin-api";
import {
  SCROLLED_DOWN,
  SCROLLED_UP,
} from "discourse/services/scroll-direction";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dScrollEdges from "discourse/ui-kit/modifiers/d-scroll-edges";
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

  module("in Discourse Hub", function (hubHooks) {
    hubHooks.beforeEach(function () {
      sinon
        .stub(this.owner.lookup("service:capabilities"), "isAppWebview")
        .value(true);
      ["one", "two"].forEach((key) => addTabPanel(key));
    });

    test("keeps Eject last when all four tabs fit", async function (assert) {
      await render(<template><MobileTabBar /></template>);

      assert.deepEqual(
        tabKeys(),
        ["main", "one", "two", "hub"],
        "all tabs fit with Eject last"
      );
      assert
        .dom("[data-key='hub'] .d-icon-eject")
        .exists("the final tab returns to Hub");
    });

    test("keeps Eject immediately after More when sections overflow", async function (assert) {
      addTabPanel("three");
      this.currentUser.set("can_create_topic", true);

      await render(<template><MobileTabBar /></template>);

      assert.deepEqual(
        tabKeys(),
        ["main", "one", "more", "hub"],
        "More precedes Eject"
      );
      assert
        .dom(".mobile-tab-bar__tabs + .mobile-tab-bar__create")
        .exists("Create follows the navigation tabs");
      await click(".mobile-tab-bar__more");

      assert.deepEqual(
        findAll(".mobile-tab-bar__more-item").map((item) => item.dataset.key),
        ["two", "three"],
        "More lists the remaining sections"
      );
    });
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

  test("puts the views slot between the menu and create buttons when Topics is the only section", async function (assert) {
    const mobileTabBar = this.owner.lookup("service:mobile-tab-bar");
    this.currentUser.set("can_create_topic", true);

    await render(<template><MobileTabBar /></template>);

    assert
      .dom(
        ".mobile-tab-bar__menu + .mobile-tab-bar__views + .mobile-tab-bar__create"
      )
      .exists("the views sit between the two actions in keyboard order");
    assert
      .dom(".mobile-tab-bar__tabs")
      .doesNotExist("the Topics tab is redundant");
    assert
      .dom(".mobile-tab-bar__views > *")
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

  test("keeps the single row of topic views available while scrolling down", async function (assert) {
    this.currentUser.set("can_create_topic", true);
    this.owner.lookup("service:scroll-direction").lastScrollDirection =
      SCROLLED_DOWN;

    await render(
      <template>
        <MobileTabBar />
        <MobileTabBarViews>
          <ul class="nav-pills">
            <li><a href="/latest">Latest</a></li>
          </ul>
        </MobileTabBarViews>
      </template>
    );

    const views = find(".mobile-tab-bar__views");
    assert.strictEqual(
      getComputedStyle(find(".mobile-tab-bar__menu")).pointerEvents,
      "auto",
      "the menu stays available on lists"
    );
    assert.strictEqual(
      getComputedStyle(find(".mobile-tab-bar__create")).pointerEvents,
      "auto",
      "the create button stays available on lists"
    );
    assert.dom(views).isVisible("the views remain visible");
    assert.strictEqual(
      getComputedStyle(views).pointerEvents,
      "auto",
      "the views still accept taps"
    );
    assert.strictEqual(
      views.offsetHeight,
      find(".mobile-tab-bar__menu").offsetHeight,
      "the views and the menu share a height"
    );
  });

  test("tucks the side buttons while reading a topic and reveals them on scroll up", async function (assert) {
    this.currentUser.set("can_create_topic", true);
    sinon.stub(this.owner.lookup("service:router"), "currentRoute").value({
      name: "topic.show",
    });
    const scrollDirection = this.owner.lookup("service:scroll-direction");
    scrollDirection.lastScrollDirection = SCROLLED_DOWN;

    await render(
      <template>
        <MobileTabBar />
        <MobileTabBarViews>
          <button type="button">Timeline</button>
        </MobileTabBarViews>
      </template>
    );

    const menu = find(".mobile-tab-bar__menu");
    const create = find(".mobile-tab-bar__create");
    assert.strictEqual(
      getComputedStyle(menu).pointerEvents,
      "none",
      "the menu yields to the page"
    );
    assert.strictEqual(
      getComputedStyle(create).pointerEvents,
      "none",
      "the create button yields to the page"
    );
    assert.strictEqual(
      getComputedStyle(find(".mobile-tab-bar__views")).pointerEvents,
      "auto",
      "the timeline stays interactive"
    );

    scrollDirection.lastScrollDirection = SCROLLED_UP;
    await settled();

    assert.strictEqual(
      getComputedStyle(menu).pointerEvents,
      "auto",
      "the menu returns"
    );
    assert.strictEqual(
      getComputedStyle(create).pointerEvents,
      "auto",
      "the create button returns"
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
  test("highlights the active view in an overflowing RTL strip", async function (assert) {
    await render(
      <template>
        <MobileTabBar />
        <MobileTabBarViews>
          <ul
            class="nav-pills"
            dir="rtl"
            style="width: 160px; flex: none; padding: 0; --d-sys-color-background-default-selected: rgb(240, 240, 240);"
            {{dScrollEdges}}
          >
            <li><a class="active" href="/latest">Latest topics</a></li>
            <li><a href="/top">Top topics</a></li>
            <li><a href="/categories">Categories</a></li>
          </ul>
        </MobileTabBarViews>
      </template>
    );

    assert.notStrictEqual(
      getComputedStyle(find(".nav-pills a.active")).backgroundColor,
      getComputedStyle(find(".nav-pills a:not(.active)")).backgroundColor,
      "the active view has its own background in RTL"
    );
  });
});
