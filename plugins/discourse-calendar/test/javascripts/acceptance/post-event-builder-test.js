import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

acceptance("Post event - composer", function (needs) {
  needs.user({ admin: true, can_create_discourse_post_event: true });
  needs.settings({
    discourse_local_dates_enabled: true,
    discourse_calendar_enabled: true,
    discourse_post_event_enabled: true,
    discourse_post_event_allowed_on_groups: "",
    discourse_post_event_allowed_custom_fields: "",
  });

  test("composer event builder", async function (assert) {
    await visit("/");
    await click("#create-topic");
    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);
    await click(".toolbar-menu__options-trigger");
    await click(
      `button[title='${i18n("discourse_post_event.builder_modal.attach")}']`
    );

    // Toolbar inserts inline when the preview is visible; click the gear to
    // open the modal on the advanced screen.
    await click(".d-editor-preview .composer-event__more-dropdown button");

    const modal = ".post-event-builder-modal";

    const timezoneInput = selectKit(
      `${modal} [data-name="timezone"] .timezone-input`
    );
    await timezoneInput.expand();
    await timezoneInput.selectRowByValue("Europe/London");
    assert.strictEqual(
      timezoneInput.header().value(),
      "Europe/London",
      "Timezone can be changed"
    );

    await fillIn(`${modal} .from input[type=date]`, "2022-07-01");

    const fromTime = selectKit(`${modal} .from .d-time-input .select-kit`);
    await fromTime.expand();
    await fromTime.selectRowByName("12:00 PM");

    await fillIn(`${modal} .to input[type=date]`, "2022-07-01");
    const toTime = selectKit(`${modal} .to .d-time-input .select-kit`);
    await toTime.expand();
    await toTime.selectRowByName("1:00 PM");

    await timezoneInput.expand();
    await timezoneInput.selectRowByName("Europe/Paris");

    assert.strictEqual(fromTime.header().name(), "12:00 PM");
    assert.strictEqual(toTime.header().name(), "1:00 PM");

    await click(`${modal} .d-modal__footer .btn-primary`);

    assert
      .dom(".d-editor-input")
      .hasValue(
        `[event start="2022-07-01 12:00" status=public timezone=Europe/Paris end="2022-07-01 13:00" reminders=notification.15.minutes]\n[/event]`,
        "bbcode is correct"
      );
  });

  test("composer event builder - inline preview pre-populates defaults", async function (assert) {
    await visit("/");
    await click("#create-topic");
    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);
    await click(".toolbar-menu__options-trigger");
    await click(
      `button[title='${i18n("discourse_post_event.builder_modal.attach")}']`
    );

    const preview = ".d-editor-preview";

    assert
      .dom(`${preview} input.composer-event__date-input`)
      .hasAnyValue("start date is pre-populated in the inline preview editor");
    assert
      .dom(`${preview} input.composer-event__time-input`)
      .hasAnyValue("start time is pre-populated");
    assert
      .dom(`${preview} .composer-event__reminder-value`)
      .hasAnyValue("default reminder is pre-populated");
  });

  test("composer event builder - the timezone case", async function (assert) {
    await visit("/");

    // Freeze time
    const newTimezone = "Europe/Paris";
    const previousZone = moment.tz.guess();
    const now = moment.tz("2022-04-04 23:15", newTimezone).valueOf();
    sinon.useFakeTimers({
      now,
      toFake: ["Date"],
      shouldAdvanceTime: true,
      shouldClearNativeTimers: true,
    });
    sinon.stub(moment.tz, "guess");
    moment.tz.guess.returns(newTimezone);
    moment.tz.setDefault(newTimezone);

    try {
      await click("#create-topic");
      const categoryChooser = selectKit(".category-chooser");
      await categoryChooser.expand();
      await categoryChooser.selectRowByValue(2);

      await click(".toolbar-menu__options-trigger");
      await click(
        `button[title='${i18n("discourse_post_event.builder_modal.attach")}']`
      );

      // Toolbar inserts inline; click gear to open the modal on advanced.
      await click(".d-editor-preview .composer-event__more-dropdown button");

      const modal = ".post-event-builder-modal";

      // Select the date
      await fillIn(`${modal} .from input[type=date]`, "2022-07-01");

      // Select the timezone
      const timezoneInput = selectKit(
        `${modal} [data-name="timezone"] .timezone-input`
      );
      await timezoneInput.expand();
      await timezoneInput.selectRowByValue("Europe/London");

      // The date should be still the same?
      assert.dom(`${modal} .from input[type=date]`).hasValue("2022-07-01");
    } finally {
      // Unfreeze time
      moment.tz.guess.returns(previousZone);
      moment.tz.setDefault(previousZone);
      sinon.restore();
    }
  });
});

acceptance("Post event - composer - custom fields", function (needs) {
  needs.user({ admin: true, can_create_discourse_post_event: true });
  needs.settings({
    discourse_local_dates_enabled: true,
    discourse_calendar_enabled: true,
    discourse_post_event_enabled: true,
    discourse_post_event_allowed_on_groups: "",
    discourse_post_event_allowed_custom_fields: "fancy_field",
  });

  test("custom fields render and save", async function (assert) {
    await visit("/");
    await click("#create-topic");
    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);
    await click(".toolbar-menu__options-trigger");
    await click(
      `button[title='${i18n("discourse_post_event.builder_modal.attach")}']`
    );

    await click(".d-editor-preview .composer-event__more-dropdown button");

    const modal = ".post-event-builder-modal";

    assert
      .dom(`${modal} [data-name="customFields.fancy_field"] input`)
      .exists("the allowed custom field renders as a form field");

    await fillIn(`${modal} .from input[type=date]`, "2022-07-01");
    const fromTime = selectKit(`${modal} .from .d-time-input .select-kit`);
    await fromTime.expand();
    await fromTime.selectRowByName("12:00 PM");

    await fillIn(
      `${modal} [data-name="customFields.fancy_field"] input`,
      "hello world"
    );

    await click(`${modal} .d-modal__footer .btn-primary`);

    assert
      .dom(".d-editor-input")
      .hasValue(
        /fancyField="hello world"/,
        "the custom field is written to the event bbcode"
      );
  });
});
