import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ChatUserInfo from "discourse/plugins/chat/discourse/components/chat-user-info";

module("Discourse Chat | Component | chat-user-info", function (hooks) {
  setupRenderingTest(hooks);

  test("avatar and name", async function (assert) {
    const self = this;

    this.set("user", this.currentUser);

    await render(<template><ChatUserInfo @user={{self.user}} /></template>);

    assert.dom().containsText(this.user.username);
    assert.dom().containsText(this.user.name);
  });

  test("status message", async function (assert) {
    const self = this;

    this.siteSettings.enable_user_status = true;

    this.set("user", this.currentUser);

    this.user.setProperties({
      status: { description: "happy", emoji: "smile" },
    });

    await render(
      <template>
        <ChatUserInfo
          @user={{self.user}}
          @showStatus={{true}}
          @showStatusDescription={{true}}
        />
      </template>
    );

    assert.dom("img.emoji[alt='smile']").exists("it shows the emoji");
    assert.dom().containsText("happy");
  });
});
