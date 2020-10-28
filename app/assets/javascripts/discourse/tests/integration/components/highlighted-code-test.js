import { queryAll } from "discourse/tests/helpers/qunit-helpers";
import { moduleForComponent } from "ember-qunit";
import componentTest from "discourse/tests/helpers/component-test";

const LONG_CODE_BLOCK = "puts a\n".repeat(15000);

moduleForComponent("highlighted-code", { integration: true });

componentTest("highlighting code", {
  template: "{{highlighted-code lang='ruby' code=code}}",

  beforeEach() {
    this.session.highlightJsPath =
      "assets/highlightjs/highlight-test-bundle.min.js";
    this.set("code", "def test; end");
  },

  test(assert) {
    assert.equal(
      queryAll("code.ruby.hljs .hljs-function .hljs-keyword").text().trim(),
      "def"
    );
  },
});

componentTest("large code blocks are not highlighted", {
  template: "{{highlighted-code lang='ruby' code=code}}",

  beforeEach() {
    this.session.highlightJsPath =
      "assets/highlightjs/highlight-test-bundle.min.js";
    this.set("code", LONG_CODE_BLOCK);
  },

  test(assert) {
    assert.equal(queryAll("code").text().trim(), LONG_CODE_BLOCK.trim());
  },
});
