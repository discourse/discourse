import { module, test } from "qunit";
import {
  bbcodeAttributeDecode,
  bbcodeAttributeEncode,
} from "discourse/lib/bbcode-attributes";

module("Unit | Local Dates | ICS Parameter", function () {
  test("encodes and decodes ICS data correctly", function (assert) {
    const testIcsData = `BEGIN:VCALENDAR
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

    const base64url = bbcodeAttributeEncode(testIcsData);

    assert.true(base64url.length > 0, "base64url encoding produces output");
    assert.false(
      base64url.includes("+"),
      "base64url does not contain + character"
    );
    assert.false(
      base64url.includes("/"),
      "base64url does not contain / character"
    );
    assert.false(
      base64url.includes("="),
      "base64url does not contain = character"
    );

    const decodedIcsData = bbcodeAttributeDecode(base64url);

    assert.strictEqual(
      decodedIcsData,
      testIcsData,
      "decoded ICS data matches original"
    );
  });

  test("handles UTF-8 characters in ICS data", function (assert) {
    const testIcsData = `BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Discourse//EN
BEGIN:VEVENT
UID:12345
SUMMARY:Test Event ????
DTSTART:20251201T120000Z
DTEND:20251201T130000Z
LOCATION:Caf? ?
DESCRIPTION:Testing ?mojis and sp?cial ?haracters
END:VEVENT
END:VCALENDAR`;

    const base64url = bbcodeAttributeEncode(testIcsData);
    const decodedIcsData = bbcodeAttributeDecode(base64url);

    assert.strictEqual(
      decodedIcsData,
      testIcsData,
      "UTF-8 characters are preserved through encoding/decoding"
    );
    assert.true(decodedIcsData.includes("??"), "emoji in title is preserved");
    assert.true(decodedIcsData.includes("?"), "emoji in location is preserved");
    assert.true(
      decodedIcsData.includes("?mojis"),
      "accented characters are preserved"
    );
  });

  test("extracts event title from ICS SUMMARY field", function (assert) {
    const testCases = [
      {
        ics: "BEGIN:VEVENT\nSUMMARY:My Event Name\nEND:VEVENT",
        expected: "My Event Name",
      },
      {
        ics: "BEGIN:VEVENT\nSUMMARY:Event with ?? emoji\nEND:VEVENT",
        expected: "Event with ?? emoji",
      },
      {
        ics: "BEGIN:VEVENT\nSUMMARY:   Trimmed Event   \nEND:VEVENT",
        expected: "Trimmed Event",
      },
    ];

    testCases.forEach((testCase) => {
      const summaryMatch = testCase.ics.match(/SUMMARY:(.+?)[\r\n]/);
      const title = summaryMatch ? summaryMatch[1].trim() : "event";
      assert.strictEqual(
        title,
        testCase.expected,
        `extracts "${testCase.expected}"`
      );
    });
  });

  test("cleans filename correctly", function (assert) {
    const testCases = [
      { input: "My Event Name", expected: "my-event-name" },
      { input: "Event with ?? emoji", expected: "event-with-emoji" },
      {
        input: "Special!@#$%^&*()chars",
        expected: "specialchars",
      },
      {
        input: "Multiple   Spaces",
        expected: "multiple-spaces",
      },
      {
        input: "Trailing-Dashes---",
        expected: "trailing-dashes",
      },
      {
        input:
          "Very Long Event Name That Exceeds Fifty Characters Total Length Here",
        expected: "very-long-event-name-that-exceeds-fifty-characters",
      },
    ];

    testCases.forEach((testCase) => {
      const cleaned = testCase.input
        .toLowerCase()
        .replace(/[^\w\s-]/g, "")
        .replace(/[\s_]+/g, "-")
        .replace(/^-+|-+$/g, "")
        .substring(0, 50);

      assert.strictEqual(
        cleaned,
        testCase.expected,
        `"${testCase.input}" -> "${testCase.expected}"`
      );
    });
  });
});
