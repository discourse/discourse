import { click, fillIn, visit } from "@ember/test-helpers";
import {
  acceptance,
  count,
  exists,
  fakeTime,
  loggedInUser,
  query,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import I18n from "I18n";
import { test } from "qunit";

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

    assert.strictEqual(count(".suspend-user-modal:visible"), 1);

    await click(".d-modal-cancel");

    assert.ok(!exists(".suspend-user-modal:visible"));
  });

  test("suspend a user - cancel with input", async function (assert) {
    await visit("/admin/users/1234/regular");
    await click(".suspend-user");

    assert.strictEqual(count(".suspend-user-modal:visible"), 1);

    await fillIn("input.suspend-reason", "for breaking the rules");
    await fillIn(".suspend-message", "this is an email reason why");

    await click(".d-modal-cancel");

    assert.strictEqual(count(".dialog-body:visible"), 1);

    await click(".dialog-footer .btn-default");
    assert.strictEqual(count(".suspend-user-modal:visible"), 1);
    assert.strictEqual(
      query(".suspend-message").value,
      "this is an email reason why"
    );

    await click(".d-modal-cancel");
    assert.strictEqual(count(".dialog-body:visible"), 1);

    await click(".dialog-footer .btn-primary");
    assert.ok(!exists(".suspend-user-modal:visible"));
    assert.ok(!exists(".dialog-body:visible"));
  });

  test("suspend, then unsuspend a user", async function (assert) {
    const suspendUntilCombobox = selectKit(".suspend-until .combobox");

    await visit("/admin/flags/active");

    await visit("/admin/users/1234/regular");

    assert.ok(!exists(".suspension-info"));

    await click(".suspend-user");

    assert.strictEqual(
      count(".perform-penalize[disabled]"),
      1,
      "disabled by default"
    );

    await suspendUntilCombobox.expand();
    await suspendUntilCombobox.selectRowByValue("tomorrow");

    await fillIn("input.suspend-reason", "for breaking the rules");
    await fillIn(".suspend-message", "this is an email reason why");

    assert.ok(!exists(".perform-penalize[disabled]"), "no longer disabled");

    await click(".perform-penalize");

    assert.ok(!exists(".suspend-user-modal:visible"));
    assert.ok(exists(".suspension-info"));

    await click(".unsuspend-user");

    assert.ok(!exists(".suspension-info"));
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
      I18n.t("time_shortcut.later_today"),
      I18n.t("time_shortcut.tomorrow"),
      I18n.t("time_shortcut.later_this_week"),
      I18n.t("time_shortcut.start_of_next_business_week_alt"),
      I18n.t("time_shortcut.two_weeks"),
      I18n.t("time_shortcut.next_month"),
      I18n.t("time_shortcut.two_months"),
      I18n.t("time_shortcut.three_months"),
      I18n.t("time_shortcut.four_months"),
      I18n.t("time_shortcut.six_months"),
      I18n.t("time_shortcut.one_year"),
      I18n.t("time_shortcut.forever"),
      I18n.t("time_shortcut.custom"),
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
      I18n.t("time_shortcut.later_today"),
      I18n.t("time_shortcut.tomorrow"),
      I18n.t("time_shortcut.later_this_week"),
      I18n.t("time_shortcut.start_of_next_business_week_alt"),
      I18n.t("time_shortcut.two_weeks"),
      I18n.t("time_shortcut.next_month"),
      I18n.t("time_shortcut.two_months"),
      I18n.t("time_shortcut.three_months"),
      I18n.t("time_shortcut.four_months"),
      I18n.t("time_shortcut.six_months"),
      I18n.t("time_shortcut.one_year"),
      I18n.t("time_shortcut.forever"),
      I18n.t("time_shortcut.custom"),
    ];

    assert.deepEqual(options, expected, "options are correct");
  });
});
