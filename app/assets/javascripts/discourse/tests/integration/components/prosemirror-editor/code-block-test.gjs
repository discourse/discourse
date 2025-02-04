import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { testMarkdown } from "discourse/tests/helpers/rich-editor-helper";

module(
  "Integration | Component | prosemirror-editor - code-block extension",
  function (hooks) {
    setupRenderingTest(hooks);

    const select = (lang = "") =>
      `<select contenteditable="false" class="code-language-select"><option>${lang}</option><option>javascript</option><option>ruby</option><option>sql</option></select>`;

    Object.entries({
      "basic code block": [
        "```plaintext\nconsole.log('Hello, world!');\n```",
        `<pre class="code-block"><code>console.log('Hello, world!');</code>${select(
          "plaintext"
        )}</pre>`,
        "```plaintext\nconsole.log('Hello, world!');\n```",
      ],
      "code block within list item": [
        "- ```plaintext\n  console.log('Hello, world!');\n  ```",
        `<ul><li><pre class="code-block"><code>console.log('Hello, world!');</code>${select(
          "plaintext"
        )}</pre></li></ul>`,
        "* ```plaintext\n  console.log('Hello, world!');\n  ```",
      ],
      "code block with language": [
        '```javascript\nconsole.log("Hello, world!");\n```',
        `<pre class="code-block"><code><span class="hljs-variable language_">console</span>.<span class="hljs-title function_">log</span>(<span class="hljs-string">"Hello, world!"</span>);</code>${select()}</pre>`,
        '```javascript\nconsole.log("Hello, world!");\n```',
      ],
      "code block with 4 spaces": [
        "    print('Hello, world!')",
        `<pre class="code-block"><code><span class="hljs-title function_">print</span>(<span class="hljs-string">'Hello, world!'</span>)</code>${select()}</pre>`,
        "```\nprint('Hello, world!')\n```",
      ],
      "code block with 4 spaces within list item": [
        "-     print('Hello, world!')",
        `<ul><li><pre class="code-block"><code><span class="hljs-title function_">print</span>(<span class="hljs-string">\'Hello, world!\'</span>)</code>${select()}</pre></li></ul>`,
        "* ```\n  print('Hello, world!')\n  ```",
      ],
    }).forEach(([name, [markdown, html, expectedMarkdown]]) => {
      test(name, async function (assert) {
        this.siteSettings.rich_editor = true;
        await testMarkdown(assert, markdown, html, expectedMarkdown);
      });
    });
  }
);
