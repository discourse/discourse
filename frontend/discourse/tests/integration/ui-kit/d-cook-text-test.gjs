import { render } from "@ember/test-helpers";
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
      <template><DCookText @rawText="_foo_" class="post-body" /></template>
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
        <DCookText @rawText="![an image](upload://a.png)" class="post-body" />
      </template>
    );

    assert
      .dom(".post-body")
      .hasHtml('<p><img src="/images/avatar.png" alt="an image"></p>');
  });
});
