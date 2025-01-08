import { getOwner } from "@ember/owner";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { forceMobile } from "discourse/lib/mobile";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender from "discourse/tests/helpers/create-pretender";
import { i18n } from "discourse-i18n";
import ChatChannelLeaveBtn from "discourse/plugins/chat/discourse/components/chat-channel-leave-btn";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module("Discourse Chat | Component | chat-channel-leave-btn", function (hooks) {
  setupRenderingTest(hooks);

  test("accepts an optional onLeaveChannel callback", async function (assert) {
    const self = this;

    this.foo = 1;
    this.onLeaveChannel = () => (this.foo = 2);
    this.channel = new ChatFabricators(getOwner(this)).directMessageChannel();

    await render(
      <template>
        <ChatChannelLeaveBtn
          @channel={{self.channel}}
          @onLeaveChannel={{self.onLeaveChannel}}
        />
      </template>
    );

    pretender.post("/chat/chat_channels/:chatChannelId/unfollow", () => {
      return [200, { current_user_membership: { following: false } }, {}];
    });
    assert.strictEqual(this.foo, 1);

    await click(".chat-channel-leave-btn");
    assert.strictEqual(this.foo, 2);
  });

  test("has a specific title for direct message channel", async function (assert) {
    const self = this;

    this.channel = new ChatFabricators(getOwner(this)).directMessageChannel();

    await render(
      <template><ChatChannelLeaveBtn @channel={{self.channel}} /></template>
    );

    assert
      .dom(".chat-channel-leave-btn")
      .hasAttribute("title", i18n("chat.direct_messages.leave"));
  });

  test("has a specific title for message channel", async function (assert) {
    const self = this;

    this.channel = new ChatFabricators(getOwner(this)).channel();

    await render(
      <template><ChatChannelLeaveBtn @channel={{self.channel}} /></template>
    );

    assert
      .dom(".chat-channel-leave-btn")
      .hasAttribute("title", i18n("chat.leave"));
  });

  test("is not visible on mobile", async function (assert) {
    const self = this;

    forceMobile();
    this.channel = new ChatFabricators(getOwner(this)).channel();

    await render(
      <template><ChatChannelLeaveBtn @channel={{self.channel}} /></template>
    );

    assert.dom(".chat-channel-leave-btn").doesNotExist();
  });
});
