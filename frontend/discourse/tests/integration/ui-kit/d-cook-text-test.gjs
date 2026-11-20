import { tracked } from "@glimmer/tracking";
import { render, settled } from "@ember/test-helpers";
import { resetCache } from "pretty-text/upload-short-url";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import DCookText from "discourse/ui-kit/d-cook-text";

module("Integration | ui-kit | DCookText", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    resetCache();
  });

  test("renders markdown", async function (assert) {
    await render(
      <template><DCookText class="post-body" @rawText="_foo_" /></template>
    );

    assert.dom(".post-body").hasHtml("<p><em>foo</em></p>");
  });

  test("resolves short URLs", async function (assert) {
    pretender.post("/uploads/lookup-urls", () =>
      response([
        {
          short_url: "upload://a.png",
          url: "/images/avatar.png",
          short_path: "/images/d-logo-sketch.png",
        },
      ])
    );

    await render(
      <template>
        <DCookText class="post-body" @rawText="![an image](upload://a.png)" />
      </template>
    );

    assert
      .dom(".post-body")
      .hasHtml('<p><img src="/images/avatar.png" alt="an image"></p>');
  });

  test("cooks again when @rawText changes", async function (assert) {
    const rawText = tracked("_foo_");

    await render(
      <template>
        <DCookText class="post-body" @rawText={{rawText.value}} />
      </template>
    );
    rawText.value = "**bar**";
    await settled();

    assert
      .dom(".post-body")
      .hasHtml("<p><strong>bar</strong></p>", "the new text is cooked");
  });

  test("reports its height after cooking", async function (assert) {
    const heights = [];
    const onHeight = (height) => heights.push(height);

    await render(
      <template>
        <DCookText @onOffsetHeightCalculated={{onHeight}} @rawText="_foo_" />
      </template>
    );

    assert.strictEqual(heights.length, 1, "the height is reported once");
    assert.true(heights[0] > 0, "the reported height is the rendered height");
  });
});
