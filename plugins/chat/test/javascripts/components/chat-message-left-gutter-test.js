import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import CoreFabricators from "discourse/lib/fabricators";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module(
  "Discourse Chat | Component | Chat::Message::LeftGutter",
  function (hooks) {
    setupRenderingTest(hooks);

    const template = hbs`
      <Chat::Message::LeftGutter @message={{this.message}} />
    `;

    test("default", async function (assert) {
      this.message = new ChatFabricators(getOwner(this)).message();

      await render(template);

      assert.dom(".chat-message-left-gutter__date").exists();
    });

    test("with reviewable", async function (assert) {
      this.message = new ChatFabricators(getOwner(this)).message({
        reviewable_id: 1,
      });

      await render(template);

      assert
        .dom(".chat-message-left-gutter__flag .svg-icon-title")
        .hasAttribute("title", i18n("chat.flagged"));
    });

    test("with flag status", async function (assert) {
      this.message = new ChatFabricators(getOwner(this)).message({
        user_flag_status: 0,
      });

      await render(template);

      assert
        .dom(".chat-message-left-gutter__flag .svg-icon-title")
        .hasAttribute("title", i18n("chat.you_flagged"));
    });

    test("bookmark", async function (assert) {
      this.message = new ChatFabricators(getOwner(this)).message({
        bookmark: new CoreFabricators(getOwner(this)).bookmark(),
      });

      await render(template);

      assert.dom(".chat-message-left-gutter__date").exists();
      assert.dom(".chat-message-left-gutter__bookmark").exists();
    });
  }
);
