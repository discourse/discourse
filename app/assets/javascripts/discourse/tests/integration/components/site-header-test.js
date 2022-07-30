import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { click, render, waitUntil } from "@ember/test-helpers";
import { count, exists, query } from "discourse/tests/helpers/qunit-helpers";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { hbs } from "ember-cli-htmlbars";

module("Integration | Component | site-header", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.currentUser.set("unread_high_priority_notifications", 1);
    this.currentUser.set("read_first_notification", false);
  });

  test("first notification mask", async function (assert) {
    await render(hbs`<SiteHeader />`);

    assert.strictEqual(
      count(".ring-backdrop"),
      1,
      "there is the first notification mask"
    );

    // Click anywhere
    await click("header.d-header");

    assert.ok(
      !exists(".ring-backdrop"),
      "it hides the first notification mask"
    );
  });

  test("do not call authenticated endpoints as anonymous", async function (assert) {
    this.owner.unregister("service:current-user");

    await render(hbs`<SiteHeader />`);

    assert.ok(
      !exists(".ring-backdrop"),
      "there is no first notification mask for anonymous users"
    );

    pretender.get("/notifications", () => {
      assert.ok(false, "it should not try to refresh notifications");
      return response(403, {});
    });

    // Click anywhere
    await click("header.d-header");
  });

  test("user avatar is highlighted when the user receives the first notification", async function (assert) {
    this.currentUser.set("all_unread_notifications", 1);
    this.currentUser.set("redesigned_user_menu_enabled", true);
    this.currentUser.set("read_first_notification", false);
    await render(hbs`<SiteHeader />`);
    assert.ok(exists(".ring-first-notification"));
  });

  test("user avatar is not highlighted when the user receives notifications beyond the first one", async function (assert) {
    this.currentUser.set("redesigned_user_menu_enabled", true);
    this.currentUser.set("all_unread_notifications", 1);
    this.currentUser.set("read_first_notification", true);
    await render(hbs`<SiteHeader />`);
    assert.ok(!exists(".ring-first-notification"));
  });

  test("hamburger menu icon shows pending reviewables count", async function (assert) {
    this.currentUser.set("reviewable_count", 1);
    await render(hbs`<SiteHeader />`);
    let pendingReviewablesBadge = query(
      ".hamburger-dropdown .badge-notification"
    );
    assert.strictEqual(pendingReviewablesBadge.textContent, "1");
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
});
