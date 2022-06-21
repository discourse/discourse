import {
  acceptance,
  exists,
  query,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import { click, currentURL, fillIn, visit } from "@ember/test-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { test } from "qunit";
import I18n from "I18n";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";

const { TOTP, BACKUP_CODE, SECURITY_KEY } = SECOND_FACTOR_METHODS;
acceptance("Admin - User Index", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.get("/groups/search.json", () => {
      return helper.response([
        {
          id: 42,
          automatic: false,
          name: "Macdonald",
          user_count: 0,
          alias_level: 99,
          visible: true,
          automatic_membership_email_domains: "",
          primary_group: false,
          title: null,
          grant_trust_level: null,
          has_messages: false,
          flair_url: null,
          flair_bg_color: null,
          flair_color: null,
          bio_raw: null,
          bio_cooked: null,
          public_admission: false,
          allow_membership_requests: true,
          membership_request_template: "Please add me",
          full_name: null,
        },
      ]);
    });

    server.put("/users/sam/preferences/username", () => {
      return helper.response({ id: 2, username: "new-sam" });
    });

    server.get("/admin/users/3.json", () => {
      return helper.response({
        id: 3,
        username: "user1",
        name: null,
        avatar_template: "/letter_avatar_proxy/v4/letter/b/f0a364/{size}.png",
        active: true,
        admin: false,
        moderator: false,
        can_grant_admin: true,
        can_revoke_admin: false,
        can_grant_moderation: true,
        can_revoke_moderation: false,
      });
    });

    server.put("/admin/users/3/grant_admin", () => {
      return helper.response({
        success: "OK",
        email_confirmation_required: true,
      });
    });

    server.get("/admin/users/4.json", () => {
      return helper.response({
        id: 4,
        username: "user2",
        name: null,
        avatar_template: "/letter_avatar_proxy/v4/letter/b/f0a364/{size}.png",
        active: true,
        admin: false,
        moderator: false,
        can_grant_admin: true,
        can_revoke_admin: false,
        can_grant_moderation: true,
        can_revoke_moderation: false,
      });
    });

    server.put("/admin/users/4/grant_admin", () => {
      return helper.response(403, {
        second_factor_challenge_nonce: "somenonce",
      });
    });

    server.get("/session/2fa.json", () => {
      return helper.response(200, {
        totp_enabled: true,
        backup_enabled: true,
        security_keys_enabled: true,
        allowed_methods: [TOTP, BACKUP_CODE, SECURITY_KEY],
      });
    });
  });

  test("can edit username", async function (assert) {
    await visit("/admin/users/2/sam");

    assert.strictEqual(
      queryAll(".display-row.username .value").text().trim(),
      "sam"
    );

    // Trying cancel.
    await click(".display-row.username button");
    await fillIn(".display-row.username .value input", "new-sam");
    await click(".display-row.username a");
    assert.strictEqual(
      queryAll(".display-row.username .value").text().trim(),
      "sam"
    );

    // Doing edit.
    await click(".display-row.username button");
    await fillIn(".display-row.username .value input", "new-sam");
    await click(".display-row.username button");
    assert.strictEqual(
      queryAll(".display-row.username .value").text().trim(),
      "new-sam"
    );
  });

  test("shows the number of post edits", async function (assert) {
    await visit("/admin/users/1/eviltrout");

    assert.strictEqual(queryAll(".post-edits-count .value").text().trim(), "6");

    assert.ok(
      exists(".post-edits-count .controls .btn.btn-icon"),
      "View edits button exists"
    );
  });

  test("a link to view post edits report exists", async function (assert) {
    await visit("/admin/users/1/eviltrout");

    let filter = encodeURIComponent('{"editor":"eviltrout"}');

    await click(".post-edits-count .controls .btn.btn-icon");

    assert.strictEqual(
      currentURL(),
      `/admin/reports/post_edits?filters=${filter}`,
      "it redirects to the right admin report"
    );
  });

  test("hides the 'view Edits' button if the count is zero", async function (assert) {
    await visit("/admin/users/2/sam");

    assert.ok(
      !exists(".post-edits-count .controls .btn.btn-icon"),
      "View Edits button not present"
    );
  });

  test("will clear unsaved groups when switching user", async function (assert) {
    await visit("/admin/users/2/sam");

    assert.strictEqual(
      queryAll(".display-row.username .value").text().trim(),
      "sam",
      "the name should be correct"
    );

    const groupChooser = selectKit(".group-chooser");
    await groupChooser.expand();
    await groupChooser.selectRowByValue(42);
    assert.strictEqual(
      groupChooser.header().value(),
      "42",
      "group should be set"
    );

    await visit("/admin/users/1/eviltrout");

    assert.strictEqual(
      queryAll(".display-row.username .value").text().trim(),
      "eviltrout",
      "the name should be correct"
    );

    assert.ok(
      !exists('.group-chooser span[title="Macdonald"]'),
      "group should not be set"
    );
  });

  test("grant admin - shows the confirmation bootbox", async function (assert) {
    await visit("/admin/users/3/user1");
    await click(".grant-admin");
    assert.ok(exists(".bootbox"));
    assert.strictEqual(
      I18n.t("admin.user.grant_admin_confirm"),
      query(".modal-body").textContent.trim()
    );
    await click(".bootbox .btn-primary");
  });

  test("grant admin - redirects to the 2fa page", async function (assert) {
    await visit("/admin/users/4/user2");
    await click(".grant-admin");
    assert.equal(
      currentURL(),
      "/session/2fa?nonce=somenonce",
      "user is redirected to the 2FA page"
    );
  });
});
