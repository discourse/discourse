import { tracked } from "@glimmer/tracking";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import HighlightedCode from "admin/components/highlighted-code";

module("Integration | Component | highlighted-code", function (hooks) {
  setupRenderingTest(hooks);

  test("highlighting code", async function (assert) {
    await render(
      <template>
        <HighlightedCode @lang="ruby" @code="def test; end" />
      </template>
    );

    assert.dom("code.lang-ruby.hljs .hljs-keyword").hasText("def");
  });

  test("large code blocks are not highlighted", async function (assert) {
    const longCodeBlock = "puts a\n".repeat(15000);

    await render(
      <template>
        <HighlightedCode @lang="ruby" @code={{longCodeBlock}} />
      </template>
    );

    assert.dom("pre code").hasText(longCodeBlock);
  });

  test("highlighting code with lang=auto", async function (assert) {
    await render(
      <template>
        <HighlightedCode @lang="auto" @code="def test; end" />
      </template>
    );

    assert.dom("code.hljs").hasNoClass("lang-auto", "lang-auto is removed");
    assert.dom("code.hljs").hasClass(/language-/, "language is detected");

    assert
      .dom("code.hljs")
      .hasNoAttribute(
        "data-unknown-hljs-lang",
        "language is found from language- class"
      );
  });

  test("re-highlights the code when it changes", async function (assert) {
    class State {
      @tracked code = "def foo; end";
    }

    const testState = new State();

    await render(
      <template>
        <HighlightedCode @lang="ruby" @code={{testState.code}} />
        {{testState.code}}
      </template>
    );

    assert.dom("code.lang-ruby.hljs .hljs-title").hasText("foo");

    testState.code = "def bar; end";
    await settled();

    assert.dom("code.lang-ruby.hljs .hljs-title").hasText("bar");
  });
});
