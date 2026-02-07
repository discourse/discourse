import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  getExtensions,
  registerRichEditorExtension,
  resetRichEditorExtensions,
} from "discourse/lib/composer/rich-editor-extensions";
import toMarkdown from "discourse/lib/to-markdown";
import mathExtension from "discourse/plugins/discourse-math/lib/rich-editor-extension";

module("Unit | Lib | to-markdown-math", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(async function () {
    await resetRichEditorExtensions();
    if (!getExtensions().includes(mathExtension)) {
      registerRichEditorExtension(mathExtension);
    }
  });

  test("converts inline mathjax to markdown", function (assert) {
    const html = `<p>Lorem ipsum <span class="math" data-applied-mathjax="true" style="display: none;">E=mc^2</span><span class="math-container inline-math mathjax-math" style=""><mjx-container class="MathJax" jax="SVG"><svg></svg></mjx-container></span> dolor sit amet.</p>`;
    const markdown = `Lorem ipsum $E=mc^2$ dolor sit amet.`;
    assert.strictEqual(toMarkdown(html), markdown);
  });

  test("converts block mathjax to markdown", function (assert) {
    const html = `<p>Before</p>
    <div class="math" data-applied-mathjax="true" style="display: none;">
    \\sqrt{(-1)} \\; 2^3 \\; \\sum \\; \\pi
    </div><div class="math-container block-math mathjax-math" style=""><mjx-container class="MathJax" jax="SVG" display="true"><svg></svg></mjx-container></div>
    <p>After</p>`;

    const markdown = `Before

$$
\\sqrt{(-1)} \\; 2^3 \\; \\sum \\; \\pi
$$

After`;

    assert.strictEqual(toMarkdown(html), markdown);
  });
});
