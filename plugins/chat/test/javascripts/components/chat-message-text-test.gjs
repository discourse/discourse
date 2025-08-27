import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ChatMessageText from "discourse/plugins/chat/discourse/components/chat-message-text";

module("Discourse Chat | Component | chat-message-text", function (hooks) {
  setupRenderingTest(hooks);

  test("yields", async function (assert) {
    const self = this;

    this.set("cooked", "<p></p>");

    await render(
      <template>
        <ChatMessageText @cooked={{self.cooked}} @uploads={{self.uploads}}>
          <div class="yield-me"></div>
        </ChatMessageText>
      </template>
    );

    assert.dom(".yield-me").exists();
  });

  test("shows collapsed", async function (assert) {
    const self = this;

    this.set(
      "cooked",
      '<div class="youtube-onebox lazy-video-container" data-video-id="WaT_rLGuUr8" data-video-title="Japanese Katsu Curry (Pork Cutlet)" data-provider-name="youtube"/>'
    );

    await render(
      <template>
        <ChatMessageText @cooked={{self.cooked}} @uploads={{self.uploads}} />
      </template>
    );

    assert.dom(".chat-message-collapser").exists();
  });

  test("does not collapse a non-image onebox", async function (assert) {
    const self = this;

    this.set("cooked", '<p><a href="http://cat1.com" class="onebox"></a></p>');

    await render(
      <template><ChatMessageText @cooked={{self.cooked}} /></template>
    );

    assert.dom(".chat-message-collapser").doesNotExist();
  });

  test("shows edits - regular message", async function (assert) {
    const self = this;

    this.set("cooked", "<p></p>");

    await render(
      <template>
        <ChatMessageText @cooked={{self.cooked}} @edited={{true}} />
      </template>
    );

    assert.dom(".chat-message-edited").exists();
  });

  test("shows edits - collapsible message", async function (assert) {
    const self = this;

    this.set(
      "cooked",
      '<div class="youtube-onebox lazy-video-container"></div>'
    );

    await render(
      <template>
        <ChatMessageText @cooked={{self.cooked}} @edited={{true}} />
      </template>
    );

    assert.dom(".chat-message-edited").exists();
  });
});
