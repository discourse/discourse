import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { testMarkdown } from "discourse/tests/helpers/rich-editor-helper";

module("Integration | Component | rich-editor-extension", function (hooks) {
  setupRenderingTest(hooks);

  const testCases = {
    "event alone": [
      [
        `[event start="2025-03-21 15:41" status="public" timezone="Europe/Paris"]\n[/event]\n`,
        (assert) => {
          assert
            .dom(".composer-event-node")
            .exists("Event node should be rendered");
          assert
            .dom(".composer-event__status")
            .hasText("Public", "Status should be displayed");
          assert
            .dom(".composer-event__date-display")
            .exists("Date should be displayed");
        },
        `[event start="2025-03-21 15:41" status=public timezone=Europe/Paris]\n[/event]\n`,
      ],
    ],
    "event with content around": [
      [
        `Hello world\n\n[event start="2025-03-21 15:41" status="public" timezone="Europe/Paris"]\n[/event]\nGoodbye world`,
        (assert) => {
          assert
            .dom("p")
            .exists({ count: 2 }, "Should have paragraphs around event");
          assert
            .dom(".composer-event-node")
            .exists("Event node should be rendered");
          assert
            .dom(".composer-event__status")
            .hasText("Public", "Status should be displayed");
        },
        `Hello world\n\n[event start="2025-03-21 15:41" status=public timezone=Europe/Paris]\n[/event]\nGoodbye world`,
      ],
    ],
    "event with content inside": [
      [
        `[event start="2025-03-21 15:41" status="public" timezone="Europe/Paris"]\ntest\n[/event]\n`,
        (assert) => {
          assert
            .dom(".composer-event-node")
            .exists("Event node should be rendered");
          assert
            .dom(".composer-event__status")
            .hasText("Public", "Status should be displayed");
        },
        `[event start="2025-03-21 15:41" status=public timezone=Europe/Paris]\ntest\n\n[/event]\n`,
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
