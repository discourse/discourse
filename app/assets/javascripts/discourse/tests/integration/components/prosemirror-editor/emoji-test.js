import { IMAGE_VERSION as v } from "pretty-text/emoji/version";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { testMarkdown } from "discourse/tests/helpers/rich-editor-helper";

module(
  "Integration | Component | prosemirror-editor - emoji extension",
  function (hooks) {
    setupRenderingTest(hooks);

    const testCases = {
      emoji: [
        [
          "Hey :tada:!",
          `<p>Hey <img class="emoji" alt=":tada:" title=":tada:" src="/images/emoji/twitter/tada.png?v=${v}" contenteditable="false" draggable="true">!</p>`,
          "Hey :tada:!",
        ],
      ],
      "emoji in heading": [
        [
          "# Heading :information_source:",
          `<h1>Heading <img class="emoji" alt=":information_source:" title=":information_source:" src="/images/emoji/twitter/information_source.png?v=${v}" contenteditable="false" draggable="true"></h1>`,
          "# Heading :information_source:",
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
