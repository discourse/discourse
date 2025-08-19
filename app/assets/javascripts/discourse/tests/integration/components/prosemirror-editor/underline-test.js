import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { testMarkdown } from "discourse/tests/helpers/rich-editor-helper";

module(
  "Integration | Component | prosemirror-editor - underline extension",
  function (hooks) {
    setupRenderingTest(hooks);

    const testCases = {
      underline: [
        ["[u]Hello[/u]", "<p><u>Hello</u></p>", "[u]Hello[/u]"],
        [
          "Hello [u]World[/u]",
          "<p>Hello <u>World</u></p>",
          "Hello [u]World[/u]",
        ],
        [
          "[u]Hello[/u] [u]World[/u]",
          "<p><u>Hello</u> <u>World</u></p>",
          "[u]Hello[/u] [u]World[/u]",
        ],
      ],
      "with other marks": [
        [
          "___[u][`Hello`](https://example.com)[/u]___",
          '<p><em><strong><u><a href="https://example.com"><code>Hello</code></a></u></strong></em></p>',
          "***[u][`Hello`](https://example.com)[/u]***",
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
