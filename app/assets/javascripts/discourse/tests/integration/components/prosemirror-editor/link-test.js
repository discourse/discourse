import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { testMarkdown } from "discourse/tests/helpers/rich-editor-helper";

module(
  "Integration | Component | prosemirror-editor - link extension",
  function (hooks) {
    setupRenderingTest(hooks);

    Object.entries({
      "basic link": [
        "[Example](https://example.com)",
        '<p><a href="https://example.com">Example</a></p>',
        "[Example](https://example.com)",
      ],
      "link with title": [
        '[Example](https://example.com "Example Title")',
        '<p><a href="https://example.com" title="Example Title">Example</a></p>',
        '[Example](https://example.com "Example Title")',
      ],
      autolink: [
        "<https://example.com>",
        '<p><a href="https://example.com" data-markup="autolink">https://example.com</a></p>',
        "<https://example.com>",
      ],
      "attachment link": [
        "[File|attachment](https://example.com/file.pdf)",
        '<p><a href="https://example.com/file.pdf" class="attachment">File</a></p>',
        "[File|attachment](https://example.com/file.pdf)",
      ],
      "attachment link with hash upload": [
        "[File|attachment](upload://some-hash)",
        '<p><a href="/404" class="attachment" data-orig-href="upload://some-hash">File</a></p>',
        "[File|attachment](upload://some-hash)",
      ],
    }).forEach(([name, [markdown, html, expectedMarkdown]]) => {
      test(name, async function (assert) {
        this.siteSettings.rich_editor = true;
        await testMarkdown(assert, markdown, html, expectedMarkdown);
      });
    });
  }
);
