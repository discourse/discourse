import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import { click, render } from "@ember/test-helpers";

const videoAttributes = {
  url: "https://www.youtube.com/watch?v=kPRA0W1kECg",
  thumbnail: "thumbnail.jpeg",
  title: "15 Sorting Algorithms in 6 Minutes",
  providerName: "youtube",
  id: "kPRA0W1kECg",
};

module("Discourse Lazy Videos | Component | lazy-video", function (hooks) {
  setupRenderingTest(hooks);

  test("displays the correct video title", async function (assert) {
    this.set("attributes", videoAttributes);

    await render(hbs`<LazyVideo @videoAttributes={{this.attributes}} />`);

    assert.dom(".title-link").hasText(this.attributes.title);
  });

  test("displays the correct provider icon", async function (assert) {
    this.set("attributes", videoAttributes);

    await render(hbs`<LazyVideo @videoAttributes={{this.attributes}} />`);

    assert.dom(".icon.youtube-icon").exists();
  });

  test("loads the iframe when clicked", async function (assert) {
    this.set("attributes", videoAttributes);

    await render(hbs`<LazyVideo @videoAttributes={{this.attributes}}/>`);
    assert.dom(".lazy-video-container.video-loaded").doesNotExist();

    await click(".video-thumbnail.youtube");
    assert.dom(".lazy-video-container.video-loaded iframe").exists();
  });

  test("accepts an optional callback function", async function (assert) {
    this.set("attributes", videoAttributes);
    this.set("foo", 1);
    this.set("callback", () => this.set("foo", 2));

    await render(
      hbs`<LazyVideo @videoAttributes={{this.attributes}} @callback={{this.callback}} />`
    );
    assert.strictEqual(this.foo, 1);

    await click(".video-thumbnail.youtube");
    assert.strictEqual(this.foo, 2);
  });
});
