import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { query } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";

const LONG_CODE_BLOCK = "puts a\n".repeat(15000);

module("Integration | Component | highlighted-code", function (hooks) {
  setupRenderingTest(hooks);

  test("highlighting code", async function (assert) {
    this.session.highlightJsPath =
      "/assets/highlightjs/highlight-test-bundle.min.js";
    this.set("code", "def test; end");

    await render(hbs`<HighlightedCode @lang="ruby" @code={{this.code}} />`);

    assert.strictEqual(
      query("code.language-ruby.hljs .hljs-keyword").innerText.trim(),
      "def"
    );
  });

  test("large code blocks are not highlighted", async function (assert) {
    this.session.highlightJsPath =
      "/assets/highlightjs/highlight-test-bundle.min.js";
    this.set("code", LONG_CODE_BLOCK);

    await render(hbs`<HighlightedCode @lang="ruby" @code={{this.code}} />`);

    assert.strictEqual(query("code").innerText.trim(), LONG_CODE_BLOCK.trim());
  });
});
