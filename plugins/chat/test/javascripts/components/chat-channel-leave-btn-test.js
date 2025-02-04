import { getOwner } from "@ember/owner";
import { click, render } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender from "discourse/tests/helpers/create-pretender";
import { i18n } from "discourse-i18n";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module("Discourse Chat | Component | chat-channel-leave-btn", function (hooks) {
  setupRenderingTest(hooks);

  test("accepts an optional onLeaveChannel callback", async function (assert) {
    this.foo = 1;
    this.onLeaveChannel = () => (this.foo = 2);
    this.channel = new ChatFabricators(getOwner(this)).directMessageChannel();

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
    this.channel = new ChatFabricators(getOwner(this)).directMessageChannel();

    await render(hbs`<ChatChannelLeaveBtn @channel={{this.channel}} />`);

    assert
      .dom(".chat-channel-leave-btn")
      .hasAttribute("title", i18n("chat.direct_messages.leave"));
  });

  test("has a specific title for message channel", async function (assert) {
    this.channel = new ChatFabricators(getOwner(this)).channel();

    await render(hbs`<ChatChannelLeaveBtn @channel={{this.channel}} />`);

    assert
      .dom(".chat-channel-leave-btn")
      .hasAttribute("title", i18n("chat.leave"));
  });

  test("is not visible on mobile", async function (assert) {
    this.site.desktopView = false;
    this.channel = new ChatFabricators(getOwner(this)).channel();

    await render(hbs`<ChatChannelLeaveBtn @channel={{this.channel}} />`);

    assert.dom(".chat-channel-leave-btn").doesNotExist();
  });
});
