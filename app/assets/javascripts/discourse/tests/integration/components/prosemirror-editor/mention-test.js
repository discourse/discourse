import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { testMarkdown } from "discourse/tests/helpers/rich-editor-helper";

module(
  "Integration | Component | prosemirror-editor - mention extension",
  function (hooks) {
    setupRenderingTest(hooks);

    const testCases = {
      mention: [
        "@hello",
        '<p><a class="mention" data-name="hello" contenteditable="false" draggable="true">@hello</a></p>',
        "@hello",
      ],
      "text with mention": [
        "Hello @dude",
        '<p>Hello <a class="mention" data-name="dude" contenteditable="false" draggable="true">@dude</a></p>',
        "Hello @dude",
      ],
      "mention after heading": [
        "## Hello\n\n@dude",
        '<h2>Hello</h2><p><a class="mention" data-name="dude" contenteditable="false" draggable="true">@dude</a></p>',
        "## Hello\n\n@dude",
      ],
    };

    Object.entries(testCases).forEach(
      ([name, [markdown, expectedHtml, expectedMarkdown]]) => {
        test(name, async function (assert) {
          this.siteSettings.rich_editor = true;

          await testMarkdown(assert, markdown, expectedHtml, expectedMarkdown);
        });
      }
    );
  }
);
