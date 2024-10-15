import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  query,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

acceptance("Local Dates - composer", function (needs) {
  needs.user();
  needs.settings({
    discourse_local_dates_enabled: true,
    discourse_local_dates_default_formats: "LLL|LTS|LL|LLLL",
  });

  test("composer bbcode", async function (assert) {
    const getAttr = (attr) => {
      return query(
        ".d-editor-preview .discourse-local-date.cooked-date"
      ).getAttribute(`data-${attr}`);
    };

    await visit("/");
    await click("#create-topic");
    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);

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
    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);
    await click(".d-editor-button-bar .local-dates");

    const timezoneChooser = selectKit(".timezone-input");
    await timezoneChooser.expand();
    await timezoneChooser.selectRowByValue("Asia/Macau");

    assert.ok(
      query(".preview .discourse-local-date").textContent.includes("Macau"),
      "it outputs a preview date in selected timezone"
    );
  });

  test("date modal - controls", async function (assert) {
    await visit("/");
    await click("#create-topic");
    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);
    await click(".d-editor-button-bar .local-dates");

    await click('.pika-table td[data-day="5"] > .pika-button');

    assert.ok(
      query("#from-date-time").textContent.includes("5,"),
      "selected FROM date works"
    );

    await click(".date-time-control.to .date-time");

    assert.strictEqual(
      queryAll(".pika-table .is-disabled").length,
      4,
      "date just before selected FROM date is disabled"
    );

    await click('.pika-table td[data-day="10"] > .pika-button');

    assert.ok(
      query(".date-time-control.to button").textContent.includes("10,"),
      "selected TO date works"
    );

    assert.strictEqual(
      query(".pika-table .is-selected").textContent,
      "10",
      "selected date is the 10th"
    );

    await click(".delete-to-date");

    assert.notOk(
      query(".date-time-control.to.is-selected"),
      "deleting selected TO date works"
    );

    await click(".advanced-mode-btn");

    assert.dom("input.format-input").hasValue("");
    await click("ul.formats a.moment-format");
    assert.dom("input.format-input").hasValue("LLL");
  });
});
