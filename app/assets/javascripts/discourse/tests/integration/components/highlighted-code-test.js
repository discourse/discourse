import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { query } from "discourse/tests/helpers/qunit-helpers";

const LONG_CODE_BLOCK = "puts a\n".repeat(15000);

module("Integration | Component | highlighted-code", function (hooks) {
  setupRenderingTest(hooks);

  test("highlighting code", async function (assert) {
    this.set("code", "def test; end");

    await render(hbs`<HighlightedCode @lang="ruby" @code={{this.code}} />`);

    assert.strictEqual(
      query("code.lang-ruby.hljs .hljs-keyword").innerText.trim(),
      "def"
    );
  });

  test("large code blocks are not highlighted", async function (assert) {
    this.set("code", LONG_CODE_BLOCK);

    await render(hbs`<HighlightedCode @lang="ruby" @code={{this.code}} />`);

    assert.strictEqual(query("code").innerText.trim(), LONG_CODE_BLOCK.trim());
  });
});
