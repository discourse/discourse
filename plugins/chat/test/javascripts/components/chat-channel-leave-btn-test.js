import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { click, render } from "@ember/test-helpers";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import pretender from "discourse/tests/helpers/create-pretender";
import I18n from "I18n";
import { module, test } from "qunit";
import fabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module("Discourse Chat | Component | chat-channel-leave-btn", function (hooks) {
  setupRenderingTest(hooks);

  test("accepts an optional onLeaveChannel callback", async function (assert) {
    this.foo = 1;
    this.onLeaveChannel = () => (this.foo = 2);
    this.channel = fabricators.directMessageChannel();

    await render(
      hbs`<ChatChannelLeaveBtn @channel={{this.channel}} @onLeaveChannel={{this.onLeaveChannel}} />`
    );

    pretender.post("/chat/chat_channels/:chatChannelId/unfollow", () => {
      return [200, { current_user_membership: { following: false } }, {}];
    });
    assert.strictEqual(this.foo, 1);

    await click(".chat-channel-leave-btn");
    assert.strictEqual(this.foo, 2);
  });

  test("has a specific title for direct message channel", async function (assert) {
    this.channel = fabricators.directMessageChannel();

    await render(hbs`<ChatChannelLeaveBtn @channel={{this.channel}} />`);

    const btn = query(".chat-channel-leave-btn");
    assert.strictEqual(btn.title, I18n.t("chat.direct_messages.leave"));
  });

  test("has a specific title for message channel", async function (assert) {
    this.channel = fabricators.channel();

    await render(hbs`<ChatChannelLeaveBtn @channel={{this.channel}} />`);

    const btn = query(".chat-channel-leave-btn");
    assert.strictEqual(btn.title, I18n.t("chat.leave"));
  });

  test("is not visible on mobile", async function (assert) {
    this.site.mobileView = true;
    this.channel = fabricators.channel();

    await render(hbs`<ChatChannelLeaveBtn @channel={{this.channel}} />`);

    assert.false(exists(".chat-channel-leave-btn"));
  });
});
