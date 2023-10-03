import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import hbs from "htmlbars-inline-precompile";
import fabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import { module, test } from "qunit";
import { render } from "@ember/test-helpers";

module(
  "Discourse Chat | Component | chat-composer-message-details",
  function (hooks) {
    setupRenderingTest(hooks);

    test("data-id attribute", async function (assert) {
      this.message = fabricators.message();

      await render(
        hbs`<ChatComposerMessageDetails @message={{this.message}} />`
      );

      assert
        .dom(".chat-composer-message-details")
        .hasAttribute("data-id", this.message.id.toString());
    });

    test("editing a message has the pencil icon", async function (assert) {
      this.message = fabricators.message({ editing: true });

      await render(
        hbs`<ChatComposerMessageDetails @message={{this.message}} />`
      );

      assert.dom(".chat-composer-message-details .d-icon-pencil-alt").exists();
    });

    test("replying to a message has the reply icon", async function (assert) {
      const firstMessage = fabricators.message();
      this.message = fabricators.message({ inReplyTo: firstMessage });

      await render(
        hbs`<ChatComposerMessageDetails @message={{this.message}} />`
      );

      assert.dom(".chat-composer-message-details .d-icon-reply").exists();
    });

    test("displays user avatar", async function (assert) {
      this.message = fabricators.message();

      await render(
        hbs`<ChatComposerMessageDetails @message={{this.message}} />`
      );

      assert
        .dom(".chat-composer-message-details .chat-user-avatar .avatar")
        .hasAttribute("title", this.message.user.username);
    });

    test("displays message excerpt", async function (assert) {
      this.message = fabricators.message();

      await render(
        hbs`<ChatComposerMessageDetails @message={{this.message}} />`
      );

      assert.dom(".chat-reply__excerpt").hasText(this.message.excerpt);
    });

    test("displays user’s username", async function (assert) {
      this.message = fabricators.message();

      await render(
        hbs`<ChatComposerMessageDetails @message={{this.message}} />`
      );

      assert.dom(".chat-reply__username").hasText(this.message.user.username);
    });
  }
);
