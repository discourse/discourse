import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import highlightSyntax from "discourse/lib/highlight-syntax";
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

  test("highlighting code with lang=auto", async function (assert) {
    this.set("code", "def test; end");

    await render(hbs`<HighlightedCode @lang="auto" @code={{this.code}} />`);

    const codeElement = query("code.hljs");

    assert.ok(
      !codeElement.classList.contains("lang-auto"),
      "lang-auto is removed"
    );
    assert.ok(
      Array.from(codeElement.classList).some((className) => {
        return className.startsWith("language-");
      }),
      "language is detected"
    );

    await highlightSyntax(
      codeElement.parentElement, // <pre>
      this.siteSettings,
      this.session
    );

    assert.ok(
      codeElement.dataset.unknownHljsLang === undefined,
      "language is found from language- class"
    );
  });
});
