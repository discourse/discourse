import { render } from "@ember/test-helpers";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import fabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import I18n from "I18n";

module(
  "Discourse Chat | Component | Chat::Message::LeftGutter",
  function (hooks) {
    setupRenderingTest(hooks);

    const template = hbs`
      <Chat::Message::LeftGutter @message={{this.message}} />
    `;

    test("default", async function (assert) {
      this.message = fabricators.message();

      await render(template);

      assert.dom(".chat-message-left-gutter__date").exists();
    });

    test("with reviewable", async function (assert) {
      this.message = fabricators.message({ reviewable_id: 1 });

      await render(template);

      assert
        .dom(".chat-message-left-gutter__flag .svg-icon-title")
        .hasAttribute("title", I18n.t("chat.flagged"));
    });

    test("with flag status", async function (assert) {
      this.message = fabricators.message({ user_flag_status: 0 });

      await render(template);

      assert
        .dom(".chat-message-left-gutter__flag .svg-icon-title")
        .hasAttribute("title", I18n.t("chat.you_flagged"));
    });

    test("bookmark", async function (assert) {
      this.message = fabricators.message({ bookmark: fabricators.bookmark() });

      await render(template);

      assert.dom(".chat-message-left-gutter__date").exists();
      assert.dom(".chat-message-left-gutter__bookmark").exists();
    });
  }
);
