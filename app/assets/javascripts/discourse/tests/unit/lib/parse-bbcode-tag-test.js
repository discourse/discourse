import { module, test } from "qunit";
import { parseBBCodeTag } from "pretty-text/engines/discourse-markdown/bbcode-block";

module("Unit | Utility | parseBBCodeTag", function () {
  test("block with multiple quoted attributes", function (assert) {
    const parsed = parseBBCodeTag('[test one="foo" two="bar bar"]', 0, 30);

    assert.strictEqual(parsed.tag, "test");
    assert.strictEqual(parsed.attrs.one, "foo");
    assert.strictEqual(parsed.attrs.two, "bar bar");
  });
});
