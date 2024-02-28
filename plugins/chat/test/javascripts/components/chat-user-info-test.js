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
    this.siteSettings.enable_user_status = true;

    this.set("user", this.currentUser);

    this.user.setProperties({
      status: { description: "happy", emoji: "smile" },
    });

    await render(
      hbs`<ChatUserInfo @user={{this.user}} @showStatus={{true}} @showStatusDescription={{true}} />`
    );

    assert.dom("img.emoji[alt='smile']").exists("it shows the emoji");
    assert.dom().containsText("happy");
  });
});
