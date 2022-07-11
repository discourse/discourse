import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";

module("Integration | Component | user-info", function (hooks) {
  setupRenderingTest(hooks);

  test("prioritized name", async function (assert) {
    this.siteSettings.prioritize_username_in_ux = false;
    this.currentUser.name = "Evil Trout";

    await render(hbs`<UserInfo @user={{this.currentUser}} />`);

    assert.strictEqual(query(".name.bold").innerText.trim(), "Evil Trout");
    assert.strictEqual(query(".username.margin").innerText.trim(), "eviltrout");
  });

  test("prioritized username", async function (assert) {
    this.siteSettings.prioritize_username_in_ux = true;
    this.currentUser.name = "Evil Trout";

    await render(hbs`<UserInfo @user={{this.currentUser}} />`);

    assert.strictEqual(query(".username.bold").innerText.trim(), "eviltrout");
    assert.strictEqual(query(".name.margin").innerText.trim(), "Evil Trout");
  });

  test("includeLink", async function (assert) {
    await render(
      hbs`<UserInfo @user={{this.currentUser}} @includeLink={{this.includeLink}} />`
    );

    this.set("includeLink", true);
    assert.ok(exists(`.username a[href="/u/${this.currentUser.username}"]`));

    this.set("includeLink", false);
    assert.notOk(exists(`.username a[href="/u/${this.currentUser.username}"]`));
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
});
