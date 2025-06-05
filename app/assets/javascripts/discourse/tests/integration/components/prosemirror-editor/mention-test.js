import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { testMarkdown } from "discourse/tests/helpers/rich-editor-helper";

module(
  "Integration | Component | prosemirror-editor - mention extension",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      pretender.get("/u/john.json", () => {
        return response(404);
      });
    });

    const testCases = {
      mention: [
        "@eviltrout",
        '<p><a class="mention" data-name="eviltrout" contenteditable="false" draggable="true">@eviltrout</a></p>',
        "@eviltrout",
      ],
      "text with mention": [
        "Hello @eviltrout",
        '<p>Hello <a class="mention" data-name="eviltrout" contenteditable="false" draggable="true">@eviltrout</a></p>',
        "Hello @eviltrout",
      ],
      "mention after heading": [
        "## Hello\n\n@eviltrout",
        '<h2>Hello</h2><p><a class="mention" data-name="eviltrout" contenteditable="false" draggable="true">@eviltrout</a></p>',
        "## Hello\n\n@eviltrout",
      ],
      "invalid mention": [
        "Hello @john, how are you?",
        "<p>Hello @john, how are you?</p>",
        "Hello @john, how are you?",
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
