import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import { fixturesByUrl } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance(
  "Local Dates - Download calendar with embedded ICS data",
  function (needs) {
    needs.user({ "user_option.default_calendar": "none_selected" });
    needs.settings({ discourse_local_dates_enabled: true });
    needs.pretender((server, helper) => {
      const response = cloneJSON(fixturesByUrl["/t/281.json"]);
      const startDate = moment
        .tz("America/Lima")
        .add(1, "days")
        .format("YYYY-MM-DD");

      // Create sample ICS data
      const icsData = `BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Discourse//EN
BEGIN:VEVENT
UID:test123
DTSTAMP:20251201T000000Z
DTSTART:20251201T130000Z
DTEND:20251201T140000Z
SUMMARY:Test Event from Calendar
LOCATION:Test Location
DESCRIPTION:Test Description
END:VEVENT
END:VCALENDAR`;

      // Encode ICS data as base64url
      const utf8Bytes = new TextEncoder().encode(icsData);
      const binaryString = Array.from(utf8Bytes, (byte) =>
        String.fromCharCode(byte)
      ).join("");
      const base64 = btoa(binaryString);
      const base64url = base64
        .replace(/\+/g, "-")
        .replace(/\//g, "_")
        .replace(/=/g, "~");

      response.post_stream.posts[0].cooked = `<p><span data-date="${startDate}" data-time="13:00:00" class="discourse-local-date" data-timezone="America/Lima" data-ics="${base64url}" data-email-preview="${startDate}T18:00:00Z UTC">${startDate}T18:00:00Z</span></p>`;

      server.get("/t/281.json", () => helper.response(response));
    });

    test("Downloads ICS file with embedded data", async function (assert) {
      await visit("/t/local-dates/281");
      await click(".discourse-local-date");

      assert
        .dom(".download-calendar")
        .exists("download calendar button is present");

      // We can't fully test the download without mocking File/Blob APIs
      // but we can verify the button has the data-ics attribute
      const downloadButton = document.querySelector(".download-calendar");
      assert.true(
        !!downloadButton.dataset.ics,
        "download button has data-ics attribute"
      );
      assert.true(
        downloadButton.dataset.ics.length > 0,
        "data-ics attribute is not empty"
      );
      assert.false(downloadButton.dataset.ics.includes("+"), "data-ics uses base64url encoding (no +)");
      assert.false(downloadButton.dataset.ics.includes("/"), "data-ics uses base64url encoding (no /)");
    });
  }
);

acceptance(
  "Local Dates - Falls back to default ICS generation without embedded data",
  function (needs) {
    needs.user({ "user_option.default_calendar": "none_selected" });
    needs.settings({ discourse_local_dates_enabled: true });
    needs.pretender((server, helper) => {
      const response = cloneJSON(fixturesByUrl["/t/281.json"]);
      const startDate = moment
        .tz("America/Lima")
        .add(1, "days")
        .format("YYYY-MM-DD");

      // No data-ics attribute - should fall back to default behavior
      response.post_stream.posts[0].cooked = `<p><span data-date="${startDate}" data-time="13:00:00" class="discourse-local-date" data-timezone="America/Lima" data-email-preview="${startDate}T18:00:00Z UTC">${startDate}T18:00:00Z</span></p>`;

      server.get("/t/281.json", () => helper.response(response));
    });

    test("Shows download button without data-ics attribute", async function (assert) {
      await visit("/t/local-dates/281");
      await click(".discourse-local-date");

      assert
        .dom(".download-calendar")
        .exists("download calendar button is present");

      const downloadButton = document.querySelector(".download-calendar");
      assert.false(
        !!downloadButton.dataset.ics,
        "download button has no data-ics attribute"
      );
      assert.true(
        !!downloadButton.dataset.startsAt,
        "download button has data-starts-at for fallback"
      );
    });
  }
);
