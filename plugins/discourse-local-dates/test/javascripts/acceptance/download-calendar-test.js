import {
  acceptance,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import I18n from "I18n";
import { test } from "qunit";
import { fixturesByUrl } from "discourse/tests/helpers/create-pretender";
import sinon from "sinon";
import { cloneJSON } from "discourse-common/lib/object";

acceptance(
  "Local Dates - Download calendar without default calendar option set",
  function (needs) {
    needs.user({ "user_option.default_calendar": "none_selected" });
    needs.settings({ discourse_local_dates_enabled: true });
    needs.pretender((server, helper) => {
      const response = cloneJSON(fixturesByUrl["/t/281.json"]);
      const startDate = moment
        .tz("Africa/Cairo")
        .add(1, "days")
        .format("YYYY-MM-DD");
      response.post_stream.posts[0].cooked = `<p><span data-date=\"${startDate}\" data-time=\"13:00:00\" class=\"discourse-local-date\" data-timezone=\"Africa/Cairo\" data-email-preview=\"${startDate}T11:00:00Z UTC\">${startDate}T11:00:00Z</span></p>`;

      server.get("/t/281.json", () => helper.response(response));
    });

    test("Display pick calendar modal", async function (assert) {
      await visit("/t/local-dates/281");

      await click(".discourse-local-date");
      await click(document.querySelector(".download-calendar"));
      assert.strictEqual(
        query("#discourse-modal-title").textContent.trim(),
        I18n.t("download_calendar.title"),
        "it should display modal to select calendar"
      );
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
        .tz("Africa/Cairo")
        .subtract(1, "days")
        .format("YYYY-MM-DD");

      response.post_stream.posts[0].cooked = `<p><span data-date=\"${startDate}\" data-time=\"13:00:00\" class=\"discourse-local-date\" data-timezone=\"Africa/Cairo\" data-email-preview=\"${startDate}T11:00:00Z UTC\">${startDate}T11:00:00Z</span></p>`;

      server.get("/t/281.json", () => helper.response(response));
    });

    test("Does not show add to calendar button", async function (assert) {
      await visit("/t/local-dates/281");

      await click(".discourse-local-date");
      assert.ok(!exists(document.querySelector(".download-calendar")));
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
        .tz("Africa/Cairo")
        .add(1, "days")
        .format("YYYY-MM-DD");
      response.post_stream.posts[0].cooked = `<p><span data-date=\"${startDate}\" data-time=\"13:00:00\" class=\"discourse-local-date\" data-timezone=\"Africa/Cairo\" data-email-preview=\"${startDate}T11:00:00Z UTC\">${startDate}T11:00:00Z</span></p>`;
      response.title = "   title to trim   ";
      server.get("/t/281.json", () => helper.response(response));
    });

    needs.hooks.beforeEach(function () {
      let win = { focus: function () {} };
      sinon.stub(window, "open").returns(win);
      sinon.stub(win, "focus");
    });

    test("saves into default calendar", async function (assert) {
      const startDate = moment
        .tz("Africa/Cairo")
        .add(1, "days")
        .format("YYYYMMDD");
      await visit("/t/local-dates/281");

      await click(".discourse-local-date");
      await click(document.querySelector(".download-calendar"));
      assert.ok(!exists(document.querySelector("#discourse-modal-title")));
      assert.ok(
        window.open.calledWith(
          `https://www.google.com/calendar/event?action=TEMPLATE&text=title%20to%20trim&dates=${startDate}T110000Z/${startDate}T120000Z`,
          "_blank",
          "noopener",
          "noreferrer"
        )
      );
    });
  }
);
