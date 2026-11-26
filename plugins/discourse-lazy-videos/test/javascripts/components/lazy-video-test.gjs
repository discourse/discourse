import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { STREAM_HTML_DECORATOR } from "discourse/components/post/cooked-html";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { applyHtmlDecorators } from "discourse/ui-kit/d-decorated-html";
import LazyVideo from "discourse/plugins/discourse-lazy-videos/discourse/components/lazy-video";

module("Component | LazyVideo", function (hooks) {
  setupRenderingTest(hooks);

  this.attributes = {
    url: "https://www.youtube.com/watch?v=kPRA0W1kECg&list=RDkPRA0W1kECg",
    thumbnail: "thumbnail.jpeg",
    title: "15 Sorting Algorithms in 6 Minutes",
    providerName: "youtube",
    id: "kPRA0W1kECg",
    listId: "RDkPRA0W1kECg",
    dominantColor: "00ffff",
    startTime: 234,
  };

  test("displays the correct video title", async function (assert) {
    await render(
      <template><LazyVideo @videoAttributes={{this.attributes}} /></template>
    );

    assert.dom(".title-link").hasText(this.attributes.title);
  });

  test("uses the correct video start time", async function (assert) {
    await render(
      <template><LazyVideo @videoAttributes={{this.attributes}} /></template>
    );

    assert.dom(".youtube-onebox").hasAttribute("data-video-start-time", "234");
  });

  test("preserves the YouTube playlist", async function (assert) {
    await render(
      <template><LazyVideo @videoAttributes={{this.attributes}} /></template>
    );

    assert
      .dom(".youtube-onebox")
      .hasAttribute(
        "data-video-list-id",
        this.attributes.listId,
        "the playlist ID is retained on the lazy video"
      );

    await click(".video-thumbnail.youtube");

    assert
      .dom(".lazy-video-container.video-loaded iframe")
      .hasAttribute(
        "src",
        "https://www.youtube.com/embed/kPRA0W1kECg?autoplay=1&rel=0&list=RDkPRA0W1kECg&start=234",
        "the loaded iframe includes the playlist ID"
      );
  });

  test("displays the correct provider icon", async function (assert) {
    await render(
      <template><LazyVideo @videoAttributes={{this.attributes}} /></template>
    );

    assert.dom(".icon.youtube-icon").exists();
  });

  test("uses the dominant color from the dom", async function (assert) {
    await render(
      <template><LazyVideo @videoAttributes={{this.attributes}} /></template>
    );

    assert
      .dom(".video-thumbnail")
      .hasAttribute("style", "background-color: #00ffff;");
  });

  test("loads the iframe when clicked", async function (assert) {
    await render(
      <template><LazyVideo @videoAttributes={{this.attributes}} /></template>
    );
    assert.dom(".lazy-video-container.video-loaded").doesNotExist();

    await click(".video-thumbnail.youtube");
    assert.dom(".lazy-video-container.video-loaded iframe").exists();
  });

  test("accepts an optional onLoadedVideo callback function", async function (assert) {
    let foo = 1;
    const onLoadedVideo = () => (foo = 2);

    await render(
      <template>
        <LazyVideo
          @onLoadedVideo={{onLoadedVideo}}
          @videoAttributes={{this.attributes}}
        />
      </template>
    );
    assert.strictEqual(foo, 1);

    await click(".video-thumbnail.youtube");
    assert.strictEqual(foo, 2);
  });

  test("reuses a module-level component reference across decorateCookedElement calls", function (assert) {
    this.siteSettings.lazy_youtube_enabled = true;

    const makeCooked = (videoId) => {
      const cooked = document.createElement("div");
      cooked.className = "cooked";
      cooked.innerHTML = `<div class="youtube-onebox lazy-video-container" data-video-id="${videoId}" data-video-title="Video ${videoId}" data-provider-name="youtube"><a href="https://www.youtube.com/watch?v=${videoId}"><img src="thumb.jpg" /></a></div>`;
      return cooked;
    };

    const renderedComponents = [];
    const helper = {
      getModel: () => null,
      renderGlimmer(_el, component, data) {
        renderedComponents.push({ component, data });
      },
    };

    applyHtmlDecorators(makeCooked("abc123"), helper, STREAM_HTML_DECORATOR);
    applyHtmlDecorators(makeCooked("def456"), helper, STREAM_HTML_DECORATOR);

    assert.strictEqual(
      renderedComponents.length,
      2,
      "each lazy video container invokes renderGlimmer"
    );
    assert.strictEqual(
      renderedComponents[0].component,
      renderedComponents[1].component,
      "reuses the same module-level component reference instead of creating an inline template per post"
    );
    assert.strictEqual(renderedComponents[0].data.param.id, "abc123");
    assert.strictEqual(renderedComponents[1].data.param.id, "def456");
  });
});
