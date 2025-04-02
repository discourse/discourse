import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  joinChannel,
  leaveChannel,
} from "discourse/tests/helpers/presence-pretender";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

async function addUser(id, username, channelName = "/chat-reply/1") {
  await joinChannel(channelName, {
    id,
    avatar_template: "/images/avatar.png",
    username,
  });
}

async function removeUser(id, channelName = "/chat-reply/1") {
  await leaveChannel(channelName, {
    id,
  });
}

module(
  "Discourse Chat | Component | chat-replying-indicator",
  function (hooks) {
    setupRenderingTest(hooks);

    test("not displayed when no one is replying", async function (assert) {
      await render(
        hbs`<ChatReplyingIndicator @presenceChannelName="/chat-reply/1" />`
      );

      assert.dom(".chat-replying-indicator__text").doesNotExist();
    });

    test("working for thread", async function (assert) {
      await render(
        hbs`<ChatReplyingIndicator @presenceChannelName="/chat-reply/1/thread/1" />`
      );

      await addUser(1, "sam", "/chat-reply/1/thread/1");

      assert.dom(".chat-replying-indicator__text").hasText("sam is typing");
    });

    test("doesn’t leak in other indicators", async function (assert) {
      await render(
        hbs`
          <div class="channel"><ChatReplyingIndicator @presenceChannelName="/chat-reply/1" /></div>
          <div class="thread"><ChatReplyingIndicator @presenceChannelName="/chat-reply/1/thread/1" /></div>
        `
      );

      await addUser(1, "sam");

      assert
        .dom(".channel .chat-replying-indicator__text")
        .hasText("sam is typing");
      assert.dom(".thread .chat-replying-indicator__text").doesNotExist();

      await addUser(2, "mark", "/chat-reply/1/thread/1");
      await removeUser(1);

      assert.dom(".channel .chat-replying-indicator__text").doesNotExist();
      assert
        .dom(".thread .chat-replying-indicator__text")
        .hasText("mark is typing");
    });

    test("displays indicator when user is replying", async function (assert) {
      await render(
        hbs`<ChatReplyingIndicator @presenceChannelName="/chat-reply/1" />`
      );

      await addUser(1, "sam");

      assert.dom(".chat-replying-indicator__text").hasText("sam is typing");
    });

    test("displays indicator when 2 or 3 users are replying", async function (assert) {
      this.channel = new ChatFabricators(getOwner(this)).channel();

      await render(
        hbs`<ChatReplyingIndicator @presenceChannelName="/chat-reply/1" />`
      );

      await addUser(1, "sam");
      await addUser(2, "mark");

      assert
        .dom(".chat-replying-indicator__text")
        .hasText("sam and mark are typing");
    });

    test("displays indicator when 3 users are replying", async function (assert) {
      this.channel = new ChatFabricators(getOwner(this)).channel();

      await render(
        hbs`<ChatReplyingIndicator @presenceChannelName="/chat-reply/1" />`
      );

      await addUser(1, "sam");
      await addUser(2, "mark");
      await addUser(3, "joffrey");

      assert
        .dom(".chat-replying-indicator__text")
        .hasText("sam, mark and joffrey are typing");
    });

    test("displays indicator when more than 3 users are replying", async function (assert) {
      this.channel = new ChatFabricators(getOwner(this)).channel();

      await render(
        hbs`<ChatReplyingIndicator  @presenceChannelName="/chat-reply/1" />`
      );

      await addUser(1, "sam");
      await addUser(2, "mark");
      await addUser(3, "joffrey");
      await addUser(4, "taylor");

      assert
        .dom(".chat-replying-indicator__text")
        .hasText("sam, mark and 2 others are typing");
    });

    test("filters current user from list of repliers", async function (assert) {
      this.channel = new ChatFabricators(getOwner(this)).channel();

      await render(
        hbs`<ChatReplyingIndicator  @presenceChannelName="/chat-reply/1" />`
      );

      await addUser(1, "sam");
      await addUser(this.currentUser.id, this.currentUser.username);

      assert.dom(".chat-replying-indicator__text").hasText("sam is typing");
    });

    test("resets presence when channel changes", async function (assert) {
      this.set("presenceChannelName", "/chat-reply/1");

      await addUser(1, "sam");

      await render(
        hbs`<ChatReplyingIndicator @presenceChannelName={{this.presenceChannelName}} />`
      );

      assert.dom(".chat-replying-indicator__text").hasText("sam is typing");

      this.set("presenceChannelName", "/chat-reply/2");

      assert.dom(".chat-replying-indicator__text").doesNotExist();
    });
  }
);
