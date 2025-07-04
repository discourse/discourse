import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { testMarkdown } from "discourse/tests/helpers/rich-editor-helper";

module(
  "Integration | Component | prosemirror-editor - image extension",
  function (hooks) {
    setupRenderingTest(hooks);

    const wrap = (img) =>
      `<p><div class="composer-image-node" contenteditable="false" draggable="true">${img}</div></p>`;

    const testCases = {
      image: [
        [
          "![alt text](https://example.com/image.jpg)",
          wrap('<img src="https://example.com/image.jpg" alt="alt text">'),
          "![alt text](https://example.com/image.jpg)",
        ],
        [
          "![alt text](https://example.com/image.jpg 'title')",
          wrap(
            '<img src="https://example.com/image.jpg" alt="alt text" title="title">'
          ),
          '![alt text](https://example.com/image.jpg "title")',
        ],
        [
          '![alt text|100x200](https://example.com/image.jpg "title")',
          wrap(
            '<img src="https://example.com/image.jpg" alt="alt text" title="title" width="100" height="200">'
          ),
          '![alt text|100x200](https://example.com/image.jpg "title")',
        ],
        [
          "![alt text|100x200, 50%](https://example.com/image.jpg)",
          wrap(
            '<img src="https://example.com/image.jpg" alt="alt text" width="100" height="200" data-scale="50" style="width: 50px; height: 100px;">'
          ),
          "![alt text|100x200, 50%](https://example.com/image.jpg)",
        ],
        [
          "![alt text|100x200, 50%|thumbnail](https://example.com/image.jpg)",
          wrap(
            '<img src="https://example.com/image.jpg" alt="alt text" width="100" height="200" data-scale="50" data-thumbnail="true" style="width: 50px; height: 100px;">'
          ),
          "![alt text|100x200, 50%|thumbnail](https://example.com/image.jpg)",
        ],
        [
          "![alt text](https://example.com/image(1).jpg)",
          wrap('<img src="https://example.com/image(1).jpg" alt="alt text">'),
          "![alt text](https://example.com/image\\(1\\).jpg)",
        ],
        [
          "![alt text|video](uploads://hash)",
          '<p><div class="onebox-placeholder-container" contenteditable="false" draggable="true"><span class="placeholder-icon video"></span></div></p>',
          "![alt text|video](uploads://hash)",
        ],
        [
          "![alt text|audio](upload://hash)",
          '<p><audio preload="metadata" controls="false" tabindex="-1" contenteditable="false" draggable="true"><source data-orig-src="upload://hash"></audio></p>',
          "![alt text|audio](upload://hash)",
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
