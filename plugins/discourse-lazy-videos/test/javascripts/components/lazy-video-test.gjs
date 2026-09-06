import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import LazyVideo from "../discourse/components/lazy-video";

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
    this.set("foo", 1);
    this.set("onLoadedVideo", () => this.set("foo", 2));

    await render(
      <template>
        <LazyVideo
          @videoAttributes={{this.attributes}}
          @onLoadedVideo={{this.onLoadedVideo}}
        />
      </template>
    );
    assert.strictEqual(this.foo, 1);

    await click(".video-thumbnail.youtube");
    assert.strictEqual(this.foo, 2);
  });
});
