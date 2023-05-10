import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { query } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import fabricators from "../helpers/fabricators";
import { module, test } from "qunit";
import { render } from "@ember/test-helpers";
import { joinChannel } from "discourse/tests/helpers/presence-pretender";

async function addUserToChannel(channelId, id, username) {
  await joinChannel(`/chat-reply/${channelId}`, {
    id,
    avatar_template: "/images/avatar.png",
    username,
  });
}

module(
  "Discourse Chat | Component | chat-replying-indicator",
  function (hooks) {
    setupRenderingTest(hooks);

    test("not displayed when no one is replying", async function (assert) {
      this.channel = fabricators.chatChannel();

      await render(hbs`<ChatReplyingIndicator @channel={{this.channel}} />`);

      assert.dom(".chat-replying-indicator__text").doesNotExist();
    });

    test("displays indicator when user is replying", async function (assert) {
      this.channel = fabricators.chatChannel();

      await render(hbs`<ChatReplyingIndicator @channel={{this.channel}} />`);

      await addUserToChannel(1, 1, "sam");

      assert.strictEqual(
        query(".chat-replying-indicator__text").innerText,
        `sam is typing`
      );
    });

    test("displays indicator when 2 or 3 users are replying", async function (assert) {
      this.channel = fabricators.chatChannel();

      await render(hbs`<ChatReplyingIndicator @channel={{this.channel}} />`);

      await addUserToChannel(1, 1, "sam");
      await addUserToChannel(1, 2, "mark");

      assert
        .dom(".chat-replying-indicator__text")
        .hasText("sam and mark are typing");
    });

    test("displays indicator when 3 users are replying", async function (assert) {
      this.channel = fabricators.chatChannel();

      await render(hbs`<ChatReplyingIndicator @channel={{this.channel}} />`);

      await addUserToChannel(1, 1, "sam");
      await addUserToChannel(1, 2, "mark");
      await addUserToChannel(1, 3, "joffrey");

      assert
        .dom(".chat-replying-indicator__text")
        .hasText("sam, mark and joffrey are typing");
    });

    test("displays indicator when more than 3 users are replying", async function (assert) {
      this.channel = fabricators.chatChannel();

      await render(hbs`<ChatReplyingIndicator  @channel={{this.channel}} />`);

      await addUserToChannel(1, 1, "sam");
      await addUserToChannel(1, 2, "mark");
      await addUserToChannel(1, 3, "joffrey");
      await addUserToChannel(1, 4, "taylor");

      assert
        .dom(".chat-replying-indicator__text")
        .hasText("sam, mark and 2 others are typing");
    });

    test("filters current user from list of repliers", async function (assert) {
      this.channel = fabricators.chatChannel();

      await render(hbs`<ChatReplyingIndicator  @channel={{this.channel}} />`);

      await addUserToChannel(1, 1, "sam");
      await addUserToChannel(1, this.currentUser.id, this.currentUser.username);

      assert.dom(".chat-replying-indicator__text").hasText("sam is typing");
    });

    test("resets presence when channel changes", async function (assert) {
      this.set("channel", fabricators.chatChannel());

      await addUserToChannel(1, 1, "sam");

      await render(hbs`<ChatReplyingIndicator @channel={{this.channel}} />`);

      assert.dom(".chat-replying-indicator__text").hasText("sam is typing");

      this.set("channel", fabricators.chatChannel({ id: 2 }));

      assert.dom(".chat-replying-indicator__text").doesNotExist();
    });
  }
);
