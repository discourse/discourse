import { module, test } from "qunit";
import {
  clearRichEditorExtensions,
  resetRichEditorExtensions,
} from "discourse/lib/composer/rich-editor-extensions";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { testMarkdown } from "discourse/tests/helpers/rich-editor-helper";

module(
  "Integration | Component | prosemirror-editor - prosemirror-markdown defaults",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(() => clearRichEditorExtensions());
    hooks.afterEach(() => resetRichEditorExtensions());

    const testCases = {
      "paragraphs and hard breaks": [
        ["Hello", "<p>Hello</p>", "Hello"],
        ["Hello\nWorld", "<p>Hello<br>World</p>", "Hello\nWorld"],
        ["Hello\n\nWorld", "<p>Hello</p><p>World</p>", "Hello\n\nWorld"],
      ],
      blockquotes: [
        ["> Hello", "<blockquote><p>Hello</p></blockquote>", "> Hello"],
        [
          "> Hello\n> World",
          "<blockquote><p>Hello<br>World</p></blockquote>",
          "> Hello\n> World",
        ],
        [
          "> Hello\n\n> World",
          "<blockquote><p>Hello</p></blockquote><blockquote><p>World</p></blockquote>",
          "> Hello\n\n> World",
        ],
      ],
      "horizontal rule": [
        [
          "Hey\n\n---",
          '<p>Hey</p><div contenteditable="false" draggable="true"><hr></div>',
          "Hey\n\n---",
        ],
        [
          "***",
          '<div contenteditable="false" draggable="true"><hr></div>',
          "---",
        ],
      ],
      "heading (level 1-6)": [
        ["# Hello", "<h1>Hello</h1>", "# Hello"],
        ["# Hello\nWorld", "<h1>Hello</h1><p>World</p>", "# Hello\n\nWorld"],
        ["## Hello", "<h2>Hello</h2>", "## Hello"],
        ["### Hello", "<h3>Hello</h3>", "### Hello"],
        ["#### Hello", "<h4>Hello</h4>", "#### Hello"],
        ["##### Hello", "<h5>Hello</h5>", "##### Hello"],
        ["###### Hello", "<h6>Hello</h6>", "###### Hello"],
      ],
      "code block": [
        ["```\nHello\n```", "<pre><code>Hello</code></pre>", "```\nHello\n```"],
        [
          "```\nHello\nWorld\n```",
          "<pre><code>Hello\nWorld</code></pre>",
          "```\nHello\nWorld\n```",
        ],
        [
          "```\nHello\n\nWorld\n```",
          "<pre><code>Hello\n\nWorld</code></pre>",
          "```\nHello\n\nWorld\n```",
        ],
        [
          "```ruby\nHello\n```\n\nWorld",
          '<pre data-params="ruby"><code>Hello</code></pre><p>World</p>',
          "```ruby\nHello\n```\n\nWorld",
        ],
      ],
      "ordered lists": [
        [
          "1. Hello",
          `<ol data-tight="true"><li><p>Hello</p></li></ol>`,
          "1. Hello",
        ],
        [
          "1. Hello\n2. World",
          `<ol data-tight="true"><li><p>Hello</p></li><li><p>World</p></li></ol>`,
          "1. Hello\n2. World",
        ],
        [
          "5. Hello\n\n6. World",
          `<ol start="5"><li><p>Hello</p></li><li><p>World</p></li></ol>`,
          "5. Hello\n\n6. World",
        ],
      ],
      "bullet lists": [
        [
          "* Hello",
          '<ul data-tight="true"><li><p>Hello</p></li></ul>',
          "* Hello",
        ],
        [
          "* Hello\n* World",
          '<ul data-tight="true"><li><p>Hello</p></li><li><p>World</p></li></ul>',
          "* Hello\n* World",
        ],
        [
          "* Hello\n\n* World",
          "<ul><li><p>Hello</p></li><li><p>World</p></li></ul>",
          "* Hello\n\n* World",
        ],
      ],
      images: [
        [
          "![alt](src)",
          '<p><img src="src" alt="alt" contenteditable="false" draggable="true"></p>',
          "![alt](src)",
        ],
        [
          '![alt](src "title")',
          '<p><img src="src" alt="alt" title="title" contenteditable="false" draggable="true"></p>',
          '![alt](src "title")',
        ],
      ],
      em: [
        ["*Hello*", "<p><em>Hello</em></p>", "*Hello*"],
        ["_Hello_", "<p><em>Hello</em></p>", "*Hello*"],
      ],
      strong: [
        ["**Hello**", "<p><strong>Hello</strong></p>", "**Hello**"],
        ["__Hello__", "<p><strong>Hello</strong></p>", "**Hello**"],
      ],
      link: [
        ["[text](href)", '<p><a href="href">text</a></p>', "[text](href)"],
        [
          '[text](href "title")',
          '<p><a href="href" title="title">text</a></p>',
          '[text](href "title")',
        ],
      ],
      code: [
        ["Hel`lo wo`rld", "<p>Hel<code>lo wo</code>rld</p>", "Hel`lo wo`rld"],
      ],
      "all marks": [
        [
          "___[`Hello`](https://example.com)___",
          '<p><em><strong><a href="https://example.com"><code>Hello</code></a></strong></em></p>',
          "***[`Hello`](https://example.com)***",
        ],
      ],
    };

    Object.entries(testCases).forEach(([name, tests]) => {
      tests.forEach(([markdown, expectedHtml, expectedMarkdown]) => {
        test(name, async function (assert) {
          this.siteSettings.rich_editor = true;

          await testMarkdown(assert, markdown, expectedHtml, expectedMarkdown);
        });
      });
    });
  }
);
