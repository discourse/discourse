import { module, test } from "qunit";
import {
  registerRichEditorExtension,
  resetRichEditorExtensions,
} from "discourse/lib/composer/rich-editor-extensions";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { testMarkdown } from "discourse/tests/helpers/rich-editor-helper";
import richEditorExtension from "discourse/plugins/spoiler-alert/lib/rich-editor-extension";

module(
  "Integration | Component | prosemirror-editor - spoiler plugin extension",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.siteSettings.rich_editor = true;

      resetRichEditorExtensions().then(() => {
        registerRichEditorExtension(richEditorExtension);
      });
    });

    Object.entries({
      "inline spoiler": [
        "Hey [spoiler]did you know the good guys die[/spoiler] in the end?",
        '<p>Hey <span class="spoiled">did you know the good guys die</span> in the end?</p>',
        "Hey [spoiler]did you know the good guys die[/spoiler] in the end?",
      ],
      "block spoiler": [
        "hey\n\n[spoiler]\n> did you know the good guys die\n\n[/spoiler]\n\nin the end?",
        '<p>hey</p><div class="spoiled"><blockquote><p>did you know the good guys die</p></blockquote></div><p>in the end?</p>',
        "hey\n\n[spoiler]\n> did you know the good guys die\n\n[/spoiler]\n\nin the end?",
      ],
    }).forEach(([name, [markdown, html, expectedMarkdown]]) => {
      test(name, async function (assert) {
        await testMarkdown(assert, markdown, html, expectedMarkdown);
      });
    });
  }
);
