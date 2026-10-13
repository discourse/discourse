import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import { cloneJSON } from "discourse/lib/object";
import { fixturesByUrl } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance(
  "Download calendar without default calendar option set",
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

      assert.form().field("calendar").hasValue("ics");
      assert
        .dom('[data-name="calendar"] input[type="radio"]')
        .exists({ count: 4 });
      assert.form().field("remember").exists();
    });
  }
);

acceptance("Download calendar as an anonymous user", function (needs) {
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

    assert.form().field("calendar").hasValue("ics");
    assert.form().field("remember").doesNotExist();
  });
});

acceptance(
  "Download calendar is not available for dates in the past",
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
  "Download calendar with default calendar option set",
  function (needs) {
    needs.user({ "user_option.default_calendar": "outlook" });
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
        const [url, target, ...features] = arguments;
        const link = new URL(url);

        assert.strictEqual(
          link.origin + link.pathname,
          "https://outlook.live.com/calendar/0/deeplink/compose"
        );
        assert.strictEqual(
          link.searchParams.get("startdt"),
          `${moment(startDate, "YYYYMMDD").format("YYYY-MM-DD")}T18:00:00.000Z`
        );
        assert.strictEqual(target, "_blank");
        assert.deepEqual(features, ["noopener", "noreferrer"]);
        return { focus() {} };
      });

      await click(".discourse-local-date");
      await click(".download-calendar");

      assert.dom("#discourse-modal-title").doesNotExist();
    });
  }
);
