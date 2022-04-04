import {
  acceptance,
  fakeTime,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import I18n from "I18n";

acceptance("Admin - Silence User", function (needs) {
  let clock = null;
  needs.user();

  needs.hooks.beforeEach(() => {
    const timezone = moment.tz.guess();
    clock = fakeTime("2100-05-03T08:00:00", timezone, true); // Monday morning
  });

  needs.hooks.afterEach(() => {
    clock.restore();
  });

  test("shows correct timeframe options", async function (assert) {
    await visit("/admin/users/1234/regular");
    await click(".silence-user");
    await click(".future-date-input-selector-header");

    const options = Array.from(
      queryAll(`ul.select-kit-collection li span.name`).map((_, x) =>
        x.innerText.trim()
      )
    );

    const expected = [
      I18n.t("topic.auto_update_input.later_today"),
      I18n.t("topic.auto_update_input.tomorrow"),
      I18n.t("topic.auto_update_input.later_this_week"),
      I18n.t("topic.auto_update_input.next_week"),
      I18n.t("topic.auto_update_input.two_weeks"),
      I18n.t("topic.auto_update_input.next_month"),
      I18n.t("topic.auto_update_input.two_months"),
      I18n.t("topic.auto_update_input.three_months"),
      I18n.t("topic.auto_update_input.four_months"),
      I18n.t("topic.auto_update_input.six_months"),
      I18n.t("topic.auto_update_input.one_year"),
      I18n.t("topic.auto_update_input.forever"),
      I18n.t("topic.auto_update_input.pick_date_and_time"),
    ];

    assert.deepEqual(options, expected, "options are correct");
  });
});
