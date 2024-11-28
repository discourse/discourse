import { click, fillIn, triggerKeyEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  metaModifier,
} from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

acceptance("Local Dates - composer", function (needs) {
  needs.user();
  needs.settings({
    discourse_local_dates_enabled: true,
    discourse_local_dates_default_formats: "LLL|LTS|LL|LLLL",
  });

  test("composer bbcode", async function (assert) {
    await visit("/");
    await click("#create-topic");
    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);

    await fillIn(
      ".d-editor-input",
      '[date=2017-10-23 time=01:30:00 displayedTimezone="America/Chicago" format="LLLL" calendar="off" recurring="1.weeks" timezone=" Asia/Calcutta" timezones="Europe/Paris|America/Los_Angeles"]'
    );

    assert
      .dom(".d-editor-preview .discourse-local-date.cooked-date")
      .hasAttribute("data-date", "2017-10-23", "has the correct date");
    assert
      .dom(".d-editor-preview .discourse-local-date.cooked-date")
      .hasAttribute("data-time", "01:30:00", "has the correct time");
    assert
      .dom(".d-editor-preview .discourse-local-date.cooked-date")
      .hasAttribute(
        "data-displayed-timezone",
        "America/Chicago",
        "has the correct displayed timezone"
      );
    assert
      .dom(".d-editor-preview .discourse-local-date.cooked-date")
      .hasAttribute("data-format", "LLLL", "has the correct format");
    assert
      .dom(".d-editor-preview .discourse-local-date.cooked-date")
      .hasAttribute(
        "data-timezones",
        "Europe/Paris|America/Los_Angeles",
        "has the correct timezones"
      );
    assert
      .dom(".d-editor-preview .discourse-local-date.cooked-date")
      .hasAttribute("data-recurring", "1.weeks", "has the correct recurring");
    assert
      .dom(".d-editor-preview .discourse-local-date.cooked-date")
      .hasAttribute(
        "data-timezone",
        "Asia/Calcutta",
        "has the correct timezone"
      );

    await fillIn(
      ".d-editor-input",
      '[date=2017-10-24 format="LL" timezone="Asia/Calcutta" timezones="Europe/Paris|America/Los_Angeles"]'
    );

    assert
      .dom(".d-editor-preview .discourse-local-date.cooked-date")
      .hasAttribute("data-date", "2017-10-24", "has the correct date");
    assert
      .dom(".d-editor-preview .discourse-local-date.cooked-date")
      .doesNotHaveAttribute("data-time", "doesn’t have time");
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

    assert
      .dom(".preview .discourse-local-date")
      .includesText("Macau", "outputs a preview date in selected timezone");
  });

  test("date modal - controls", async function (assert) {
    await visit("/");
    await click("#create-topic");
    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);
    await click(".d-editor-button-bar .local-dates");

    await click('.pika-table td[data-day="5"] > .pika-button');

    assert
      .dom("#from-date-time")
      .includesText("5,", "selected FROM date works");

    await click(".date-time-control.to .date-time");

    assert
      .dom(".pika-table .is-disabled")
      .exists({ count: 4 }, "date just before selected FROM date is disabled");

    await click('.pika-table td[data-day="10"] > .pika-button');

    assert
      .dom(".date-time-control.to button")
      .includesText("10,", "selected TO date works");

    assert
      .dom(".pika-table .is-selected")
      .hasText("10", "selected date is the 10th");

    await click(".delete-to-date");

    assert
      .dom(".date-time-control.to.is-selected")
      .doesNotExist("deleting selected TO date works");

    await click(".advanced-mode-btn");

    assert.dom("input.format-input").hasValue("");
    await click("ul.formats a.moment-format");
    assert.dom("input.format-input").hasValue("LLL");
  });

  test("composer insert current time shortcut", async function (assert) {
    await visit("/t/internationalization-localization/280");

    await click("#topic-footer-buttons .btn.create");
    assert.dom(".d-editor-input").exists("the composer input is visible");
    await fillIn(".d-editor-input", "and the time now is: ");

    const date = moment().format("YYYY-MM-DD");

    await triggerKeyEvent(".d-editor-input", "keydown", ".", {
      ...metaModifier,
      shiftKey: true,
    });

    assert
      .dom("#reply-control .d-editor-input")
      .hasValue(
        new RegExp(`and the time now is: \\[date=${date}`),
        "it adds the current date"
      );
  });
});
