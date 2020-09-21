import { parseBBCodeTag } from "pretty-text/engines/discourse-markdown/bbcode-block";

function parseTag(bbcodeTag) {
  return parseBBCodeTag(bbcodeTag, 0, bbcodeTag.length);
}

QUnit.module("lib:pretty-text:bbcode");

QUnit.test("block with multiple quoted attributes", (assert) => {
  const parsed = parseTag(`[test one="foo" two='bar bar']`);

  assert.equal(parsed.tag, "test");
  assert.equal(parsed.attrs.one, "foo");
  assert.equal(parsed.attrs.two, "bar bar");
});

QUnit.test("default attribute value", (assert) => {
  const parsed = parseTag("[test='foo bar']");

  assert.equal(parsed.tag, "test");
  assert.equal(parsed.attrs._default, "foo bar");
});

// This is not supported because it conflicts with
// the quoteless default attribute syntax:
// [test=some random =) text]
QUnit.skip("default and additional attributes", (assert) => {
  const parsed = parseTag(`[date=2018-09-17 time=01:39:00 format="LLL"]`);

  assert.equal(parsed.tag, "date");
  assert.equal(parsed.attrs._default, "2018-09-17");
  assert.equal(parsed.attrs.time, "01:39:00");
  assert.equal(parsed.attrs.format, "LLL");
});

QUnit.test("quote characters inside a another quotes", (assert) => {
  const parsed = parseTag(`[test one="foo's" two='“bar”' three=“"abc's"”]`);

  assert.equal(parsed.tag, "test");
  assert.equal(parsed.attrs.one, "foo's");
  assert.equal(parsed.attrs.two, "“bar”");
  assert.equal(parsed.attrs.three, `"abc's"`);
});
