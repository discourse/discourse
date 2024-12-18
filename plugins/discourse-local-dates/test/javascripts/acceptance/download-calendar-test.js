import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import { fixturesByUrl } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { cloneJSON } from "discourse-common/lib/object";
import { i18n } from "discourse-i18n";

acceptance(
  "Local Dates - Download calendar without default calendar option set",
  function (needs) {
    needs.user({ "user_option.default_calendar": "none_selected" });
    needs.settings({ discourse_local_dates_enabled: true });
    needs.pretender((server, helper) => {
      const response = cloneJSON(fixturesByUrl["/t/281.json"]);
      const startDate = moment
        .tz("America/Lima")
        .add(1, "days")
        .format("YYYY-MM-DD");
      response.post_stream.posts[0].cooked = `<p><span data-date=\"${startDate}\" data-time=\"13:00:00\" class=\"discourse-local-date\" data-timezone=\"America/Lima\" data-email-preview=\"${startDate}T18:00:00Z UTC\">${startDate}T18:00:00Z</span></p>`;

      server.get("/t/281.json", () => helper.response(response));
    });

    test("Display pick calendar modal", async function (assert) {
      await visit("/t/local-dates/281");
      await click(".discourse-local-date");
      await click(".download-calendar");

      assert
        .dom("#discourse-modal-title")
        .hasText(
          i18n("download_calendar.title"),
          "it should display modal to select calendar"
        );

      assert.dom(".control-group.remember").exists();
    });
  }
);

acceptance(
  "Local Dates - Download calendar as an anonymous user",
  function (needs) {
    needs.settings({ discourse_local_dates_enabled: true });
    needs.pretender((server, helper) => {
      const response = cloneJSON(fixturesByUrl["/t/281.json"]);
      const startDate = moment
        .tz("America/Lima")
        .add(1, "days")
        .format("YYYY-MM-DD");
      response.post_stream.posts[0].cooked = `<p><span data-date=\"${startDate}\" data-time=\"13:00:00\" class=\"discourse-local-date\" data-timezone=\"America/Lima\" data-email-preview=\"${startDate}T18:00:00Z UTC\">${startDate}T18:00:00Z</span></p>`;

      server.get("/t/281.json", () => helper.response(response));
    });

    test("Display pick calendar modal", async function (assert) {
      await visit("/t/local-dates/281");
      await click(".discourse-local-date");
      await click(".download-calendar");

      assert
        .dom("#discourse-modal-title")
        .hasText(
          i18n("download_calendar.title"),
          "it should display modal to select calendar"
        );

      assert.dom(".control-group.remember").doesNotExist();
    });
  }
);

acceptance(
  "Local Dates - Download calendar is not available for dates in the past",
  function (needs) {
    needs.user({ "user_option.default_calendar": "none_selected" });
    needs.settings({ discourse_local_dates_enabled: true });
    needs.pretender((server, helper) => {
      const response = cloneJSON(fixturesByUrl["/t/281.json"]);
      const startDate = moment
        .tz("America/Lima")
        .subtract(1, "days")
        .format("YYYY-MM-DD");

      response.post_stream.posts[0].cooked = `<p><span data-date=\"${startDate}\" data-time=\"13:00:00\" class=\"discourse-local-date\" data-timezone=\"America/Lima\" data-email-preview=\"${startDate}T18:00:00Z UTC\">${startDate}T18:00:00Z</span></p>`;

      server.get("/t/281.json", () => helper.response(response));
    });

    test("Does not show add to calendar button", async function (assert) {
      await visit("/t/local-dates/281");
      await click(".discourse-local-date");

      assert.dom(".download-calendar").doesNotExist();
    });
  }
);

acceptance(
  "Local Dates - Download calendar with default calendar option set",
  function (needs) {
    needs.user({ "user_option.default_calendar": "google" });
    needs.settings({ discourse_local_dates_enabled: true });
    needs.pretender((server, helper) => {
      const response = cloneJSON(fixturesByUrl["/t/281.json"]);
      const startDate = moment
        .tz("America/Lima")
        .add(1, "days")
        .format("YYYY-MM-DD");
      response.post_stream.posts[0].cooked = `<p><span data-date=\"${startDate}\" data-time=\"13:00:00\" class=\"discourse-local-date\" data-timezone=\"America/Lima\" data-email-preview=\"${startDate}T18:00:00Z UTC\">${startDate}T18:00:00Z</span></p>`;
      response.title = "   title to trim   ";
      server.get("/t/281.json", () => helper.response(response));
    });

    test("saves into default calendar", async function (assert) {
      const startDate = moment
        .tz("America/Lima")
        .add(1, "days")
        .format("YYYYMMDD");
      await visit("/t/local-dates/281");

      sinon.stub(window, "open").callsFake(function () {
        assert.deepEqual(
          [...arguments],
          [
            `https://www.google.com/calendar/event?action=TEMPLATE&text=title+to+trim&dates=${startDate}T180000Z%2F${startDate}T190000Z`,
            "_blank",
            "noopener",
            "noreferrer",
          ]
        );
        return { focus() {} };
      });

      await click(".discourse-local-date");
      await click(".download-calendar");

      assert.dom("#discourse-modal-title").doesNotExist();
    });
  }
);
