import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { testMarkdown } from "discourse/tests/helpers/rich-editor-helper";

module(
  "Integration | Component | prosemirror-editor - html block extension",
  function (hooks) {
    setupRenderingTest(hooks);

    Object.entries({
      "unclosed html block": [
        "<div>Hello World\n\n",
        '<pre class="html-block"><code>&lt;div&gt;Hello World</code></pre>',
        "<div>Hello World\n\n",
      ],
      "html block with attributes": [
        'Hey\n\n<div class="test">Hello World</div>\nYou',
        '<p>Hey</p><pre class="html-block"><code>&lt;div class="test"&gt;Hello World&lt;/div&gt;\nYou</code></pre>',
        'Hey\n\n<div class="test">Hello World</div>\nYou\n\n',
      ],
      "html block with multiple lines": [
        "<div>\n  <p>Hello</p>\n  <p>World</p>\n</div>",
        '<pre class="html-block"><code>&lt;div&gt;\n  &lt;p&gt;Hello&lt;/p&gt;\n  &lt;p&gt;World&lt;/p&gt;\n&lt;/div&gt;</code></pre>',
        "<div>\n  <p>Hello</p>\n  <p>World</p>\n</div>\n\n",
      ],
      "html block multiple times": [
        "<div>1</div>\n\nA\n\n<div>2</div>",
        '<pre class="html-block"><code>&lt;div&gt;1&lt;/div&gt;</code></pre><p>A</p><pre class="html-block"><code>&lt;div&gt;2&lt;/div&gt;</code></pre>',
        "<div>1</div>\n\nA\n\n<div>2</div>\n\n",
      ],
      "html block with formatting that would be escaped outside it": [
        "<div>A **bold** or *italic* text</div>",
        '<pre class="html-block"><code>&lt;div&gt;A **bold** or *italic* text&lt;/div&gt;</code></pre>',
        "<div>A **bold** or *italic* text</div>\n\n",
      ],
    }).forEach(([name, [markdown, html, expectedMarkdown]]) => {
      test(name, async function (assert) {
        this.siteSettings.rich_editor = true;
        await testMarkdown(assert, markdown, html, expectedMarkdown);
      });
    });
  }
);
