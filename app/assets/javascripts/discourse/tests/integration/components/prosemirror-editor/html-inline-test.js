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
        "<p><kbd>Ctrl</kbd></p>",
        "<kbd>Ctrl</kbd>",
      ],
      "nested inline HTML": [
        "<sup><small>text</small></sup>",
        "<p><sup><small>text</small></sup></p>",
        "<sup><small>text</small></sup>",
      ],
      "inline marks using HTML": [
        "<strong>bold</strong> and <em>italic</em>",
        "<p><strong>bold</strong> and <em>italic</em></p>",
        "**bold** and *italic*",
      ],
      "mixed HTML inline and marks": [
        "<kbd><strong>Ctrl+B</strong></kbd>",
        "<p><kbd><strong>Ctrl+B</strong></kbd></p>",
        "<kbd>**Ctrl+B**</kbd>",
      ],
      "multiple inline elements": [
        "Text with <sub>subscript</sub> and <sup>superscript</sup>",
        "<p>Text with <sub>subscript</sub> and <sup>superscript</sup></p>",
        "Text with <sub>subscript</sub> and <sup>superscript</sup>",
      ],
      "HTML mark aliases": [
        "<b>bold</b> and <i>italic</i>",
        "<p><strong>bold</strong> and <em>italic</em></p>",
        "**bold** and *italic*",
      ],
      "semantic HTML elements": [
        "<ins>inserted</ins> and <del>deleted</del>",
        "<p><ins>inserted</ins> and <del>deleted</del></p>",
        "<ins>inserted</ins> and <del>deleted</del>",
      ],
    }).forEach(([name, [markdown, html, expectedMarkdown]]) => {
      test(name, async function (assert) {
        this.siteSettings.rich_editor = true;
        await testMarkdown(assert, markdown, html, expectedMarkdown);
      });
    });
  }
);
