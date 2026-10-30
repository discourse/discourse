import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { MESSAGE_CONTEXT_THREAD } from "discourse/plugins/chat/discourse/components/chat-message";
import ChatMessageInReplyToIndicator from "discourse/plugins/chat/discourse/components/chat-message-in-reply-to-indicator";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import UserChatChannelMembership from "discourse/plugins/chat/discourse/models/user-chat-channel-membership";

module("Component | ChatMessageInReplyToIndicator", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.fabricators = new ChatFabricators(getOwner(this));
  });

  test("renders nothing without inReplyTo", async function (assert) {
    const message = this.fabricators.message();

    await render(
      <template>
        <ChatMessageInReplyToIndicator
          @context="channel"
          @message={{message}}
        />
      </template>
    );

    assert
      .dom(".chat-reply")
      .doesNotExist("no indicator when there is no reply target");
  });

  test("in thread context links to the replied-to message within the thread", async function (assert) {
    const channel = this.fabricators.channel();
    channel.threadingEnabled = true;
    channel.currentUserMembership = UserChatChannelMembership.create({
      following: true,
    });
    const thread = this.fabricators.thread({ channel });
    const inReplyTo = this.fabricators.message({ channel });
    const message = this.fabricators.message({ channel, thread, inReplyTo });

    await render(
      <template>
        <ChatMessageInReplyToIndicator
          @context={{MESSAGE_CONTEXT_THREAD}}
          @message={{message}}
        />
      </template>
    );

    assert
      .dom(".chat-reply.is-direct-reply")
      .exists("indicator renders in thread context")
      .hasAttribute(
        "href",
        `/chat/c/${channel.slugifiedTitle}/${channel.id}/t/${thread.id}/${inReplyTo.id}`,
        "links to the specific replied-to message within the thread"
      );
  });

  test("in channel context with threading links to the thread", async function (assert) {
    const channel = this.fabricators.channel();
    channel.threadingEnabled = true;
    channel.currentUserMembership = UserChatChannelMembership.create({
      following: true,
    });
    const thread = this.fabricators.thread({ channel });
    const inReplyTo = this.fabricators.message({ channel });
    const message = this.fabricators.message({ channel, thread, inReplyTo });

    await render(
      <template>
        <ChatMessageInReplyToIndicator
          @context="channel"
          @message={{message}}
        />
      </template>
    );

    assert
      .dom(".chat-reply.is-direct-reply")
      .exists("indicator renders in channel context")
      .hasAttribute(
        "href",
        `/chat/c/${channel.slugifiedTitle}/${channel.id}/t/${thread.id}`,
        "links to the thread rather than the specific message"
      );
  });

  test("in channel context without threading links to the replied-to message in the channel", async function (assert) {
    const channel = this.fabricators.channel();
    channel.threadingEnabled = false;
    const inReplyTo = this.fabricators.message({ channel });
    const message = this.fabricators.message({ channel, inReplyTo });

    await render(
      <template>
        <ChatMessageInReplyToIndicator
          @context="channel"
          @message={{message}}
        />
      </template>
    );

    assert
      .dom(".chat-reply.is-direct-reply")
      .exists("indicator renders without threading")
      .hasAttribute(
        "href",
        `/chat/c/${channel.slugifiedTitle}/${channel.id}/${inReplyTo.id}`,
        "links directly to the replied-to message in the channel"
      );
  });
});
