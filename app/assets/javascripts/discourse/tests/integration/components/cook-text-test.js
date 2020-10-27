import { moduleForComponent } from "ember-qunit";
import componentTest from "discourse/tests/helpers/component-test";
import { addPretenderCallback } from "discourse/tests/helpers/qunit-helpers";
import { resetCache } from "pretty-text/upload-short-url";

moduleForComponent("cook-text", { integration: true });

componentTest("renders markdown", {
  template: '{{cook-text "_foo_" class="post-body"}}',

  test(assert) {
    const html = find(".post-body")[0].innerHTML.trim();
    assert.equal(html, "<p><em>foo</em></p>");
  },
});

addPretenderCallback("cook-text", (server, helper) => {
  server.post("/uploads/lookup-urls", () =>
    helper.response([
      {
        short_url: "upload://a.png",
        url: "/images/avatar.png",
        short_path: "/images/d-logo-sketch.png",
      },
    ])
  );
});

componentTest("resolves short URLs", {
  template: `{{cook-text "![an image](upload://a.png)" class="post-body"}}`,

  afterEach() {
    resetCache();
  },

  test(assert) {
    const html = find(".post-body")[0].innerHTML.trim();
    assert.equal(html, '<p><img src="/images/avatar.png" alt="an image"></p>');
  },
});
