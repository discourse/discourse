import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

acceptance("Post event - composer (rich editor)", function (needs) {
  needs.user({ admin: true, can_create_discourse_post_event: true });
  needs.settings({
    rich_editor: true,
    discourse_local_dates_enabled: true,
    discourse_calendar_enabled: true,
    discourse_post_event_enabled: true,
    discourse_post_event_allowed_on_groups: "",
    discourse_post_event_allowed_custom_fields: "",
  });

  test("inserts event block in rich editor", async function (assert) {
    await visit("/");
    await click("#create-topic");

    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);

    await click(".composer-toggle-switch");

    await click(".toolbar-menu__options-trigger");
    await click(
      `button[title='${i18n("discourse_post_event.builder_modal.attach")}']`
    );

    const modal = ".post-event-builder-modal";

    // Choose a deterministic date/time/timezone so we can assert attributes
    await fillIn(`${modal} .from input[type=date]`, "2022-07-01");
    const fromTime = selectKit(`${modal} .from .d-time-input .select-kit`);
    await fromTime.expand();
    await fromTime.selectRowByName("12:00");

    const toTime = selectKit(`${modal} .to .d-time-input .select-kit`);
    await fillIn(`${modal} .to input[type=date]`, "2022-07-01");
    await toTime.expand();
    await toTime.selectRowByName("13:00");

    const timezoneInput = selectKit(
      `${modal} .event-field.timezone .timezone-input`
    );
    await timezoneInput.expand();
    await timezoneInput.selectRowByValue("Europe/Paris");

    await click(`${modal} .d-modal__footer .btn-primary`);

    assert
      .dom(
        '.ProseMirror .discourse-post-event[data-start="2022-07-01 12:00"][data-timezone="Europe/Paris"]'
      )
      .exists("event preview block inserted in rich editor");
  });
});
