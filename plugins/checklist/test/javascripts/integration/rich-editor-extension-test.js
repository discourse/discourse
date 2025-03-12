import { module, test } from "qunit";
import {
  registerRichEditorExtension,
  resetRichEditorExtensions,
} from "discourse/lib/composer/rich-editor-extensions";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { testMarkdown } from "discourse/tests/helpers/rich-editor-helper";
import richEditorExtension from "discourse/plugins/checklist/lib/rich-editor-extension";

module(
  "Integration | Component | prosemirror-editor - checklist plugin extension",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.siteSettings.rich_editor = true;

      resetRichEditorExtensions().then(() => {
        registerRichEditorExtension(richEditorExtension);
      });
    });

    const checked =
      '<span class="chcklst-box checked fa fa-square-check-o fa-fw" contenteditable="false" draggable="true"></span>';
    const unchecked =
      '<span class="chcklst-box fa fa-square-o fa-fw" contenteditable="false" draggable="true"></span>';

    Object.entries({
      "renders unchecked checkbox correctly": [
        "[ ] todo item",
        `<p>${unchecked} todo item</p>`,
        "[ ] todo item",
      ],
      "renders checked checkbox correctly": [
        "[x] completed item",
        `<p>${checked} completed item</p>`,
        "[x] completed item",
      ],
      "handles multiple checkboxes in a single paragraph": [
        "[] first task [x] second task",
        `<p>${unchecked} first task ${checked} second task</p>`,
        "[ ] first task [x] second task",
      ],
      "handles checkboxes in lists": [
        "* [ ] unchecked list item\n* [x] checked list item",
        `<ul data-tight="true"><li><p>${unchecked} unchecked list item</p></li><li><p>${checked} checked list item</p></li></ul>`,
        "* [ ] unchecked list item\n* [x] checked list item",
      ],
      "handles checkboxes with formatting": [
        "[ ] *italics* and [x] **bold**",
        `<p>${unchecked} <em>italics</em> and ${checked} <strong>bold</strong></p>`,
        "[ ] *italics* and [x] **bold**",
      ],
    }).forEach(([name, [markdown, html, expectedMarkdown]]) => {
      test(name, async function (assert) {
        await testMarkdown(assert, markdown, html, expectedMarkdown);
      });
    });
  }
);
