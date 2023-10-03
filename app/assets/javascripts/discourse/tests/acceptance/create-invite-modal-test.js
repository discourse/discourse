import { click, fillIn, visit } from "@ember/test-helpers";
import {
  acceptance,
  exists,
  fakeTime,
  loggedInUser,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import I18n from "I18n";
import { test } from "qunit";

acceptance("Invites - Create & Edit Invite Modal", function (needs) {
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
      return helper.response({});
    });
  });

  test("basic functionality", async function (assert) {
    await visit("/u/eviltrout/invited/pending");
    await click(".user-invite-buttons .btn:first-child");

    await assert.ok(exists(".invite-to-groups"));
    await assert.ok(exists(".invite-to-topic"));
    await assert.ok(exists(".invite-expires-at"));
  });

  test("saving", async function (assert) {
    await visit("/u/eviltrout/invited/pending");
    await click(".user-invite-buttons .btn:first-child");

    assert
      .dom("table.user-invite-list tbody tr")
      .exists({ count: 2 }, "is seeded with two rows");

    await click(".btn-primary");

    assert
      .dom("table.user-invite-list tbody tr")
      .exists({ count: 3 }, "gets added to the list");
  });

  test("copying saves invite", async function (assert) {
    await visit("/u/eviltrout/invited/pending");
    await click(".user-invite-buttons .btn:first-child");

    await click(".save-invite");
    assert.ok(exists(".invite-link .btn"));
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

    server.post("/invites", (request) => {
      lastRequest = request;
      return helper.response(inviteData);
    });

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
      lastRequest.requestBody.includes("skip_email=true"),
      "sends skip_email to server"
    );

    await fillIn("#invite-email", "test2@example.com ");
    assert.ok(exists(".send-invite"), "shows save and send email button");
    await click(".send-invite");
    assert.ok(
      lastRequest.requestBody.includes("send_email=true"),
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
      const timezone = loggedInUser().user_option.timezone;
      clock = fakeTime("2100-05-03T08:00:00", timezone, true); // Monday morning
    });

    needs.hooks.afterEach(() => {
      clock.restore();
    });

    test("shows correct timeframe options", async function (assert) {
      await visit("/u/eviltrout/invited/pending");

      await click(".user-invite-buttons .btn:first-child");
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
        I18n.t("time_shortcut.custom"),
      ];

      assert.deepEqual(options, expected, "options are correct");
    });
  }
);

acceptance(
  "Invites - Create Invite on Site with must_approve_users Setting",
  function (needs) {
    needs.user();
    needs.settings({ must_approve_users: true });

    test("hides `Arrive at Topic` field on sites with `must_approve_users`", async function (assert) {
      await visit("/u/eviltrout/invited/pending");
      await click(".user-invite-buttons .btn:first-child");
      assert.ok(!exists(".invite-to-topic"));
    });
  }
);
