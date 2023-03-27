import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  click,
  render,
  settled,
  triggerKeyEvent,
  waitUntil,
} from "@ember/test-helpers";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";
import I18n from "I18n";

module("Integration | Component | site-header", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.currentUser.set("unread_high_priority_notifications", 1);
    this.currentUser.set("read_first_notification", false);
  });

  test("unread notifications count rerenders when user's notifications count is updated", async function (assert) {
    this.currentUser.set("all_unread_notifications_count", 1);
    this.currentUser.set("redesigned_user_menu_enabled", true);

    await render(hbs`<SiteHeader />`);
    let unreadBadge = query(
      ".header-dropdown-toggle.current-user .unread-notifications"
    );
    assert.strictEqual(unreadBadge.textContent, "1");

    this.currentUser.set("all_unread_notifications_count", 5);
    await settled();

    unreadBadge = query(
      ".header-dropdown-toggle.current-user .unread-notifications"
    );
    assert.strictEqual(unreadBadge.textContent, "5");
  });

  test("hamburger menu icon shows pending reviewables count", async function (assert) {
    this.siteSettings.navigation_menu = "legacy";
    this.currentUser.set("reviewable_count", 1);
    await render(hbs`<SiteHeader />`);
    let pendingReviewablesBadge = query(
      ".hamburger-dropdown .badge-notification"
    );
    assert.strictEqual(pendingReviewablesBadge.textContent, "1");
  });

  test("hamburger menu icon doesn't show pending reviewables count for non-legacy navigation menu", async function (assert) {
    this.currentUser.set("reviewable_count", 1);
    this.siteSettings.navigation_menu = "sidebar";
    await render(hbs`<SiteHeader />`);
    assert.ok(!exists(".hamburger-dropdown .badge-notification"));
  });

  test("clicking outside the revamped menu closes it", async function (assert) {
    this.currentUser.set("redesigned_user_menu_enabled", true);
    await render(hbs`<SiteHeader />`);
    await click(".header-dropdown-toggle.current-user");
    assert.ok(exists(".user-menu.revamped"));
    await click("header.d-header");
    assert.ok(!exists(".user-menu.revamped"));
  });

  test("header's height is setting css property", async function (assert) {
    await render(hbs`<SiteHeader />`);

    function getProperty() {
      return getComputedStyle(document.body).getPropertyValue(
        "--header-offset"
      );
    }

    document.querySelector(".d-header").style.height = 90 + "px";
    await waitUntil(() => getProperty() === "90px", { timeout: 100 });
    assert.strictEqual(getProperty(), "90px");

    document.querySelector(".d-header").style.height = 60 + "px";
    await waitUntil(() => getProperty() === "60px", { timeout: 100 });
    assert.strictEqual(getProperty(), "60px");
  });

  test("arrow up/down keys move focus between the tabs", async function (assert) {
    this.currentUser.set("redesigned_user_menu_enabled", true);
    this.currentUser.set("can_send_private_messages", true);
    await render(hbs`<SiteHeader />`);
    await click(".header-dropdown-toggle.current-user");
    let activeTab = query(".menu-tabs-container .btn.active");
    assert.strictEqual(activeTab.id, "user-menu-button-all-notifications");

    await triggerKeyEvent(document, "keydown", "ArrowDown");
    let focusedTab = document.activeElement;
    assert.strictEqual(
      focusedTab.id,
      "user-menu-button-replies",
      "pressing the down arrow key moves focus to the next tab towards the bottom"
    );

    await triggerKeyEvent(document, "keydown", "ArrowDown");
    await triggerKeyEvent(document, "keydown", "ArrowDown");
    await triggerKeyEvent(document, "keydown", "ArrowDown");
    await triggerKeyEvent(document, "keydown", "ArrowDown");
    await triggerKeyEvent(document, "keydown", "ArrowDown");

    focusedTab = document.activeElement;
    assert.strictEqual(
      focusedTab.id,
      "user-menu-button-profile",
      "the down arrow key can move the focus to the bottom tabs"
    );

    await triggerKeyEvent(document, "keydown", "ArrowDown");
    focusedTab = document.activeElement;
    assert.strictEqual(
      focusedTab.id,
      "user-menu-button-all-notifications",
      "the focus moves back to the top after reaching the bottom"
    );

    await triggerKeyEvent(document, "keydown", "ArrowUp");
    focusedTab = document.activeElement;
    assert.strictEqual(
      focusedTab.id,
      "user-menu-button-profile",
      "the up arrow key moves the focus in the opposite direction"
    );
  });

  test("new personal messages bubble is prioritized over unseen reviewables and regular notifications bubbles", async function (assert) {
    this.currentUser.set("redesigned_user_menu_enabled", true);
    this.currentUser.set("all_unread_notifications_count", 5);
    this.currentUser.set("new_personal_messages_notifications_count", 2);
    this.currentUser.set("unseen_reviewable_count", 3);

    await render(hbs`<SiteHeader />`);

    assert.notOk(
      exists(
        ".header-dropdown-toggle.current-user .badge-notification.unread-notifications"
      ),
      "regular notifications bubble isn't displayed when there are new personal messages notifications"
    );

    assert.notOk(
      exists(
        ".header-dropdown-toggle.current-user .badge-notification.with-icon.new-reviewables"
      ),
      "reviewables bubble isn't displayed when there are new personal messages notifications"
    );

    const pmsBubble = query(
      ".header-dropdown-toggle.current-user .badge-notification.with-icon.new-pms"
    );
    assert.strictEqual(
      pmsBubble.textContent.trim(),
      "",
      "personal messages bubble has no count"
    );
    assert.ok(
      pmsBubble.querySelector(".d-icon-envelope"),
      "personal messages bubble has envelope icon"
    );
    assert.strictEqual(
      pmsBubble.title,
      I18n.t("notifications.tooltip.new_message_notification", { count: 2 }),
      "personal messages bubble bubble has a title"
    );
  });

  test("unseen reviewables bubble is prioritized over regular notifications", async function (assert) {
    this.currentUser.set("redesigned_user_menu_enabled", true);
    this.currentUser.set("all_unread_notifications_count", 5);
    this.currentUser.set("new_personal_messages_notifications_count", 0);
    this.currentUser.set("unseen_reviewable_count", 3);
    await render(hbs`<SiteHeader />`);

    assert.notOk(
      exists(
        ".header-dropdown-toggle.current-user .badge-notification.unread-notifications"
      ),
      "regular notifications bubble isn't displayed when there are unseen reviewables notifications"
    );

    const reviewablesBubble = query(
      ".header-dropdown-toggle.current-user .badge-notification.with-icon.new-reviewables"
    );
    assert.strictEqual(
      reviewablesBubble.textContent.trim(),
      "",
      "reviewables bubble has no count"
    );
    assert.ok(
      reviewablesBubble.querySelector(".d-icon-flag"),
      "reviewables bubble has flag icon"
    );
    assert.strictEqual(
      reviewablesBubble.title,
      I18n.t("notifications.tooltip.new_reviewable", { count: 3 }),
      "reviewables bubble has a title"
    );

    assert.notOk(
      exists(
        ".header-dropdown-toggle.current-user .badge-notification.with-icon.new-pms"
      ),
      "personal messages bubble isn't displayed"
    );
  });

  test("regular notifications bubble is shown if there are neither new personal messages nor unseen reviewables", async function (assert) {
    this.currentUser.set("redesigned_user_menu_enabled", true);
    this.currentUser.set("all_unread_notifications_count", 5);
    this.currentUser.set("new_personal_messages_notifications_count", 0);
    this.currentUser.set("unseen_reviewable_count", 0);
    await render(hbs`<SiteHeader />`);

    const regularNotificationsBubble = query(
      ".header-dropdown-toggle.current-user .badge-notification.unread-notifications"
    );
    assert.strictEqual(
      regularNotificationsBubble.textContent,
      "5",
      "regular notifications bubble has a count"
    );
    assert.strictEqual(
      regularNotificationsBubble.title,
      I18n.t("notifications.tooltip.regular", { count: 5 }),
      "regular notifications bubble has a title"
    );

    assert.notOk(
      exists(
        ".header-dropdown-toggle.current-user .badge-notification.with-icon.new-reviewables"
      ),
      "reviewables bubble isn't displayed"
    );

    assert.notOk(
      exists(
        ".header-dropdown-toggle.current-user .badge-notification.with-icon.new-pms"
      ),
      "personal messages bubble isn't displayed"
    );
  });
});
