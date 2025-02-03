import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { testMarkdown } from "discourse/tests/helpers/rich-editor-helper";

module(
  "Integration | Component | prosemirror-editor - image extension",
  function (hooks) {
    setupRenderingTest(hooks);

    const testCases = {
      image: [
        [
          "![alt text](https://example.com/image.jpg)",
          '<p><img src="https://example.com/image.jpg" alt="alt text" data-thumbnail="false" contenteditable="false" draggable="true"></p>',
          "![alt text](https://example.com/image.jpg)",
        ],
        [
          "![alt text](https://example.com/image.jpg 'title')",
          '<p><img src="https://example.com/image.jpg" alt="alt text" title="title" data-thumbnail="false" contenteditable="false" draggable="true"></p>',
          '![alt text](https://example.com/image.jpg "title")',
        ],
        [
          '![alt text|100x200](https://example.com/image.jpg "title")',
          '<p><img src="https://example.com/image.jpg" alt="alt text" title="title" width="100" height="200" data-thumbnail="false" contenteditable="false" draggable="true"></p>',
          '![alt text|100x200](https://example.com/image.jpg "title")',
        ],
        [
          "![alt text|100x200, 50%](https://example.com/image.jpg)",
          '<p><img src="https://example.com/image.jpg" alt="alt text" width="50" height="100" data-thumbnail="false" data-scale="50" contenteditable="false" draggable="true"></p>',
          "![alt text|100x200, 50%](https://example.com/image.jpg)",
        ],
        [
          "![alt text|100x200, 50%|thumbnail](https://example.com/image.jpg)",
          '<p><img src="https://example.com/image.jpg" alt="alt text" width="50" height="100" data-thumbnail="true" data-scale="50" contenteditable="false" draggable="true"></p>',
          "![alt text|100x200, 50%|thumbnail](https://example.com/image.jpg)",
        ],
        [
          "![alt text](https://example.com/image(1).jpg)",
          '<p><img src="https://example.com/image(1).jpg" alt="alt text" data-thumbnail="false" contenteditable="false" draggable="true"></p>',
          "![alt text](https://example.com/image\\(1\\).jpg)",
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
