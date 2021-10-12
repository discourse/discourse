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

acceptance(
  "Local Dates - Download calendar without default calendar option set",
  function (needs) {
    needs.user({ default_calendar: "none_selected" });
    needs.settings({ discourse_local_dates_enabled: true });
    needs.pretender((server, helper) => {
      const response = { ...fixturesByUrl["/t/281.json"] };
      server.get("/t/281.json", () => helper.response(response));
    });

    test("Display pick calendar modal", async function (assert) {
      await visit("/t/local-dates/281");

      await click(".discourse-local-date");
      await click(document.querySelector(".download-calendar"));
      assert.equal(
        query("#discourse-modal-title").textContent.trim(),
        I18n.t("download_calendar.title"),
        "it should display modal to select calendar"
      );
    });
  }
);

acceptance(
  "Local Dates - Download calendar with default calendar option set",
  function (needs) {
    needs.user({ default_calendar: "google" });
    needs.settings({ discourse_local_dates_enabled: true });
    needs.pretender((server, helper) => {
      const response = { ...fixturesByUrl["/t/281.json"] };
      server.get("/t/281.json", () => helper.response(response));
    });

    needs.hooks.beforeEach(function () {
      let win = { focus: function () {} };
      sinon.stub(window, "open").returns(win);
      sinon.stub(win, "focus");
    });

    test("saves into default calendar", async function (assert) {
      await visit("/t/local-dates/281");

      await click(".discourse-local-date");
      await click(document.querySelector(".download-calendar"));
      assert.ok(!exists(document.querySelector("#discourse-modal-title")));
      assert.ok(
        window.open.calledWith(
          "https://www.google.com/calendar/event?action=TEMPLATE&text=Local%20dates&dates=20210930T110000Z/20210930T120000Z",
          "_blank",
          "noopener",
          "noreferrer"
        )
      );
    });
  }
);
