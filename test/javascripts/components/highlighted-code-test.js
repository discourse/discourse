import componentTest from "helpers/component-test";

const LONG_CODE_BLOCK = "puts a\n".repeat(15000);

moduleForComponent("highlighted-code", { integration: true });

componentTest("highlighting code", {
  template: "{{highlighted-code lang='ruby' code=code}}",

  beforeEach() {
    Discourse.HighlightJSPath =
      "assets/highlightjs/highlight-test-bundle.min.js";
    this.set("code", "def test; end");
  },

  async test(assert) {
    assert.equal(
      find("code.ruby.hljs .hljs-function .hljs-keyword")
        .text()
        .trim(),
      "def"
    );
  }
});

componentTest("large code blocks are not highlighted", {
  template: "{{highlighted-code lang='ruby' code=code}}",

  beforeEach() {
    Discourse.HighlightJSPath =
      "assets/highlightjs/highlight-test-bundle.min.js";
    this.set("code", LONG_CODE_BLOCK);
  },

  async test(assert) {
    assert.equal(
      find("code")
        .text()
        .trim(),
      LONG_CODE_BLOCK.trim()
    );
  }
});
