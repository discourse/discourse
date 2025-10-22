import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { testMarkdown } from "discourse/tests/helpers/rich-editor-helper";

module(
  "Integration | Component | prosemirror-editor - html-inline extension",
  function (hooks) {
    setupRenderingTest(hooks);

    Object.entries({
      "basic inline HTML tags": [
        "<kbd>Ctrl</kbd>",
        "<p><kbd>Ctrl</kbd> </p>",
        "<kbd>Ctrl</kbd> ",
      ],
      "nested inline HTML": [
        "<sup><small>text</small></sup>",
        "<p><sup><small>text</small></sup> </p>",
        "<sup><small>text</small></sup> ",
      ],
      "inline marks using HTML": [
        "<strong>bold</strong> and <em>italic</em>",
        "<p><strong>bold</strong> and <em>italic</em></p>",
        "**bold** and *italic*",
      ],
      "mixed HTML inline and marks": [
        "<kbd><strong>Ctrl+B</strong></kbd>",
        "<p><kbd><strong>Ctrl+B</strong></kbd> </p>",
        "<kbd>**Ctrl+B**</kbd> ",
      ],
      "multiple inline elements": [
        "Text with <sub>subscript</sub> and <sup>superscript</sup>",
        "<p>Text with <sub>subscript</sub> and <sup>superscript</sup> </p>",
        "Text with <sub>subscript</sub> and <sup>superscript</sup> ",
      ],
      "HTML mark aliases": [
        "<b>bold</b> and <i>italic</i>",
        "<p><strong>bold</strong> and <em>italic</em></p>",
        "**bold** and *italic*",
      ],
      "semantic HTML elements": [
        "<ins>inserted</ins> and <del>deleted</del>",
        "<p><ins>inserted</ins> and <del>deleted</del> </p>",
        "<ins>inserted</ins> and <del>deleted</del> ",
      ],
      "link HTML with href attribute": [
        '<a href="https://example.com">text</a>',
        '<p><a href="https://example.com">text</a></p>',
        "[text](https://example.com)",
      ],
      "link HTML with href and title": [
        '<a href="https://example.com" title="Title">x</a>',
        '<p><a href="https://example.com" title="Title">x</a></p>',
        '[x](https://example.com "Title")',
      ],
      "unmatched opening inline tag auto-closes": [
        "<kbd>x",
        "<p><kbd>x</kbd> </p>",
        "<kbd>x</kbd> ",
      ],
      "unmatched opening link tag auto-closes": [
        '<a href="https://example.com">x',
        '<p><a href="https://example.com">x</a></p>',
        "[x](https://example.com)",
      ],
      "image HTML with src, alt, width and height": [
        '<img src="https://example.com/image.png" alt="Alt text" width="100" height="200">',
        (assert) => {
          assert
            .dom("p img")
            .hasAttribute("src", "https://example.com/image.png");
          assert.dom("p img").hasAttribute("alt", "Alt text");
          assert.dom("p img").hasAttribute("width", "100");
          assert.dom("p img").hasAttribute("height", "200");
        },
        "![Alt text|100x200](https://example.com/image.png)",
      ],
      "image HTMl with text after": [
        '<img src="https://example.com/image.png" alt="Alt text"> after',
        (assert) => {
          assert
            .dom("p img")
            .hasAttribute("src", "https://example.com/image.png");
          assert.dom("p img").hasAttribute("alt", "Alt text");
          assert.dom("p").hasText("after");
        },
        "![Alt text](https://example.com/image.png) after",
      ],
    }).forEach(([name, [markdown, html, expectedMarkdown]]) => {
      test(name, async function (assert) {
        this.siteSettings.rich_editor = true;
        await testMarkdown(assert, markdown, html, expectedMarkdown);
      });
    });
  }
);
