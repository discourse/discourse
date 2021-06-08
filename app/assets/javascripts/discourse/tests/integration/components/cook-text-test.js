import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { discourseModule, query } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import pretender from "discourse/tests/helpers/create-pretender";
import { resetCache } from "pretty-text/upload-short-url";

discourseModule("Integration | Component | cook-text", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("renders markdown", {
    template: hbs`{{cook-text "_foo_" class="post-body"}}`,

    test(assert) {
      const html = query(".post-body").innerHTML.trim();
      assert.equal(html, "<p><em>foo</em></p>");
    },
  });

  componentTest("resolves short URLs", {
    template: hbs`{{cook-text "![an image](upload://a.png)" class="post-body"}}`,

    beforeEach() {
      pretender.post("/uploads/lookup-urls", () => {
        return [
          200,
          { "Content-Type": "application/json" },
          [
            {
              short_url: "upload://a.png",
              url: "/images/avatar.png",
              short_path: "/images/d-logo-sketch.png",
            },
          ],
        ];
      });
    },

    afterEach() {
      resetCache();
    },

    test(assert) {
      const html = query(".post-body").innerHTML.trim();
      assert.equal(
        html,
        '<p><img src="/images/avatar.png" alt="an image"></p>'
      );
    },
  });
});
