import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ChatMessageText from "discourse/plugins/chat/discourse/components/chat-message-text";

module("Component | ChatMessageText", function (hooks) {
  setupRenderingTest(hooks);

  test("yields", async function (assert) {
    this.set("cooked", "<p></p>");

    await render(
      <template>
        <ChatMessageText @cooked={{this.cooked}} @uploads={{this.uploads}}>
          <div class="yield-me"></div>
        </ChatMessageText>
      </template>
    );

    assert.dom(".yield-me").exists();
  });

  test("shows collapsed", async function (assert) {
    this.set(
      "cooked",
      '<div class="youtube-onebox lazy-video-container" data-video-id="WaT_rLGuUr8" data-video-title="Japanese Katsu Curry (Pork Cutlet)" data-provider-name="youtube"/>'
    );

    await render(
      <template>
        <ChatMessageText @cooked={{this.cooked}} @uploads={{this.uploads}} />
      </template>
    );

    assert.dom(".chat-message-collapser").exists();
  });

  test("does not collapse a non-image onebox", async function (assert) {
    this.set("cooked", '<p><a href="http://cat1.com" class="onebox"></a></p>');

    await render(
      <template><ChatMessageText @cooked={{this.cooked}} /></template>
    );

    assert.dom(".chat-message-collapser").doesNotExist();
  });

  test("shows edits - regular message", async function (assert) {
    this.set("cooked", "<p></p>");

    await render(
      <template>
        <ChatMessageText @cooked={{this.cooked}} @edited={{true}} />
      </template>
    );

    assert.dom(".chat-message-edited").exists();
  });

  test("shows edits - collapsible message", async function (assert) {
    this.set(
      "cooked",
      '<div class="youtube-onebox lazy-video-container"></div>'
    );

    await render(
      <template>
        <ChatMessageText @cooked={{this.cooked}} @edited={{true}} />
      </template>
    );

    assert.dom(".chat-message-edited").exists();
  });

  test("hides the upload widget for an image already rendered inline in cooked", async function (assert) {
    // Rehosted hotlinked image: inline <img> carries data-base62-sha1, and the
    // same upload is also attached. The collapser tile should be suppressed.
    this.set(
      "cooked",
      '<p><img src="/uploads/default/original/1X/abc.png" data-base62-sha1="abcdef"></p>'
    );
    this.set("uploads", [
      { id: 1, short_url: "upload://abcdef.png", extension: "png" },
    ]);

    await render(
      <template>
        <ChatMessageText @cooked={{this.cooked}} @uploads={{this.uploads}} />
      </template>
    );

    assert
      .dom(".chat-uploads")
      .doesNotExist("inline-rendered upload is not duplicated in the widget");
  });

  test("keeps the upload widget for an attached image not inline in cooked", async function (assert) {
    this.set("cooked", "<p>just text</p>");
    this.set("uploads", [
      { id: 1, short_url: "upload://zzzzzz.png", extension: "png" },
    ]);

    await render(
      <template>
        <ChatMessageText @cooked={{this.cooked}} @uploads={{this.uploads}} />
      </template>
    );

    assert.dom(".chat-uploads").exists("attachment-only upload still renders");
  });
});
