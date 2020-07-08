import componentTest from "helpers/component-test";
import { waitForHighlighting } from "discourse/lib/highlight-syntax";

const LONG_CODE_BLOCK = "puts a\n".repeat(15000);

moduleForComponent("highlighted-code", { integration: true });

componentTest("highlighting code", {
  template: "{{highlighted-code lang='ruby' code=code}}",

  beforeEach() {
    Discourse.HighlightJSPath =
      "/assets/highlightjs/highlight-test-bundle.min.js";
    Discourse.HighlightJSWorkerURL = "/assets/highlightjs-worker.js";
  },

  async test(assert) {
    this.set("code", "def test; end");

    await waitForHighlighting();

    assert.equal(
      find("code.ruby.hljs .hljs-function .hljs-keyword")
        .text()
        .trim(),
      "def"
    );
  },

  
  async test(assert) {
    this.set("code", LONG_CODE_BLOCK);
    await waitForHighlighting();

    assert.equal(
      find("code")
        .text()
        .trim(),
      LONG_CODE_BLOCK.trim()
    );
  }

});
