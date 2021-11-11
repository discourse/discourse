import { click, fillIn, visit } from "@ember/test-helpers";
import {
  acceptance,
  count,
  exists,
  fakeTime,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import I18n from "I18n";

acceptance("Invites - Create & Edit Invite Modal", function (needs) {
  let deleted;

  needs.user();
  needs.pretender((server, helper) => {
    const inviteData = {
      id: 1,
      invite_key: "52641ae8878790bc7b79916247cfe6ba",
      link: "http://example.com/invites/52641ae8878790bc7b79916247cfe6ba",
      max_redemptions_allowed: 1,
      redemption_count: 0,
      created_at: "2021-01-26T12:00:00.000Z",
      updated_at: "2021-01-26T12:00:00.000Z",
      expires_at: "2121-01-26T12:00:00.000Z",
      expired: false,
      topics: [],
      groups: [],
    };

    server.post("/invites", () => helper.response(inviteData));
    server.put("/invites/1", (request) => {
      const data = helper.parsePostData(request.requestBody);
      if (data.email === "error") {
        return helper.response(422, {
          errors: ["error isn't a valid email address."],
        });
      } else {
        return helper.response(inviteData);
      }
    });

    server.delete("/invites", () => {
      deleted = true;
      return helper.response({});
    });
  });
  needs.hooks.beforeEach(() => {
    deleted = false;
  });

  test("basic functionality", async function (assert) {
    await visit("/u/eviltrout/invited/pending");
    await click(".user-invite-buttons .btn:first-child");
    assert.strictEqual(
      find("input.invite-link")[0].value,
      "http://example.com/invites/52641ae8878790bc7b79916247cfe6ba",
      "shows an invite link when modal is opened"
    );

    await click(".modal-footer .show-advanced");
    await assert.ok(exists(".invite-to-groups"), "shows advanced options");
    await assert.ok(exists(".invite-to-topic"), "shows advanced options");
    await assert.ok(exists(".invite-expires-at"), "shows advanced options");

    await click(".modal-close");
    assert.ok(deleted, "deletes the invite if not saved");
  });

  test("saving", async function (assert) {
    await visit("/u/eviltrout/invited/pending");
    await click(".user-invite-buttons .btn:first-child");

    assert.ok(!exists("tbody tr"), "does not show invite before saving");

    await click(".btn-primary");

    assert.strictEqual(
      count("tbody tr"),
      1,
      "adds invite to list after saving"
    );

    await click(".modal-close");
    assert.notOk(deleted, "does not delete invite on close");
  });

  test("copying saves invite", async function (assert) {
    await visit("/u/eviltrout/invited/pending");
    await click(".user-invite-buttons .btn:first-child");

    await click(".invite-link .btn");

    await click(".modal-close");
    assert.notOk(deleted, "does not delete invite on close");
  });

  test("copying an email invite without an email shows error message", async function (assert) {
    await visit("/u/eviltrout/invited/pending");
    await click(".user-invite-buttons .btn:first-child");

    await fillIn("#invite-email", "error");
    await click(".invite-link .btn");
    assert.strictEqual(
      find("#modal-alert").text(),
      "error isn't a valid email address."
    );
  });
});

acceptance("Invites - Link Invites", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    const inviteData = {
      id: 1,
      invite_key: "52641ae8878790bc7b79916247cfe6ba",
      link: "http://example.com/invites/52641ae8878790bc7b79916247cfe6ba",
      max_redemptions_allowed: 1,
      redemption_count: 0,
      created_at: "2021-01-26T12:00:00.000Z",
      updated_at: "2021-01-26T12:00:00.000Z",
      expires_at: "2121-01-26T12:00:00.000Z",
      expired: false,
      topics: [],
      groups: [],
    };

    server.post("/invites", () => helper.response(inviteData));
    server.put("/invites/1", () => helper.response(inviteData));
    server.delete("/invites", () => helper.response({}));
  });

  test("invite links", async function (assert) {
    await visit("/u/eviltrout/invited/pending");
    await click(".user-invite-buttons .btn:first-child");

    assert.ok(exists("#invite-max-redemptions"), "shows max redemptions field");
  });
});

