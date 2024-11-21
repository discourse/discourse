import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  fakeTime,
  loggedInUser,
  query,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

acceptance("Admin - Suspend User", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.put("/admin/users/:user_id/suspend", () =>
      helper.response(200, {
        suspension: {
          suspended_till: "2099-01-01T12:00:00.000Z",
        },
      })
    );

    server.put("/admin/users/:user_id/unsuspend", () =>
      helper.response(200, {
        suspension: {
          suspended_till: null,
        },
      })
    );
  });

  test("suspend a user - cancel", async function (assert) {
    await visit("/admin/users/1234/regular");
    await click(".suspend-user");

    assert.dom(".suspend-user-modal").exists();

    await click(".d-modal-cancel");

    assert.dom(".suspend-user-modal").doesNotExist();
  });

  test("suspend a user - cancel with input", async function (assert) {
    await visit("/admin/users/1234/regular");
    await click(".suspend-user");

    assert.dom(".suspend-user-modal").exists();

    await fillIn("input.suspend-reason", "for breaking the rules");
    await fillIn(".suspend-message", "this is an email reason why");

    await click(".d-modal-cancel");

    assert.dom(".dialog-body").exists();

    await click(".dialog-footer .btn-default");
    assert.dom(".suspend-user-modal").exists();
    assert.strictEqual(
      query(".suspend-message").value,
      "this is an email reason why"
    );

    await click(".d-modal-cancel");
    assert.dom(".dialog-body").exists();

    await click(".dialog-footer .btn-primary");
    assert.dom(".suspend-user-modal").doesNotExist();
    assert.dom(".dialog-body").doesNotExist();
  });

  test("suspend, then unsuspend a user", async function (assert) {
    const suspendUntilCombobox = selectKit(".suspend-until .combobox");

    await visit("/admin/flags/active");

    await visit("/admin/users/1234/regular");

    assert.dom(".suspension-info").doesNotExist();

    await click(".suspend-user");

    assert.dom(".perform-penalize").isDisabled("disabled by default");

    await suspendUntilCombobox.expand();
    await suspendUntilCombobox.selectRowByValue("tomorrow");

    await fillIn("input.suspend-reason", "for breaking the rules");
    await fillIn(".suspend-message", "this is an email reason why");

    assert.dom(".perform-penalize").isEnabled("no longer disabled");

    await click(".perform-penalize");

    assert.dom(".suspend-user-modal").doesNotExist();
    assert.dom(".suspension-info").exists();

    await click(".unsuspend-user");

    assert.dom(".suspension-info").doesNotExist();
  });
});

acceptance("Admin - Suspend User - timeframe choosing", function (needs) {
  let clock = null;
  needs.user();

  needs.hooks.beforeEach(() => {
    const timezone = loggedInUser().user_option.timezone;
    clock = fakeTime("2100-05-03T08:00:00", timezone, true); // Monday morning
  });

  needs.hooks.afterEach(() => {
    clock.restore();
  });

  test("shows correct timeframe options", async function (assert) {
    await visit("/admin/users/1234/regular");
    await click(".suspend-user");
    await click(".future-date-input-selector-header");

    const options = Array.from(
      queryAll(`ul.select-kit-collection li span.name`)
    ).map((el) => el.innerText.trim());

    const expected = [
      i18n("time_shortcut.later_today"),
      i18n("time_shortcut.tomorrow"),
      i18n("time_shortcut.later_this_week"),
      i18n("time_shortcut.start_of_next_business_week_alt"),
      i18n("time_shortcut.two_weeks"),
      i18n("time_shortcut.next_month"),
      i18n("time_shortcut.two_months"),
      i18n("time_shortcut.three_months"),
      i18n("time_shortcut.four_months"),
      i18n("time_shortcut.six_months"),
      i18n("time_shortcut.one_year"),
      i18n("time_shortcut.forever"),
      i18n("time_shortcut.custom"),
    ];

    assert.deepEqual(options, expected, "options are correct");
  });
});

acceptance("Admin - Silence User", function (needs) {
  let clock = null;
  needs.user();

  needs.hooks.beforeEach(() => {
    const timezone = loggedInUser().user_option.timezone;
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
      i18n("time_shortcut.later_today"),
      i18n("time_shortcut.tomorrow"),
      i18n("time_shortcut.later_this_week"),
      i18n("time_shortcut.start_of_next_business_week_alt"),
      i18n("time_shortcut.two_weeks"),
      i18n("time_shortcut.next_month"),
      i18n("time_shortcut.two_months"),
      i18n("time_shortcut.three_months"),
      i18n("time_shortcut.four_months"),
      i18n("time_shortcut.six_months"),
      i18n("time_shortcut.one_year"),
      i18n("time_shortcut.forever"),
      i18n("time_shortcut.custom"),
    ];

    assert.deepEqual(options, expected, "options are correct");
  });
});
