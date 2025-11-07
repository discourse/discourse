import { module, test } from "qunit";
import {
  bbcodeAttributeDecode,
  bbcodeAttributeEncode,
} from "discourse/lib/bbcode-attributes";
import { generateIcsData } from "discourse/lib/download-calendar";

module("Unit | Discourse Calendar | ICS Generation", function () {
  test("generates valid ICS data", function (assert) {
    const title = "Test Event";
    const dates = [
      {
        startsAt: "2025-12-01T12:00:00Z",
        endsAt: "2025-12-01T13:00:00Z",
      },
    ];
    const options = {};

    const icsData = generateIcsData(title, dates, options);

    assert.true(icsData.includes("BEGIN:VCALENDAR"), "contains VCALENDAR");
    assert.true(icsData.includes("VERSION:2.0"), "contains version");
    assert.true(icsData.includes("BEGIN:VEVENT"), "contains VEVENT");
    assert.true(icsData.includes("SUMMARY:Test Event"), "contains title");
    assert.true(icsData.includes("DTSTART:"), "contains start time");
    assert.true(icsData.includes("DTEND:"), "contains end time");
    assert.true(icsData.includes("END:VEVENT"), "closes VEVENT");
    assert.true(icsData.includes("END:VCALENDAR"), "closes VCALENDAR");
  });

  test("includes location when provided", function (assert) {
    const title = "Test Event";
    const dates = [
      {
        startsAt: "2025-12-01T12:00:00Z",
        endsAt: "2025-12-01T13:00:00Z",
      },
    ];
    const options = { location: "Test Location" };

    const icsData = generateIcsData(title, dates, options);

    assert.true(
      icsData.includes("LOCATION:Test Location"),
      "includes location"
    );
  });

  test("includes description when provided", function (assert) {
    const title = "Test Event";
    const dates = [
      {
        startsAt: "2025-12-01T12:00:00Z",
        endsAt: "2025-12-01T13:00:00Z",
      },
    ];
    const options = { details: "Test Description" };

    const icsData = generateIcsData(title, dates, options);

    assert.true(
      icsData.includes("DESCRIPTION:Test Description"),
      "includes description"
    );
  });

  test("includes recurrence rule when provided", function (assert) {
    const title = "Test Event";
    const dates = [
      {
        startsAt: "2025-12-01T12:00:00Z",
        endsAt: "2025-12-01T13:00:00Z",
      },
    ];
    const options = { rrule: "FREQ=WEEKLY;BYDAY=MO" };

    const icsData = generateIcsData(title, dates, options);

    assert.true(
      icsData.includes("RRULE:FREQ=WEEKLY;BYDAY=MO"),
      "includes rrule"
    );
  });

  test("handles multiple dates", function (assert) {
    const title = "Test Event";
    const dates = [
      {
        startsAt: "2025-12-01T12:00:00Z",
        endsAt: "2025-12-01T13:00:00Z",
      },
      {
        startsAt: "2025-12-08T12:00:00Z",
        endsAt: "2025-12-08T13:00:00Z",
      },
    ];
    const options = {};

    const icsData = generateIcsData(title, dates, options);

    const eventCount = (icsData.match(/BEGIN:VEVENT/g) || []).length;
    assert.strictEqual(eventCount, 2, "creates two VEVENT blocks");
  });

  test("handles emoji and special characters in event details", function (assert) {
    const title = "Test Event ????";
    const dates = [
      {
        startsAt: "2025-12-01T12:00:00Z",
        endsAt: "2025-12-01T13:00:00Z",
      },
    ];
    const options = {
      location: "Caf? ?",
      details: "Testing ?mojis and sp?cial ?haracters",
    };

    const icsData = generateIcsData(title, dates, options);

    assert.true(icsData.includes("??"), "preserves emoji in title");
    assert.true(icsData.includes("?"), "preserves emoji in location");
    assert.true(icsData.includes("?mojis"), "preserves accented characters");
  });

  test("generates valid base64url encoding", function (assert) {
    const title = "Test Event";
    const dates = [
      {
        startsAt: "2025-12-01T12:00:00Z",
        endsAt: "2025-12-01T13:00:00Z",
      },
    ];
    const options = { location: "Test+Location/With=Special" };

    const icsData = generateIcsData(title, dates, options);
    const base64url = bbcodeAttributeEncode(icsData);

    assert.false(
      base64url.includes("+"),
      "base64url encoding replaces + with -"
    );
    assert.false(
      base64url.includes("/"),
      "base64url encoding replaces / with _"
    );
    assert.false(
      base64url.includes("="),
      "base64url encoding replaces = with ~"
    );
    assert.true(base64url.length > 0, "produces non-empty output");

    const decoded = bbcodeAttributeDecode(base64url);
    assert.strictEqual(
      decoded,
      icsData,
      "can decode back to original ICS data"
    );
  });

  test("uses CRLF line endings", function (assert) {
    const title = "Test Event";
    const dates = [
      {
        startsAt: "2025-12-01T12:00:00Z",
        endsAt: "2025-12-01T13:00:00Z",
      },
    ];
    const options = {};

    const icsData = generateIcsData(title, dates, options);

    assert.true(icsData.includes("\r\n"), "contains CRLF line endings");
    assert.false(/(?<!\r)\n/.test(icsData), "does not contain LF without CR");
    assert.true(icsData.startsWith("BEGIN:VCALENDAR\r\n"), "starts with CRLF");
    assert.true(icsData.endsWith("END:VCALENDAR"), "ends correctly");
  });

  test("folds long lines correctly", function (assert) {
    const longTitle = "A".repeat(100);
    const dates = [
      {
        startsAt: "2025-12-01T12:00:00Z",
        endsAt: "2025-12-01T13:00:00Z",
      },
    ];
    const options = {};

    const icsData = generateIcsData(longTitle, dates, options);

    const summaryLine = icsData.match(/SUMMARY:[^\r\n]*(?:\r\n [^\r\n]*)*/)[0];
    const lines = summaryLine.split("\r\n");

    assert.true(lines.length > 1, "long SUMMARY is folded into multiple lines");
    for (let i = 1; i < lines.length; i++) {
      assert.true(
        lines[i].startsWith(" "),
        `continuation line ${i} starts with space`
      );
    }
    lines.forEach((line, i) => {
      if (i < lines.length - 1) {
        assert.true(
          line.length <= 75,
          `line ${i} does not exceed 75 characters`
        );
      }
    });
  });

  test("omits RRULE when FREQ is missing", function (assert) {
    const title = "Test Event";
    const dates = [
      {
        startsAt: "2025-12-01T12:00:00Z",
        endsAt: "2025-12-01T13:00:00Z",
      },
    ];
    const options = { rrule: "BYDAY=MO,TU,WE" };

    const icsData = generateIcsData(title, dates, options);

    assert.false(
      icsData.includes("RRULE:"),
      "RRULE is omitted when FREQ is missing"
    );
  });

  test("includes RRULE when FREQ is present", function (assert) {
    const title = "Test Event";
    const dates = [
      {
        startsAt: "2025-12-01T12:00:00Z",
        endsAt: "2025-12-01T13:00:00Z",
      },
    ];
    const options = { rrule: "FREQ=WEEKLY;BYDAY=MO" };

    const icsData = generateIcsData(title, dates, options);

    assert.true(
      icsData.includes("RRULE:FREQ=WEEKLY;BYDAY=MO"),
      "RRULE is included when FREQ is present"
    );
  });

  test("parses legacy RRULE format with DTSTART", function (assert) {
    const title = "Test Event";
    const dates = [
      {
        startsAt: "2025-12-01T12:00:00Z",
        endsAt: "2025-12-01T13:00:00Z",
      },
    ];
    const options = {
      rrule: "DTSTART:20251201T120000Z\nRRULE:FREQ=WEEKLY;BYDAY=SU",
    };

    const icsData = generateIcsData(title, dates, options);

    const rruleCount = (icsData.match(/^RRULE:/gm) || []).length;
    assert.strictEqual(rruleCount, 1, "only one RRULE line in output");

    assert.true(
      icsData.includes("RRULE:FREQ=WEEKLY;BYDAY=SU"),
      "includes RRULE with FREQ"
    );

    assert.false(
      icsData.includes("RRULE:DTSTART"),
      "does not include DTSTART in RRULE line"
    );

    assert.true(
      icsData.includes("DTSTART:20251201T120000Z"),
      "DTSTART is a separate line"
    );
  });

  test("handles RRULE with RRULE: prefix", function (assert) {
    const title = "Test Event";
    const dates = [
      {
        startsAt: "2025-12-01T12:00:00Z",
        endsAt: "2025-12-01T13:00:00Z",
      },
    ];
    const options = { rrule: "RRULE:FREQ=DAILY;INTERVAL=2" };

    const icsData = generateIcsData(title, dates, options);

    const rruleCount = (icsData.match(/^RRULE:/gm) || []).length;
    assert.strictEqual(rruleCount, 1, "only one RRULE line in output");

    assert.true(
      icsData.includes("RRULE:FREQ=DAILY;INTERVAL=2"),
      "RRULE is properly formatted"
    );
  });

  test("omits RRULE when only DTSTART provided", function (assert) {
    const title = "Test Event";
    const dates = [
      {
        startsAt: "2025-12-01T12:00:00Z",
        endsAt: "2025-12-01T13:00:00Z",
      },
    ];
    const options = { rrule: "DTSTART:20251201T120000Z" };

    const icsData = generateIcsData(title, dates, options);

    assert.false(
      icsData.includes("RRULE:"),
      "RRULE is omitted when no FREQ present"
    );
  });

  test("handles long description with folding", function (assert) {
    const title = "Test Event";
    const dates = [
      {
        startsAt: "2025-12-01T12:00:00Z",
        endsAt: "2025-12-01T13:00:00Z",
      },
    ];
    const longDescription =
      "This is a very long description that exceeds the 75 character limit for ICS files and should be properly folded";
    const options = { details: longDescription };

    const icsData = generateIcsData(title, dates, options);

    assert.true(icsData.includes("DESCRIPTION:"), "includes DESCRIPTION field");

    const descriptionLine = icsData.match(
      /DESCRIPTION:[^\r\n]*(?:\r\n [^\r\n]*)*/
    )[0];
    const lines = descriptionLine.split("\r\n");

    assert.true(
      lines.length > 1,
      "long DESCRIPTION is folded into multiple lines"
    );
    for (let i = 1; i < lines.length; i++) {
      assert.true(
        lines[i].startsWith(" "),
        `continuation line ${i} starts with space`
      );
    }
  });

  test("handles long location with folding", function (assert) {
    const title = "Test Event";
    const dates = [
      {
        startsAt: "2025-12-01T12:00:00Z",
        endsAt: "2025-12-01T13:00:00Z",
      },
    ];
    const longLocation =
      "A very long location name that will definitely exceed the 75 character limit set by the ICS specification";
    const options = { location: longLocation };

    const icsData = generateIcsData(title, dates, options);

    assert.true(icsData.includes("LOCATION:"), "includes LOCATION field");

    const locationLine = icsData.match(
      /LOCATION:[^\r\n]*(?:\r\n [^\r\n]*)*/
    )[0];
    const lines = locationLine.split("\r\n");

    assert.true(
      lines.length > 1,
      "long LOCATION is folded into multiple lines"
    );
    for (let i = 1; i < lines.length; i++) {
      assert.true(
        lines[i].startsWith(" "),
        `continuation line ${i} starts with space`
      );
    }
  });

  test("escapes newlines in description", function (assert) {
    const title = "Test Event";
    const dates = [
      {
        startsAt: "2025-12-01T12:00:00Z",
        endsAt: "2025-12-01T13:00:00Z",
      },
    ];
    const options = { details: "Line 1\nLine 2\nLine 3" };

    const icsData = generateIcsData(title, dates, options);

    assert.true(
      icsData.includes("DESCRIPTION:Line 1\\nLine 2\\nLine 3"),
      "newlines are escaped as \\n in description"
    );
    assert.false(
      /DESCRIPTION:[^\r]*\n(?! )/.test(icsData),
      "no unescaped newlines in description value"
    );
  });

  test("escapes newlines in title", function (assert) {
    const title = "Multi\nLine\nTitle";
    const dates = [
      {
        startsAt: "2025-12-01T12:00:00Z",
        endsAt: "2025-12-01T13:00:00Z",
      },
    ];
    const options = {};

    const icsData = generateIcsData(title, dates, options);

    assert.true(
      icsData.includes("SUMMARY:Multi\\nLine\\nTitle"),
      "newlines are escaped as \\n in title"
    );
  });

  test("escapes newlines in location", function (assert) {
    const title = "Test Event";
    const dates = [
      {
        startsAt: "2025-12-01T12:00:00Z",
        endsAt: "2025-12-01T13:00:00Z",
      },
    ];
    const options = { location: "Building A\nRoom 101" };

    const icsData = generateIcsData(title, dates, options);

    assert.true(
      icsData.includes("LOCATION:Building A\\nRoom 101"),
      "newlines are escaped as \\n in location"
    );
  });

  test("escapes CRLF newlines", function (assert) {
    const title = "Test Event";
    const dates = [
      {
        startsAt: "2025-12-01T12:00:00Z",
        endsAt: "2025-12-01T13:00:00Z",
      },
    ];
    const options = { details: "Line 1\r\nLine 2\r\nLine 3" };

    const icsData = generateIcsData(title, dates, options);

    assert.true(
      icsData.includes("DESCRIPTION:Line 1\\nLine 2\\nLine 3"),
      "CRLF newlines are escaped as \\n"
    );
  });

  test("escapes CR newlines", function (assert) {
    const title = "Test Event";
    const dates = [
      {
        startsAt: "2025-12-01T12:00:00Z",
        endsAt: "2025-12-01T13:00:00Z",
      },
    ];
    const options = { details: "Line 1\rLine 2\rLine 3" };

    const icsData = generateIcsData(title, dates, options);

    assert.true(
      icsData.includes("DESCRIPTION:Line 1\\nLine 2\\nLine 3"),
      "CR newlines are escaped as \\n"
    );
  });

  test("escapes semicolons in field values", function (assert) {
    const title = "Event; with semicolons;";
    const dates = [
      {
        startsAt: "2025-12-01T12:00:00Z",
        endsAt: "2025-12-01T13:00:00Z",
      },
    ];
    const options = {
      location: "Room; A",
      details: "Important; details; here",
    };

    const icsData = generateIcsData(title, dates, options);

    assert.true(
      icsData.includes("SUMMARY:Event\\; with semicolons\\;"),
      "semicolons are escaped in title"
    );
    assert.true(
      icsData.includes("LOCATION:Room\\; A"),
      "semicolons are escaped in location"
    );
    assert.true(
      icsData.includes("DESCRIPTION:Important\\; details\\; here"),
      "semicolons are escaped in description"
    );
  });

  test("escapes commas in field values", function (assert) {
    const title = "Event, with commas,";
    const dates = [
      {
        startsAt: "2025-12-01T12:00:00Z",
        endsAt: "2025-12-01T13:00:00Z",
      },
    ];
    const options = {
      location: "City, State",
      details: "Item 1, Item 2, Item 3",
    };

    const icsData = generateIcsData(title, dates, options);

    assert.true(
      icsData.includes("SUMMARY:Event\\, with commas\\,"),
      "commas are escaped in title"
    );
    assert.true(
      icsData.includes("LOCATION:City\\, State"),
      "commas are escaped in location"
    );
    assert.true(
      icsData.includes("DESCRIPTION:Item 1\\, Item 2\\, Item 3"),
      "commas are escaped in description"
    );
  });

  test("escapes backslashes in field values", function (assert) {
    const title = "Path\\to\\event";
    const dates = [
      {
        startsAt: "2025-12-01T12:00:00Z",
        endsAt: "2025-12-01T13:00:00Z",
      },
    ];
    const options = {
      location: "C:\\Users\\Name",
      details: "File: C:\\Documents\\file.txt",
    };

    const icsData = generateIcsData(title, dates, options);

    assert.true(
      icsData.includes("SUMMARY:Path\\\\to\\\\event"),
      "backslashes are escaped in title"
    );
    assert.true(
      icsData.includes("LOCATION:C:\\\\Users\\\\Name"),
      "backslashes are escaped in location"
    );
    assert.true(
      icsData.includes("DESCRIPTION:File: C:\\\\Documents\\\\file.txt"),
      "backslashes are escaped in description"
    );
  });

  test("handles mixed special characters", function (assert) {
    const title = "Test Event";
    const dates = [
      {
        startsAt: "2025-12-01T12:00:00Z",
        endsAt: "2025-12-01T13:00:00Z",
      },
    ];
    const options = {
      details: "Line 1\\path\nLine 2; with semicolon\nLine 3, with comma",
    };

    const icsData = generateIcsData(title, dates, options);

    assert.true(
      icsData.includes(
        "DESCRIPTION:Line 1\\\\path\\nLine 2\\; with semicolon\\nLine 3\\, wit" +
          "h comma"
      ),
      "multiple special characters are properly escaped"
    );
  });
});
