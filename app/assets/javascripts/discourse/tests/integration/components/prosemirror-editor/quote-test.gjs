import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { testMarkdown } from "discourse/tests/helpers/rich-editor-helper";

module(
  "Integration | Component | prosemirror-editor - quote extension",
  function (hooks) {
    setupRenderingTest(hooks);

    Object.entries({
      "basic quote": [
        `[quote]\nThis is a quote.\n\n[/quote]\n\nThis is not`,
        `<aside class="quote" data-full="false"><blockquote><p>This is a quote.</p></blockquote></aside><p>This is not</p>`,
        `[quote]\nThis is a quote.\n\n[/quote]\n\nThis is not`,
      ],
      "quote with username": [
        `[quote="User"]\nQuoted text.\n\n[/quote]`,
        `<aside class="quote" data-username="User" data-full="false"><div class="title">User:</div><blockquote><p>Quoted text.</p></blockquote></aside>`,
        `[quote="User"]\nQuoted text.\n\n[/quote]\n\n`,
      ],
      "quote with topic ID": [
        `[quote="User, topic:456"]\nQuoted from a topic.\n\n[/quote]`,
        `<aside class="quote" data-username="User" data-topic="456" data-full="false"><div class="title">User:</div><blockquote><p>Quoted from a topic.</p></blockquote></aside>`,
        `[quote="User, topic:456"]\nQuoted from a topic.\n\n[/quote]\n\n`,
      ],
      "quote with topic ID and post number": [
        `[quote="User, post:123, topic:456"]\nFull quote example.\n\n[/quote]`,
        `<aside class="quote" data-username="User" data-post="123" data-topic="456" data-full="false"><div class="title">User:</div><blockquote><p>Full quote example.</p></blockquote></aside>`,
        `[quote="User, post:123, topic:456"]\nFull quote example.\n\n[/quote]\n\n`,
      ],
    }).forEach(([name, [markdown, html, expectedMarkdown]]) => {
      test(name, async function (assert) {
        this.siteSettings.rich_editor = true;
        await testMarkdown(assert, markdown, html, expectedMarkdown);
      });
    });
  }
);
