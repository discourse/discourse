import { click, currentURL, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";
import { acceptance, query } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

const { TOTP, BACKUP_CODE, SECURITY_KEY } = SECOND_FACTOR_METHODS;
let deleteAndBlock = null;

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

    server.get("/admin/users/7.json", () => {
      return helper.response({
        id: 7,
        username: "jimmy",
        name: "Jimmy Johnson",
        avatar_template: "/letter_avatar_proxy/v4/letter/b/f0a364/{size}.png",
        active: true,
        admin: false,
        moderator: false,
        can_grant_admin: true,
        can_revoke_admin: false,
        can_grant_moderation: true,
        can_revoke_moderation: false,
        second_factor_enabled: true,
        can_disable_second_factor: true,
      });
    });

    server.put("/admin/users/4/grant_admin", () => {
      return helper.response(403, {
        second_factor_challenge_nonce: "some-nonce",
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

    server.get("/admin/users/5.json", () => {
      return helper.response({
        id: 5,
        username: "user5",
        name: null,
        avatar_template: "/letter_avatar_proxy/v4/letter/b/f0a364/{size}.png",
        active: true,
        can_be_deleted: true,
        post_count: 0,
      });
    });

    server.delete("/admin/users/5.json", (request) => {
      const data = helper.parsePostData(request.requestBody);

      if (data.block_email || data.block_ip || data.block_urls) {
        deleteAndBlock = true;
      } else {
        deleteAndBlock = false;
      }

      return helper.response({});
    });

    server.get("/admin/users/6.json", () => {
      return helper.response({
        id: 6,
        username: "user6",
        name: null,
        avatar_template: "/letter_avatar_proxy/v4/letter/b/f0a364/{size}.png",
        active: true,
        admin: false,
        moderator: false,
        can_grant_admin: true,
        can_revoke_admin: false,
      });
    });

    server.put("/admin/users/6/grant_admin", () => {
      return helper.response(403, {
        error: "A message with <strong>bold</strong> text.",
        html_message: true,
      });
    });

    server.put("/admin/users/7/disable_second_factor", () => {
      return helper.response({ success: "OK" });
    });
  });

  needs.hooks.beforeEach(() => {
    deleteAndBlock = null;
  });

  test("can edit username", async function (assert) {
    await visit("/admin/users/2/sam");

    assert.dom(".display-row.username .value").hasText("sam");

    // Trying cancel.
    await click(".display-row.username button");
    await fillIn(".display-row.username .value input", "new-sam");
    await click(".display-row.username a");
    assert.dom(".display-row.username .value").hasText("sam");

    // Doing edit.
    await click(".display-row.username button");
    await fillIn(".display-row.username .value input", "new-sam");
    await click(".display-row.username button");
    assert.dom(".display-row.username .value").hasText("new-sam");
  });

  test("shows the number of post edits", async function (assert) {
    await visit("/admin/users/1/eviltrout");

    assert.dom(".post-edits-count .value").hasText("6");

    assert
      .dom(".post-edits-count .controls .btn.btn-icon")
      .exists("View edits button exists");
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

    assert
      .dom(".post-edits-count .controls .btn.btn-icon")
      .doesNotExist("View Edits button not present");
  });

  test("will clear unsaved groups when switching user", async function (assert) {
    await visit("/admin/users/2/sam");

    assert
      .dom(".display-row.username .value")
      .hasText("sam", "the name should be correct");

    const groupChooser = selectKit(".group-chooser");
    await groupChooser.expand();
    await groupChooser.selectRowByValue(42);
    assert.strictEqual(
      groupChooser.header().value(),
      "42",
      "group should be set"
    );

    await visit("/admin/users/1/eviltrout");

    assert
      .dom(".display-row.username .value")
      .hasText("eviltrout", "the name should be correct");

    assert
      .dom('.group-chooser span[title="Macdonald"]')
      .doesNotExist("group should not be set");
  });

  test("grant admin - shows the confirmation dialog", async function (assert) {
    await visit("/admin/users/3/user1");
    await click(".grant-admin");
    assert.dom(".dialog-content").exists();
    assert.strictEqual(
      i18n("admin.user.grant_admin_confirm"),
      query(".dialog-body").textContent.trim()
    );

    await click(".dialog-footer .btn-primary");
  });

  test("grant admin - optionally allows HTML to be shown in the confirmation dialog", async function (assert) {
    await visit("/admin/users/6/user6");
    await click(".grant-admin");
    assert.dom(".dialog-content").exists();

    assert
      .dom(".dialog-content .dialog-body strong")
      .exists("HTML is rendered in the dialog");
  });

  test("grant admin - redirects to the 2fa page", async function (assert) {
    await visit("/admin/users/4/user2");
    await click(".grant-admin");
    assert.strictEqual(
      currentURL(),
      "/session/2fa?nonce=some-nonce",
      "user is redirected to the 2FA page"
    );
  });

  test("disable 2fa - shows the confirmation dialog", async function (assert) {
    await visit("/admin/users/7/jimmy");
    await click(".disable-second-factor");
    assert.dom(".dialog-content").exists();
    assert.strictEqual(
      i18n("admin.user.disable_second_factor_confirm"),
      query(".dialog-body").textContent.trim()
    );

    await click(".dialog-footer .btn-primary");
  });

  test("delete user - delete without blocking works as expected", async function (assert) {
    await visit("/admin/users/5/user5");
    await click(".btn-user-delete");

    assert
      .dom("#dialog-title")
      .hasText(i18n("admin.user.delete_confirm_title"), "dialog has a title");

    await click(".dialog-footer .btn-primary");

    assert.false(deleteAndBlock, "user does not get blocked");
  });

  test("delete user - delete and block works as expected", async function (assert) {
    await visit("/admin/users/5/user5");
    await click(".btn-user-delete");
    await click(".dialog-footer .btn-danger");

    assert.ok(deleteAndBlock, "user does not get blocked");
  });
});
