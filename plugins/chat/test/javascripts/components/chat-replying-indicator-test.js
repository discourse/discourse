import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import fabricators from "../helpers/fabricators";
import { module, test } from "qunit";
import { render, settled } from "@ember/test-helpers";
import { joinChannel } from "discourse/tests/helpers/presence-pretender";

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

      await render(hbs`<ChatReplyingIndicator @channel={{this.channel}} />`);

      await joinChannel("/chat-reply/1", {
        id: 1,
        avatar_template: "/images/avatar.png",
        username: "sam",
      });

      assert.strictEqual(
        query(".chat-replying-indicator__text").innerText,
        `sam is typing`
      );
    });

    test("displays indicator when 2 or 3 users are replying", async function (assert) {
      this.channel = fabricators.chatChannel();

      await render(hbs`<ChatReplyingIndicator @channel={{this.channel}} />`);

      await joinChannel("/chat-reply/1", {
        id: 1,
        avatar_template: "/images/avatar.png",
        username: "sam",
      });

      await joinChannel("/chat-reply/1", {
        id: 2,
        avatar_template: "/images/avatar.png",
        username: "mark",
      });

      assert.strictEqual(
        query(".chat-replying-indicator__text").innerText,
        `sam and mark are typing`
      );
    });

    test("displays indicator when 3 users are replying", async function (assert) {
      this.channel = fabricators.chatChannel();

      await render(hbs`<ChatReplyingIndicator @channel={{this.channel}} />`);

      await joinChannel("/chat-reply/1", {
        id: 1,
        avatar_template: "/images/avatar.png",
        username: "sam",
      });

      await joinChannel("/chat-reply/1", {
        id: 2,
        avatar_template: "/images/avatar.png",
        username: "mark",
      });

      await joinChannel("/chat-reply/1", {
        id: 3,
        avatar_template: "/images/avatar.png",
        username: "joffrey",
      });

      assert.strictEqual(
        query(".chat-replying-indicator__text").innerText,
        `sam, mark and joffrey are typing`
      );
    });

    test("displays indicator when more than 3 users are replying", async function (assert) {
      this.channel = fabricators.chatChannel();

      await render(hbs`<ChatReplyingIndicator  @channel={{this.channel}} />`);

      await joinChannel("/chat-reply/1", {
        id: 1,
        avatar_template: "/images/avatar.png",
        username: "sam",
      });

      await joinChannel("/chat-reply/1", {
        id: 2,
        avatar_template: "/images/avatar.png",
        username: "mark",
      });

      await joinChannel("/chat-reply/1", {
        id: 3,
        avatar_template: "/images/avatar.png",
        username: "joffrey",
      });

      await joinChannel("/chat-reply/1", {
        id: 4,
        avatar_template: "/images/avatar.png",
        username: "taylor",
      });

      assert.strictEqual(
        query(".chat-replying-indicator__text").innerText,
        `sam, mark and 2 others are typing`
      );
    });

    test("filters current user from list of repliers", async function (assert) {
      this.channel = fabricators.chatChannel();

      await render(hbs`<ChatReplyingIndicator  @channel={{this.channel}} />`);

      await joinChannel("/chat-reply/1", {
        id: 1,
        avatar_template: "/images/avatar.png",
        username: "sam",
      });

      await joinChannel("/chat-reply/1", this.currentUser);

      assert.strictEqual(
        query(".chat-replying-indicator__text").innerText,
        `sam is typing`
      );
    });

    test("resets presence when channel is draft", async function (assert) {
      this.channel = fabricators.chatChannel();

      await render(hbs`<ChatReplyingIndicator @channel={{this.channel}} />`);

      assert.dom(".chat-replying-indicator.is-subscribed").exists();

      this.channel.isDraft = true;

      await settled();

      assert.dom(".chat-replying-indicator.is-subscribed").doesNotExist();
    });
  }
);
