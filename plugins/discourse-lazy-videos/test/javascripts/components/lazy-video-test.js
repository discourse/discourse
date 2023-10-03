import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import { click, render } from "@ember/test-helpers";

module("Discourse Lazy Videos | Component | lazy-video", function (hooks) {
  setupRenderingTest(hooks);

  this.attributes = {
    url: "https://www.youtube.com/watch?v=kPRA0W1kECg",
    thumbnail: "thumbnail.jpeg",
    title: "15 Sorting Algorithms in 6 Minutes",
    providerName: "youtube",
    id: "kPRA0W1kECg",
    dominantColor: "00ffff",
    startTime: 234,
  };

  test("displays the correct video title", async function (assert) {
    await render(hbs`<LazyVideo @videoAttributes={{this.attributes}} />`);

    assert.dom(".title-link").hasText(this.attributes.title);
  });

  test("uses the correct video start time", async function (assert) {
    await render(hbs`<LazyVideo @videoAttributes={{this.attributes}} />`);

    assert.dom(".youtube-onebox").hasAttribute("data-video-start-time", "234");
  });

  test("displays the correct provider icon", async function (assert) {
    await render(hbs`<LazyVideo @videoAttributes={{this.attributes}} />`);

    assert.dom(".icon.youtube-icon").exists();
  });

  test("uses tthe dominant color from the dom", async function (assert) {
    await render(hbs`<LazyVideo @videoAttributes={{this.attributes}} />`);

    assert
      .dom(".video-thumbnail")
      .hasAttribute("style", "background-color: #00ffff;");
  });

  test("loads the iframe when clicked", async function (assert) {
    await render(hbs`<LazyVideo @videoAttributes={{this.attributes}}/>`);
    assert.dom(".lazy-video-container.video-loaded").doesNotExist();

    await click(".video-thumbnail.youtube");
    assert.dom(".lazy-video-container.video-loaded iframe").exists();
  });

  test("accepts an optional onLoadedVideo callback function", async function (assert) {
    this.set("foo", 1);
    this.set("onLoadedVideo", () => this.set("foo", 2));

    await render(
      hbs`<LazyVideo @videoAttributes={{this.attributes}} @onLoadedVideo={{this.onLoadedVideo}} />`
    );
    assert.strictEqual(this.foo, 1);

    await click(".video-thumbnail.youtube");
    assert.strictEqual(this.foo, 2);
  });
});
