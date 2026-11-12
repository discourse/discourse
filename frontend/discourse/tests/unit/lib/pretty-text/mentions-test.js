import { setupTest } from "ember-qunit";
import { mentionRegex } from "pretty-text/mentions";
import { module, test } from "qunit";

module("Unit | Pretty Text | Mentions", function (hooks) {
  setupTest(hooks);

  test("mentionRegex matches ASCII usernames", function (assert) {
    const regex = mentionRegex(false);

    assert.strictEqual("hi @sam!".match(regex)[1], "sam");
    assert.strictEqual(
      "hi @a".match(regex)[2],
      "a",
      "captures a one-letter name in the second group"
    );
    assert.strictEqual(
      "@sam.smith_".match(regex)[1],
      "sam.smith",
      "does not end a name with an underscore"
    );
    assert.strictEqual("@ゆう".match(regex), null, "ignores non-ASCII names");
  });

  test("mentionRegex matches Unicode usernames when enabled", function (assert) {
    const regex = mentionRegex(true);

    assert.strictEqual("hi @ゆう!".match(regex)[1], "ゆう");
    assert.strictEqual("@é".match(regex)[2], "é");
    assert.strictEqual(
      "@sam_".match(regex)[1],
      "sam",
      "does not end a name with an underscore"
    );
  });
});
