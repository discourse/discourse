import { acceptance, query } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { click, fillIn, visit } from "@ember/test-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

acceptance("Local Dates - composer", function (needs) {
  needs.user();
  needs.settings({ discourse_local_dates_enabled: true });

  test("composer bbcode", async function (assert) {
    const getAttr = (attr) => {
      return query(
        ".d-editor-preview .discourse-local-date.cooked-date"
      ).getAttribute(`data-${attr}`);
    };

    await visit("/");
    await click("#create-topic");

    await fillIn(
      ".d-editor-input",
      '[date=2017-10-23 time=01:30:00 displayedTimezone="America/Chicago" format="LLLL" calendar="off" recurring="1.weeks" timezone=" Asia/Calcutta" timezones="Europe/Paris|America/Los_Angeles"]'
    );

    assert.strictEqual(
      getAttr("date"),
      "2017-10-23",
      "it has the correct date"
    );
    assert.strictEqual(getAttr("time"), "01:30:00", "it has the correct time");
    assert.strictEqual(
      getAttr("displayed-timezone"),
      "America/Chicago",
      "it has the correct displayed timezone"
    );
    assert.strictEqual(getAttr("format"), "LLLL", "it has the correct format");
    assert.strictEqual(
      getAttr("timezones"),
      "Europe/Paris|America/Los_Angeles",
      "it has the correct timezones"
    );
    assert.strictEqual(
      getAttr("recurring"),
      "1.weeks",
      "it has the correct recurring"
    );
    assert.strictEqual(
      getAttr("timezone"),
      "Asia/Calcutta",
      "it has the correct timezone"
    );

    await fillIn(
      ".d-editor-input",
      '[date=2017-10-24 format="LL" timezone="Asia/Calcutta" timezones="Europe/Paris|America/Los_Angeles"]'
    );

    assert.strictEqual(
      getAttr("date"),
      "2017-10-24",
      "it has the correct date"
    );
    assert.notOk(getAttr("time"), "it doesn’t have time");
  });

  test("date modal", async function (assert) {
    await visit("/");
    await click("#create-topic");
    await click(".d-editor-button-bar .local-dates");

    const timezoneChooser = selectKit(".timezone-input");
    await timezoneChooser.expand();
    await timezoneChooser.selectRowByValue("Asia/Macau");

    assert.ok(
      query(".preview .discourse-local-date").textContent.includes("Macau"),
      "it outputs a preview date in selected timezone"
    );
  });
});
