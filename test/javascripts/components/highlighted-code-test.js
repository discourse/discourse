import componentTest from "helpers/component-test";

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
