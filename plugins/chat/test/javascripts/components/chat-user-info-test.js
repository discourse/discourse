import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { exists } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import { render } from "@ember/test-helpers";

module("Discourse Chat | Component | chat-user-info", function (hooks) {
  setupRenderingTest(hooks);

  test("avatar and name", async function (assert) {
    this.set("user", this.currentUser);

    await render(hbs`<ChatUserInfo @user={{this.user}} />`);

    assert.true(
      exists(`a[data-user-card=${this.user.username}] div.chat-user-avatar`)
    );

    assert.true(
      exists(
        `a[data-user-card=${this.user.username}] span.chat-user-display-name`
      )
    );
  });
});
