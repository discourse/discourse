import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { generateCookFunction } from "discourse/lib/text";

const chatOptions = {
  limited_pretty_text_features: ["bbcode-block", "chat-transcript"],
  limited_pretty_text_markdown_rules: ["newline"],
  hashtag_configurations: { "chat-composer": [] },
};
const transcript = `[chat quote="alice;101;2023-12-01T21:10:53Z"]
First line
Second line
[/chat]`;

function buildCook({
  traditionalLinebreaks,
  additionalOptions = { chat: chatOptions },
}) {
  return generateCookFunction({
    siteSettings: {
      chat_enabled: true,
      traditional_markdown_linebreaks: traditionalLinebreaks,
    },
    additionalOptions,
  });
}

module("Unit | Lib | chat-transcript", function (hooks) {
  setupTest(hooks);

  test("isolates transcript cooking per renderer", async function (assert) {
    const cookWithBreaks = await buildCook({ traditionalLinebreaks: false });
    const cookWithoutBreaks = await buildCook({ traditionalLinebreaks: true });
    const cookWithoutOptions = await buildCook({ additionalOptions: {} });

    assert.true(
      cookWithBreaks(transcript).includes("<p>First line<br>\nSecond line</p>"),
      "keeps the first renderer's line-break setting"
    );
    assert.true(
      cookWithoutBreaks(transcript).includes("<p>First line\nSecond line</p>"),
      "keeps the second renderer's line-break setting"
    );
    assert.false(
      cookWithoutOptions(transcript).includes('class="chat-transcript"'),
      "a renderer without Chat options does not borrow another's cook function"
    );
  });
});
