import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { testMarkdown } from "discourse/tests/helpers/rich-editor-helper";

module(
  "Integration | Component | prosemirror-editor - strikethrough extension",
  function (hooks) {
    setupRenderingTest(hooks);

    const testCases = {
      strikethrough: [
        ["[s]Hello[/s]", "<p><s>Hello</s></p>", "~~Hello~~"],
        ["~~Hello~~", "<p><s>Hello</s></p>", "~~Hello~~"],
        [
          "Hey [s]wrod[/s] ~~uord~~ World",
          "<p>Hey <s>wrod</s> <s>uord</s> World</p>",
          "Hey ~~wrod~~ ~~uord~~ World",
        ],
      ],
      "with other marks": [
        [
          "___[s][`Hello`](https://example.com)[/s]___",
          '<p><em><strong><s><a href="https://example.com"><code>Hello</code></a></s></strong></em></p>',
          "***~~[`Hello`](https://example.com)~~***",
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
