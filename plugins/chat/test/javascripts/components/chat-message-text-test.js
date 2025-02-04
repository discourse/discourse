import { render } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Discourse Chat | Component | chat-message-text", function (hooks) {
  setupRenderingTest(hooks);

  test("yields", async function (assert) {
    this.set("cooked", "<p></p>");

    await render(hbs`
      <ChatMessageText @cooked={{this.cooked}} @uploads={{this.uploads}}>
        <div class="yield-me"></div>
      </ChatMessageText>
    `);

    assert.dom(".yield-me").exists();
  });

  test("shows collapsed", async function (assert) {
    this.set(
      "cooked",
      '<div class="youtube-onebox lazy-video-container" data-video-id="WaT_rLGuUr8" data-video-title="Japanese Katsu Curry (Pork Cutlet)" data-provider-name="youtube"/>'
    );

    await render(
      hbs`<ChatMessageText @cooked={{this.cooked}} @uploads={{this.uploads}} />`
    );

    assert.dom(".chat-message-collapser").exists();
  });

  test("does not collapse a non-image onebox", async function (assert) {
    this.set("cooked", '<p><a href="http://cat1.com" class="onebox"></a></p>');

    await render(hbs`<ChatMessageText @cooked={{this.cooked}} />`);

    assert.dom(".chat-message-collapser").doesNotExist();
  });

  test("shows edits - regular message", async function (assert) {
    this.set("cooked", "<p></p>");

    await render(
      hbs`<ChatMessageText @cooked={{this.cooked}} @edited={{true}} />`
    );

    assert.dom(".chat-message-edited").exists();
  });

  test("shows edits - collapsible message", async function (assert) {
    this.set(
      "cooked",
      '<div class="youtube-onebox lazy-video-container"></div>'
    );

    await render(
      hbs`<ChatMessageText @cooked={{this.cooked}} @edited={{true}} />`
    );

    assert.dom(".chat-message-edited").exists();
  });
});
