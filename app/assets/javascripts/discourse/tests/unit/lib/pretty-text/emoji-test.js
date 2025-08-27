import { setupTest } from "ember-qunit";
import { isSkinTonableEmoji } from "pretty-text/emoji";
import { module, test } from "qunit";

module("Unit | Pretty Text | Emoji", function (hooks) {
  setupTest(hooks);

  test("isSkinTonableEmoji", async function (assert) {
    assert.false(isSkinTonableEmoji(":smile:"));
    assert.false(isSkinTonableEmoji("smile"));
    assert.false(isSkinTonableEmoji("smile:t1"));
    assert.true(isSkinTonableEmoji(":woman_artist:"));
    assert.false(isSkinTonableEmoji(":woman_artist:t1:"));
  });
});
