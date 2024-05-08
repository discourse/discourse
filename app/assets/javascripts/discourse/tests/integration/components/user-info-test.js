import { render, triggerEvent } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";

module("Integration | Component | user-info", function (hooks) {
  setupRenderingTest(hooks);

  test("prioritized name", async function (assert) {
    this.siteSettings.prioritize_username_in_ux = false;
    this.currentUser.name = "Evil Trout";

    await render(hbs`<UserInfo @user={{this.currentUser}} />`);

    assert.strictEqual(query(".name").innerText.trim(), "Evil Trout");
    assert.strictEqual(query(".username").innerText.trim(), "eviltrout");
  });

  test("prioritized username", async function (assert) {
    this.siteSettings.prioritize_username_in_ux = true;
    this.currentUser.name = "Evil Trout";

    await render(hbs`<UserInfo @user={{this.currentUser}} />`);

    assert.strictEqual(query(".username").innerText.trim(), "eviltrout");
    assert.strictEqual(query(".name").innerText.trim(), "Evil Trout");
  });

  test("includeLink", async function (assert) {
    await render(
      hbs`<UserInfo @user={{this.currentUser}} @includeLink={{this.includeLink}} />`
    );

    this.set("includeLink", true);
    assert.ok(exists(`.name-line a[href="/u/${this.currentUser.username}"]`));

    this.set("includeLink", false);
    assert.notOk(
      exists(`.name-line a[href="/u/${this.currentUser.username}"]`)
    );
  });

  test("includeAvatar", async function (assert) {
    await render(
      hbs`<UserInfo @user={{this.currentUser}} @includeAvatar={{this.includeAvatar}} />`
    );

    this.set("includeAvatar", true);
    assert.ok(exists(".user-image"));

    this.set("includeAvatar", false);
    assert.notOk(exists(".user-image"));
  });

  test("shows status if enabled and user has status", async function (assert) {
    this.currentUser.name = "Evil Trout";
    this.currentUser.status = { emoji: "tooth", description: "off to dentist" };

    await render(
      hbs`<UserInfo @user={{this.currentUser}} @showStatus={{true}} />`
    );

    assert.ok(exists(".user-status-message"));
  });

  test("doesn't show status if enabled but user doesn't have status", async function (assert) {
    this.currentUser.name = "Evil Trout";

    await render(
      hbs`<UserInfo @user={{this.currentUser}} @showStatus={{true}} />`
    );

    assert.notOk(exists(".user-status-message"));
  });

  test("doesn't show status if disabled", async function (assert) {
    this.currentUser.name = "Evil Trout";
    this.currentUser.status = { emoji: "tooth", description: "off to dentist" };

    await render(
      hbs`<UserInfo @user={{this.currentUser}} @showStatus={{false}} />`
    );

    assert.notOk(exists(".user-status-message"));
  });

  test("doesn't show status by default", async function (assert) {
    this.currentUser.name = "Evil Trout";
    this.currentUser.status = { emoji: "tooth", description: "off to dentist" };

    await render(hbs`<UserInfo @user={{this.currentUser}} />`);

    assert.notOk(exists(".user-status-message"));
  });

  test("doesn't show status description by default", async function (assert) {
    this.currentUser.name = "Evil Trout";
    this.currentUser.status = { emoji: "tooth", description: "off to dentist" };

    await render(
      hbs`<UserInfo @user={{this.currentUser}} @showStatus={{true}} />`
    );

    assert
      .dom(".user-status-message .user-status-message-description")
      .doesNotExist();
  });

  test("shows status description if enabled", async function (assert) {
    this.currentUser.name = "Evil Trout";
    this.currentUser.status = { emoji: "tooth", description: "off to dentist" };

    await render(
      hbs`<UserInfo @user={{this.currentUser}} @showStatus={{true}} @showStatusDescription={{true}} />`
    );

    assert
      .dom(".user-status-message .user-status-message-description")
      .exists();
  });

  test("shows status tooltip if enabled", async function (assert) {
    this.currentUser.name = "Evil Trout";
    this.currentUser.status = { emoji: "tooth", description: "off to dentist" };

    await render(
      hbs`<UserInfo @user={{this.currentUser}} @showStatus={{true}}  /><DTooltips />`
    );
    await triggerEvent(query(".user-status-message"), "mousemove");

    assert
      .dom("[data-content][data-identifier='user-status-message-tooltip']")
      .exists();
  });
});
