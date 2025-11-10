import { module, test } from "qunit";
import {
  bbcodeAttributeDecode,
  bbcodeAttributeEncode,
} from "discourse/lib/bbcode-attributes";

module("Unit | Utility | bbcode-attributes", function () {
  test("bbcodeAttributeEncode converts string to base64url format", function (assert) {
    const input = "Hello World";
    const encoded = bbcodeAttributeEncode(input);

    assert.true(encoded.length > 0, "produces non-empty output");
    assert.false(encoded.includes("+"), "does not contain + character");
    assert.false(encoded.includes("/"), "does not contain / character");
    assert.false(encoded.includes("="), "does not contain = character");
  });

  test("bbcodeAttributeDecode reverses the encoding", function (assert) {
    const original = "Hello World";
    const encoded = bbcodeAttributeEncode(original);
    const decoded = bbcodeAttributeDecode(encoded);

    assert.strictEqual(
      decoded,
      original,
      "decoded value matches original string"
    );
  });

  test("handles UTF-8 characters correctly", function (assert) {
    const testCases = [
      "Hello 世界",
      "Café ☕",
      "Testing émojis 🎉🎊",
      "Special chars: äöüß",
      "Cyrillic: Привет",
      "Arabic: مرحبا",
    ];

    testCases.forEach((testCase) => {
      const encoded = bbcodeAttributeEncode(testCase);
      const decoded = bbcodeAttributeDecode(encoded);

      assert.strictEqual(
        decoded,
        testCase,
        `UTF-8 characters preserved: "${testCase}"`
      );
    });
  });

  test("handles ICS calendar data", function (assert) {
    const icsData = `BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Discourse//EN
BEGIN:VEVENT
UID:12345
SUMMARY:Test Event
DTSTART:20251201T120000Z
DTEND:20251201T130000Z
LOCATION:Test Location
DESCRIPTION:Test Description
END:VEVENT
END:VCALENDAR`;

    const encoded = bbcodeAttributeEncode(icsData);
    const decoded = bbcodeAttributeDecode(encoded);

    assert.strictEqual(decoded, icsData, "ICS data preserved through encoding");
    assert.true(decoded.includes("BEGIN:VCALENDAR"), "contains VCALENDAR");
    assert.true(decoded.includes("Test Event"), "contains event title");
  });

  test("handles empty strings", function (assert) {
    const encoded = bbcodeAttributeEncode("");
    const decoded = bbcodeAttributeDecode(encoded);

    assert.strictEqual(decoded, "", "empty string is preserved");
  });

  test("handles long strings", function (assert) {
    const longString = "A".repeat(10000);
    const encoded = bbcodeAttributeEncode(longString);
    const decoded = bbcodeAttributeDecode(encoded);

    assert.strictEqual(
      decoded.length,
      10000,
      "long string length is preserved"
    );
    assert.strictEqual(decoded, longString, "long string content is preserved");
  });

  test("handles strings with special BBCode characters", function (assert) {
    const testCases = [
      "Text with [brackets]",
      "Text with = equals",
      "Text with + plus",
      "Text with / slash",
      "Text with ~tilde~",
      "Mixed: [tag=value] with+special/chars~",
    ];

    testCases.forEach((testCase) => {
      const encoded = bbcodeAttributeEncode(testCase);
      const decoded = bbcodeAttributeDecode(encoded);

      assert.strictEqual(
        decoded,
        testCase,
        `Special characters preserved: "${testCase}"`
      );
    });
  });

  test("encoded output is URL-safe", function (assert) {
    const testStrings = [
      "Test with spaces",
      "Test+with+plus",
      "Test/with/slashes",
      "Test=with=equals",
    ];

    testStrings.forEach((testString) => {
      const encoded = bbcodeAttributeEncode(testString);

      assert.false(
        encoded.includes(" "),
        `"${testString}" encoded without spaces`
      );
      assert.false(encoded.includes("+"), `"${testString}" encoded without +`);
      assert.false(encoded.includes("/"), `"${testString}" encoded without /`);
      assert.false(encoded.includes("="), `"${testString}" encoded without =`);
    });
  });

  test("handles multiline strings", function (assert) {
    const multiline = `Line 1
Line 2
Line 3`;

    const encoded = bbcodeAttributeEncode(multiline);
    const decoded = bbcodeAttributeDecode(encoded);

    assert.strictEqual(decoded, multiline, "multiline text preserved");
    assert.true(decoded.includes("\n"), "newlines preserved");
  });
});
