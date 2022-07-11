import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { click, render } from "@ember/test-helpers";
import { count, exists } from "discourse/tests/helpers/qunit-helpers";
import pretender from "discourse/tests/helpers/create-pretender";
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
    this.owner.unregister("current-user:main");

    await render(hbs`<SiteHeader />`);

    assert.ok(
      !exists(".ring-backdrop"),
      "there is no first notification mask for anonymous users"
    );

    pretender.get("/notifications", () => {
      assert.ok(false, "it should not try to refresh notifications");
      return [403, { "Content-Type": "application/json" }, {}];
    });

    // Click anywhere
    await click("header.d-header");
  });
});
