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
        "Hey :tada:!",
        `<p>Hey <img class="emoji" alt=":tada:" title=":tada:" src="/images/emoji/twitter/tada.png?v=${v}" contenteditable="false" draggable="true">!</p>`,
        "Hey :tada:!",
      ],
      "emoji in heading": [
        "# Heading :information_source:",
        `<h1>Heading <img class="emoji" alt=":information_source:" title=":information_source:" src="/images/emoji/twitter/information_source.png?v=${v}" contenteditable="false" draggable="true"></h1>`,
        "# Heading :information_source:",
      ],
      "emoji after a heading": [
        "# Heading\n\n:tada:",
        `<h1>Heading</h1><p><img class="emoji only-emoji" alt=":tada:" title=":tada:" src="/images/emoji/twitter/tada.png?v=${v}" contenteditable="false" draggable="true"></p>`,
        "# Heading\n\n:tada:",
      ],
      "single emoji in paragraph gets only-emoji class": [
        ":tada:",
        `<p><img class="emoji only-emoji" alt=":tada:" title=":tada:" src="/images/emoji/twitter/tada.png?v=${v}" contenteditable="false" draggable="true"></p>`,
        ":tada:",
      ],
      "three emojis in paragraph get only-emoji class": [
        ":tada: :smile: :heart:",
        `<p><img class="emoji only-emoji" alt=":tada:" title=":tada:" src="/images/emoji/twitter/tada.png?v=${v}" contenteditable="false" draggable="true"> <img class="emoji only-emoji" alt=":smile:" title=":smile:" src="/images/emoji/twitter/smile.png?v=${v}" contenteditable="false" draggable="true"> <img class="emoji only-emoji" alt=":heart:" title=":heart:" src="/images/emoji/twitter/heart.png?v=${v}" contenteditable="false" draggable="true"></p>`,
        ":tada: :smile: :heart:",
      ],
      "more than three emojis don't get only-emoji class": [
        ":tada: :smile: :heart: :+1:",
        `<p><img class="emoji" alt=":tada:" title=":tada:" src="/images/emoji/twitter/tada.png?v=${v}" contenteditable="false" draggable="true"> <img class="emoji" alt=":smile:" title=":smile:" src="/images/emoji/twitter/smile.png?v=${v}" contenteditable="false" draggable="true"> <img class="emoji" alt=":heart:" title=":heart:" src="/images/emoji/twitter/heart.png?v=${v}" contenteditable="false" draggable="true"> <img class="emoji" alt=":+1:" title=":+1:" src="/images/emoji/twitter/+1.png?v=${v}" contenteditable="false" draggable="true"></p>`,
        ":tada: :smile: :heart: :+1:",
      ],
      "emoji with text doesn't get only-emoji class": [
        "Hello :tada:",
        `<p>Hello <img class="emoji" alt=":tada:" title=":tada:" src="/images/emoji/twitter/tada.png?v=${v}" contenteditable="false" draggable="true"></p>`,
        "Hello :tada:",
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
