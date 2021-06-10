import { acceptance, queryAll } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";

acceptance("Local Dates - composer", function (needs) {
  needs.user();
  needs.settings({ discourse_local_dates_enabled: true });

  test("composer bbcode", async function (assert) {
    const getAttr = (attr) => {
      return queryAll(
        ".d-editor-preview .discourse-local-date.cooked-date"
      ).attr(`data-${attr}`);
    };

    await visit("/");
    await click("#create-topic");

    await fillIn(
      ".d-editor-input",
      '[date=2017-10-23 time=01:30:00 displayedTimezone="America/Chicago" format="LLLL" calendar="off" recurring="1.weeks" timezone=" Asia/Calcutta" timezones="Europe/Paris|America/Los_Angeles"]'
    );

    assert.equal(getAttr("date"), "2017-10-23", "it has the correct date");
    assert.equal(getAttr("time"), "01:30:00", "it has the correct time");
    assert.equal(
      getAttr("displayed-timezone"),
      "America/Chicago",
      "it has the correct displayed timezone"
    );
    assert.equal(getAttr("format"), "LLLL", "it has the correct format");
    assert.equal(
      getAttr("timezones"),
      "Europe/Paris|America/Los_Angeles",
      "it has the correct timezones"
    );
    assert.equal(
      getAttr("recurring"),
      "1.weeks",
      "it has the correct recurring"
    );
    assert.equal(
      getAttr("timezone"),
      "Asia/Calcutta",
      "it has the correct timezone"
    );

    await fillIn(
      ".d-editor-input",
      '[date=2017-10-24 format="LL" timezone="Asia/Calcutta" timezones="Europe/Paris|America/Los_Angeles"]'
    );

    assert.equal(getAttr("date"), "2017-10-24", "it has the correct date");
    assert.notOk(getAttr("time"), "it doesn’t have time");
  });
});
