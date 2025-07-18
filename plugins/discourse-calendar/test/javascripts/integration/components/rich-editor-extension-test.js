import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { testMarkdown } from "discourse/tests/helpers/rich-editor-helper";

module("Integration | Component | rich-editor-extension", function (hooks) {
  setupRenderingTest(hooks);

  const testCases = {
    "event alone": [
      [
        `[event start="2025-03-21 15:41" status="public" timezone="Europe/Paris" allowedGroups="trust_level_0"]\n[/event]\n`,
        `<div class="discourse-post-event discourse-post-event-preview ProseMirror-selectednode" data-start="2025-03-21 15:41" data-status="public" data-timezone="Europe/Paris" data-allowed-groups="trust_level_0" contenteditable="false" draggable="true"><div class="event-preview-status">Public</div><div class="event-preview-dates"><span class="start">March 21, 2025 2:41 PM</span></div></div>`,
        `[event start="2025-03-21 15:41" status="public" timezone="Europe/Paris" allowedGroups="trust_level_0"]\n[/event]\n`,
      ],
    ],
    "event with content around": [
      [
        `Hello world\n\n[event start="2025-03-21 15:41" status="public" timezone="Europe/Paris" allowedGroups="trust_level_0"]\n[/event]\nGoodbye world`,
        `<p>Hello world</p><div class="discourse-post-event discourse-post-event-preview" data-start="2025-03-21 15:41" data-status="public" data-timezone="Europe/Paris" data-allowed-groups="trust_level_0" contenteditable="false" draggable="true"><div class="event-preview-status">Public</div><div class="event-preview-dates"><span class="start">March 21, 2025 2:41 PM</span></div></div><p>Goodbye world</p>`,
        `Hello world\n\n[event start="2025-03-21 15:41" status="public" timezone="Europe/Paris" allowedGroups="trust_level_0"]\n[/event]\nGoodbye world`,
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
});
