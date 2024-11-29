import { module, test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import toMarkdown from "discourse/lib/to-markdown";
import { initializeSpoiler } from "discourse/plugins/spoiler-alert/initializers/spoiler-alert";

module("Spoiler Alert | Unit | to-markdown", function (hooks) {
  hooks.beforeEach(function () {
    withPluginApi("0.5", initializeSpoiler);
  });

  test("handles spoiler tags", function (assert) {
    let html = `<div>Text with a</div><div class="spoiled spoiler-blurred">spoiled</div><div>word.</div>`;
    let markdown = `Text with a\n\n[spoiler]\nspoiled\n[/spoiler]\n\nword.`;

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
