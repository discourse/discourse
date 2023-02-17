import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import { render } from "@ember/test-helpers";

module("Discourse Chat | Component | chat-user-info", function (hooks) {
  setupRenderingTest(hooks);

  test("avatar and name", async function (assert) {
    this.set("user", this.currentUser);

    await render(hbs`<ChatUserInfo @user={{this.user}} />`);

    assert
      .dom(`a[data-user-card=${this.user.username}] div.chat-user-avatar`)
      .exists();

    assert
      .dom(
        `a[data-user-card=${this.user.username}] span.chat-user-display-name`
      )
      .includesText(this.user.username);
  });
});
