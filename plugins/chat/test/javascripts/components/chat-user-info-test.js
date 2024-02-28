import { render } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Discourse Chat | Component | chat-user-info", function (hooks) {
  setupRenderingTest(hooks);

  test("avatar and name", async function (assert) {
    this.set("user", this.currentUser);

    await render(hbs`<ChatUserInfo @user={{this.user}} />`);

    assert.dom().containsText(this.user.username);
    assert.dom().containsText(this.user.name);
  });

  test("status message", async function (assert) {
    this.currentUser.userStatus = { emoji: "smile", description: "happy" };
    this.set("user", this.currentUser);

    await render(hbs`<ChatUserInfo @user={{this.user}} />`);

    assert.dom().containsText(this.user.userStatus.emoji);
    assert.dom().containsText(this.user.userStatus.description);
  });
});
