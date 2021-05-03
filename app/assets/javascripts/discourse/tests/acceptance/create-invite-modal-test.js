import { click, fillIn, visit } from "@ember/test-helpers";
import {
  acceptance,
  fakeTime,
  query,
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
    server.put("/invites/1", () => helper.response(inviteData));

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
    await click(".invite-controls .btn:first-child");
    assert.equal(
      find("input.invite-link")[0].value,
      "http://example.com/invites/52641ae8878790bc7b79916247cfe6ba",
      "shows an invite link when modal is opened"
    );

    await click(".modal-footer .show-advanced");
    await assert.ok(
      find(".invite-to-groups").length > 0,
      "shows advanced options"
    );
    await assert.ok(
      find(".invite-to-topic").length > 0,
      "shows advanced options"
    );
    await assert.ok(
      find(".invite-expires-at").length > 0,
      "shows advanced options"
    );

    await click(".modal-close");
    assert.ok(deleted, "deletes the invite if not saved");
  });

  test("saving", async function (assert) {
    await visit("/u/eviltrout/invited/pending");
    await click(".invite-controls .btn:first-child");

    assert.ok(
      find("tbody tr").length === 0,
      "does not show invite before saving"
    );

    await click(".btn-primary");

    assert.ok(
      find("tbody tr").length === 1,
      "adds invite to list after saving"
    );

    await click(".modal-close");
    assert.notOk(deleted, "does not delete invite on close");
  });

  test("copying saves invite", async function (assert) {
    await visit("/u/eviltrout/invited/pending");
    await click(".invite-controls .btn:first-child");

    await click(".invite-link .btn");

    await click(".modal-close");
    assert.notOk(deleted, "does not delete invite on close");
  });

  test("copying an email invite without an email shows error message", async function (assert) {
    await visit("/u/eviltrout/invited/pending");
    await click(".invite-controls .btn:first-child");

    await click("#invite-type");
    await click(".invite-link .btn");
    assert.equal(
      find("#modal-alert").text(),
      I18n.t("user.invited.invite.blank_email")
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
      clock = fakeTime("2021-05-03T08:00:00", "UTC", true); // Monday morning
    });

    needs.hooks.afterEach(() => {
      clock.restore();
    });

    test("shows correct timeframe options", async function (assert) {
      await visit("/u/eviltrout/invited/pending");
      await click(".invite-controls .btn:first-child");
      await click(".modal-footer .show-advanced");
      await click(".future-date-input-selector-header");

      assert.equal(
        query(".future-date-input-selector-header").getAttribute(
          "aria-expanded"
        ),
        "true",
        "selector is expanded"
      );

      const options = Array.from(
        queryAll(`ul.select-kit-collection li span.name`).map((_, x) =>
          x.innerText.trim()
        )
      );

      const expected = [
        I18n.t("time_shortcut.later_today"),
        I18n.t("time_shortcut.tomorrow"),
        I18n.t("time_shortcut.next_week"),
        I18n.t("time_shortcut.two_weeks"),
        I18n.t("time_shortcut.next_month"),
        I18n.t("time_shortcut.two_months"),
        I18n.t("time_shortcut.three_months"),
        I18n.t("time_shortcut.four_months"),
        I18n.t("time_shortcut.six_months"),
        I18n.t("time_shortcut.custom"),
      ];

      assert.deepEqual(options, expected, "options are correct");
    });
  }
);

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
    await click(".invite-controls .btn:first-child");

    assert.ok(
      find("#invite-max-redemptions").length,
      "shows max redemptions field"
    );
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
    await click(".invite-controls .btn:first-child");

    await click("#invite-type");

    assert.ok(find("#invite-email").length, "shows email field");

    await fillIn("#invite-email", "test@example.com");
    assert.ok(find(".save-invite").length, "shows save without email button");
    await click(".save-invite");
    assert.ok(
      lastRequest.requestBody.indexOf("skip_email=true") !== -1,
      "sends skip_email to server"
    );

    await fillIn("#invite-email", "test2@example.com");
    assert.ok(find(".send-invite").length, "shows save and send email button");
    await click(".send-invite");
    assert.ok(
      lastRequest.requestBody.indexOf("send_email=true") !== -1,
      "sends send_email to server"
    );
  });
});
