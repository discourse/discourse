import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { testMarkdown } from "discourse/tests/helpers/rich-editor-helper";

module(
  "Integration | Component | prosemirror-editor - onebox extension",
  function (hooks) {
    setupRenderingTest(hooks);

    Object.entries({
      "full onebox": [
        [
          "https://example.com",
          '<p><a href="https://example.com"><span class="onebox-loading">https://example.com</span></a></p>',
          "https://example.com",
        ],
      ],
      "inline onebox": [
        [
          "Hello https://example.com World",
          '<p>Hello <a class="inline-onebox" href="https://example.com" contenteditable="false" draggable="true">Example Site</a> World</p>',
          "Hello https://example.com World",
        ],
      ],
      "multiple oneboxes": [
        [
          "https://example1.com\n\nhttps://example2.com",
          '<div class="onebox-wrapper" data-onebox-src="https://example1.com" contenteditable="false" draggable="true"><div class="onebox-loading"></div></div><div class="onebox-wrapper" data-onebox-src="https://example2.com" contenteditable="false" draggable="true"><div class="onebox-loading"></div></div>',
          "https://example1.com\n\nhttps://example2.com\n\n",
        ],
      ],
      "onebox with other content": [
        [
          "Hello\n\nhttps://example.com\n\nWorld",
          '<p>Hello</p><div class="onebox-wrapper" data-onebox-src="https://example.com" contenteditable="false" draggable="true"><div class="onebox-loading"></div></div><p>World</p>',
          "Hello\n\nhttps://example.com\n\nWorld",
        ],
      ],
    }).forEach(([name, tests]) => {
      tests.forEach(([markdown, expectedHtml, expectedMarkdown]) => {
        test(name, async function (assert) {
          this.siteSettings.rich_editor = true;

          await testMarkdown(assert, markdown, expectedHtml, expectedMarkdown);
        });
      });
    });
  }
);
