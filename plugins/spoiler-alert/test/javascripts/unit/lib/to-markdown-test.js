import { module, test } from "qunit";
import {
  registerRichEditorExtension,
  resetRichEditorExtensions,
} from "discourse/lib/composer/rich-editor-extensions";
import toMarkdown from "discourse/lib/to-markdown";
import richEditorExtension from "discourse/plugins/spoiler-alert/lib/rich-editor-extension";

module("Spoiler Alert | Unit | to-markdown", function (hooks) {
  hooks.beforeEach(async function () {
    await resetRichEditorExtensions();
    registerRichEditorExtension(richEditorExtension);
  });

  test("handles spoiler tags", function (assert) {
    let html = `<div>Text with a</div><div class="spoiled spoiler-blurred">spoiled</div><div>word.</div>`;
    // ProseMirror serializes block content with trailing newlines
    let markdown = `Text with a\n\n[spoiler]\nspoiled\n\n[/spoiler]\n\nword.`;

    assert.strictEqual(toMarkdown(html), markdown, "creates block spoiler tag");

    html = `Inline <span class="spoiled">spoiled</span> word.`;
    markdown = `Inline [spoiler]spoiled[/spoiler] word.`;
    assert.strictEqual(
      toMarkdown(html),
      markdown,
      "creates inline spoiler tag"
    );
  });
});
