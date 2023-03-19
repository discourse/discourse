import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import fabricators from "../helpers/fabricators";
import { module, test } from "qunit";
import { render } from "@ember/test-helpers";
import { getOwner } from "discourse-common/lib/get-owner";

module(
  "Discourse Chat | Component | chat-replying-indicator",
  function (hooks) {
    setupRenderingTest(hooks);

    test("not displayed when no one is replying", async function (assert) {
      this.channel = fabricators.chatChannel();

      await render(hbs`<ChatReplyingIndicator @channel={{this.channel}} />`);

      assert.false(exists(".chat-replying-indicator__text"));
    });

    test("displays indicator when user is replying", async function (assert) {
      this.channel = fabricators.chatChannel();
      const presence = getOwner(this).lookup("service:presence");
      const presenceChannel = presence.getChannel(
        `/chat-reply/${this.channel.id}`
      );

      await render(hbs`<ChatReplyingIndicator @channel={{this.channel}} />`);

      const sam = { id: 1, username: "sam" };
      presenceChannel.set("users", [sam]);

      assert.strictEqual(
        query(".chat-replying-indicator__text").innerText,
        `${sam.username} is typing`
      );
    });

    test("displays indicator when 2 or 3 users are replying", async function (assert) {
      this.channel = fabricators.chatChannel();
      const presence = getOwner(this).lookup("service:presence");
      const presenceChannel = presence.getChannel(
        `/chat-reply/${this.channel.id}`
      );

      await render(hbs`<ChatReplyingIndicator @channel={{this.channel}} />`);

      const sam = { id: 1, username: "sam" };
      const mark = { id: 2, username: "mark" };
      presenceChannel.set("users", [sam, mark]);

      assert.strictEqual(
        query(".chat-replying-indicator__text").innerText,
        `${sam.username} and ${mark.username} are typing`
      );
    });

    test("displays indicator when 3 users are replying", async function (assert) {
      this.channel = fabricators.chatChannel();
      const presence = getOwner(this).lookup("service:presence");
      const presenceChannel = presence.getChannel(
        `/chat-reply/${this.channel.id}`
      );

      await render(hbs`<ChatReplyingIndicator @channel={{this.channel}} />`);

      const sam = { id: 1, username: "sam" };
      const mark = { id: 2, username: "mark" };
      const joffrey = { id: 3, username: "joffrey" };
      presenceChannel.set("users", [sam, mark, joffrey]);

      assert.strictEqual(
        query(".chat-replying-indicator__text").innerText,
        `${sam.username}, ${mark.username} and ${joffrey.username} are typing`
      );
    });

    test("displays indicator when more than 3 users are replying", async function (assert) {
      this.channel = fabricators.chatChannel();
      const presence = getOwner(this).lookup("service:presence");
      const presenceChannel = presence.getChannel(
        `/chat-reply/${this.channel.id}`
      );

      await render(hbs`<ChatReplyingIndicator @channel={{this.channel}} />`);

      const sam = { id: 1, username: "sam" };
      const mark = { id: 2, username: "mark" };
      const joffrey = { id: 3, username: "joffrey" };
      const taylor = { id: 4, username: "taylor" };
      presenceChannel.set("users", [sam, mark, joffrey, taylor]);

      assert.strictEqual(
        query(".chat-replying-indicator__text").innerText,
        `${sam.username}, ${mark.username} and 2 others are typing`
      );
    });

    test("filters current user from list of repliers", async function (assert) {
      this.channel = fabricators.chatChannel();

      await render(hbs`<ChatReplyingIndicator @channel={{this.channel}} />`);

      const sam = { id: 1, username: "sam" };
      const presence = getOwner(this).lookup("service:presence");

      const presenceChannel = presence.getChannel(
        `/chat-reply/${this.channel.id}`
      );
      console.log(presenceChannel._yoo);
      presenceChannel.set("users", [sam, this.currentUser]);

      assert.strictEqual(
        query(".chat-replying-indicator__text").innerText,
        `${sam.username} is typing`
      );
    });

    test("resets presence when channel is draft", async function (assert) {
      this.channel = fabricators.chatChannel();
      const presence = getOwner(this).lookup("service:presence");
      const presenceChannel = presence.getChannel(
        `/chat-reply/${this.channel.id}`
      );
      await render(hbs`<ChatReplyingIndicator @channel={{this.channel}} />`);

      this.channel.draft = true;

      assert.false(presenceChannel.subscribed);
    });
  }
);