acceptance("Invites - Email Invites", function (needs) {
  let lastRequest;

  needs.user();
  needs.pretender((server, helper) => {
    const inviteData = {
      id: 1,
      invite_key: "52641ae8878790bc7b79916247cfe6ba",
      link: "http://example.com/invites/52641ae8878790bc7b79916247cfe6ba",
      email: "test@example.com",
      emailed: false,
      custom_message: null,
      created_at: "2021-01-26T12:00:00.000Z",
      updated_at: "2021-01-26T12:00:00.000Z",
      expires_at: "2121-01-26T12:00:00.000Z",
      expired: false,
      topics: [],
      groups: [],
    };

    server.post("/invites", () => helper.response(inviteData));

    server.put("/invites/1", (request) => {
      lastRequest = request;
      return helper.response(inviteData);
    });
  });
  needs.hooks.beforeEach(() => {
    lastRequest = null;
  });

  test("invite email", async function (assert) {
    await visit("/u/eviltrout/invited/pending");
    await click(".user-invite-buttons .btn:first-child");

    assert.ok(exists("#invite-email"), "shows email field");
    await fillIn("#invite-email", "test@example.com");

    assert.ok(exists(".save-invite"), "shows save without email button");
    await click(".save-invite");
    assert.ok(
      lastRequest.requestBody.indexOf("skip_email=true") !== -1,
      "sends skip_email to server"
    );

    await fillIn("#invite-email", "test2@example.com");
    assert.ok(exists(".send-invite"), "shows save and send email button");
    await click(".send-invite");
    assert.ok(
      lastRequest.requestBody.indexOf("send_email=true") !== -1,
      "sends send_email to server"
    );
  });
});

acceptance(
  "Invites - Create & Edit Invite Modal - timeframe choosing",
  function (needs) {
    let clock = null;

    needs.user();
    needs.pretender((server, helper) => {
      const inviteData = {
        id: 1,
        invite_key: "52641ae8878790bc7b79916247cfe6ba",
        link: "http://example.com/invites/52641ae8878790bc7b79916247cfe6ba",
        max_redemptions_allowed: 1,
        redemption_count: 0,
        created_at: "2021-01-26T12:00:00.000Z",
        updated_at: "2021-01-26T12:00:00.000Z",
        expires_at: "2121-01-26T12:00:00.000Z",
        expired: false,
        topics: [],
        groups: [],
      };

      server.post("/invites", () => helper.response(inviteData));
      server.put("/invites/1", () => helper.response(inviteData));
    });

    needs.hooks.beforeEach(() => {
      const timezone = moment.tz.guess();
      clock = fakeTime("2100-05-03T08:00:00", timezone, true); // Monday morning
    });

    needs.hooks.afterEach(() => {
      clock.restore();
    });

    test("shows correct timeframe options", async function (assert) {
      await visit("/u/eviltrout/invited/pending");

      await click(".user-invite-buttons .btn:first-child");
      await click(".modal-footer .show-advanced");
      await click(".future-date-input-selector-header");

      const options = Array.from(
        queryAll(`ul.select-kit-collection li span.name`).map((_, x) =>
          x.innerText.trim()
        )
      );

      const expected = [
        I18n.t("topic.auto_update_input.later_today"),
        I18n.t("topic.auto_update_input.tomorrow"),
        I18n.t("topic.auto_update_input.next_week"),
        I18n.t("topic.auto_update_input.two_weeks"),
        I18n.t("topic.auto_update_input.next_month"),
        I18n.t("topic.auto_update_input.two_months"),
        I18n.t("topic.auto_update_input.three_months"),
        I18n.t("topic.auto_update_input.four_months"),
        I18n.t("topic.auto_update_input.six_months"),
        I18n.t("topic.auto_update_input.pick_date_and_time"),
      ];

      assert.deepEqual(options, expected, "options are correct");
    });
  }
);
