import { getOwner } from "@ember/owner";
import { click, fillIn, settled, visit } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import { cloneJSON } from "discourse/lib/object";
import DiscourseURL from "discourse/lib/url";
import User from "discourse/models/user";
import pretender, {
  fixturesByUrl,
  response,
} from "discourse/tests/helpers/create-pretender";
import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

acceptance("User Preferences - Security", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    server.get("/u/eviltrout/activity.json", () => {
      return helper.response({});
    });

    server.get("/u/trusted-session.json", () => {
      return helper.response({ failed: "FAILED" });
    });

    server.post("/session/forgot_password.json", () => {
      return helper.response({ success: "Ok" });
    });

    server.post("/u/confirm-session.json", () => {
      return helper.response({ success: "Ok" });
    });

    server.put("/u/eviltrout/remove-password", () => {
      return helper.response({ success: "Ok" });
    });
  });

  test("changes a password using an email code", async function (assert) {
    const redirect = sinon.stub(DiscourseURL, "redirectTo");
    pretender.post("/session/forgot_password.json", () =>
      response({ success: "OK", email_code: true })
    );
    pretender.post("/session/password-reset-code/verify", () =>
      response({ success: "OK", redirect_url: "/u/password-reset/reset-token" })
    );

    await visit("/u/eviltrout/preferences/security");
    await click("#change-password-button");

    assert
      .dom(".forgot-password-modal .d-otp-input")
      .exists("opens code entry");
    assert
      .dom("#username-or-email")
      .doesNotExist("uses the code already requested");

    await fillIn(".d-otp-input", "123456");

    assert.true(
      redirect.calledOnceWithExactly("/u/password-reset/reset-token"),
      "loads the password reset page after verification"
    );
  });

  test("does not carry the password reset status over to another user", async function (assert) {
    await visit("/u/eviltrout/preferences/security");
    await click("#change-password-button");

    assert
      .dom(".pref-password")
      .includesText(
        i18n("user.change_password.success"),
        "shows the status for the first user"
      );

    await visit("/u/charlie/preferences/security");

    assert
      .dom(".pref-password")
      .doesNotIncludeText(
        i18n("user.change_password.success"),
        "starts clean for the other user"
      );
  });

  test("opens code entry from the confirm-session dialog", async function (assert) {
    this.siteSettings.enable_passkeys = true;
    pretender.post("/session/forgot_password.json", () =>
      response({ success: "OK", email_code: true })
    );

    await visit("/u/eviltrout/preferences/security");
    await click(".pref-passkeys__add .btn");
    await click(".dialog-body .confirm-session__reset-btn");

    assert
      .dom(".dialog-body .confirm-session")
      .doesNotExist("dismisses the confirmation dialog");
    assert
      .dom(".forgot-password-modal .d-otp-input")
      .exists("opens code entry for the requested reset");

    await click(".code-login-form__change-email");

    assert
      .dom("#username-or-email")
      .hasValue(
        this.owner.lookup("service:current-user").email || "eviltrout",
        "keeps the current account when returning to the request step"
      );
  });

  test("recently connected devices", async function (assert) {
    await visit("/u/eviltrout/preferences/security");

    assert
      .dom(".auth-tokens > .auth-token:nth-of-type(1) .auth-token-device")
      .hasText("Linux Computer", "displays active token first");

    assert
      .dom(".pref-auth-tokens > a:nth-of-type(1)")
      .hasText(
        i18n("user.auth_tokens.show_all", { count: 3 }),
        "it should display two tokens"
      );
    assert
      .dom(".pref-auth-tokens .auth-token")
      .exists({ count: 2 }, "displays two tokens");

    await click(".pref-auth-tokens > a:nth-of-type(1)");

    assert
      .dom(".pref-auth-tokens .auth-token")
      .exists({ count: 3 }, "displays three tokens");

    const authTokenDropdown = selectKit(".auth-token-dropdown");
    await authTokenDropdown.expand();
    await authTokenDropdown.selectRowByValue("notYou");

    assert.dom(".d-modal").exists("modal appears");
  });

  test("Viewing user api keys", async function (assert) {
    pretender.get("/u/eviltrout.json", () => {
      const json = cloneJSON(fixturesByUrl["/u/eviltrout.json"]);
      Object.assign(json.user, {
        admin: false,
        can_edit: true,
        user_api_keys: [
          {
            id: 1,
            application_name: "Discourse Hub",
            scopes: ["Read and clear notifications"],
            created_at: "2020-11-14T00:57:09.093Z",
            last_used_at: "2022-09-15T18:55:41.672Z",
          },
        ],
      });
      return response(json);
    });

    updateCurrentUser({ admin: false });

    await visit("/u/eviltrout/preferences/security");

    assert
      .dom(".user-api-key__name")
      .hasText(
        "Discourse Hub",
        "displays the application name for the API key"
      );

    await click(".user-api-key__scopes-toggle > a");

    assert
      .dom(".user-api-key__scopes-list-item")
      .hasText(
        "Read and clear notifications",
        "displays the scope for the API key"
      );

    assert
      .dom(".user-api-key__date-approved")
      .exists("displays the created at date for the API key");

    assert
      .dom(".user-api-key__date-last-used")
      .exists("displays the last used at date for the API key");

    assert
      .dom(".user-api-key__actions .btn")
      .exists("lets a non-admin owner revoke the API key");
  });

  test("Viewing Passkeys - user has a key", async function (assert) {
    this.siteSettings.enable_passkeys = true;

    updateCurrentUser({
      user_passkeys: [
        {
          id: 1,
          name: "Password Manager",
          last_used: "2023-10-09T20:03:20.986Z",
          created_at: "2023-10-09T20:01:37.578Z",
        },
      ],
    });

    await visit("/u/eviltrout/preferences/security");

    assert
      .dom(".pref-passkeys__rows .row-passkey__name")
      .hasText("Password Manager", "displays the passkey name");

    assert
      .dom(".row-passkey__created-date")
      .exists("displays the created at date for the passkey");

    assert
      .dom(".row-passkey__used-date")
      .exists("displays the last used at date for the passkey");

    await click(".pref-passkeys__add button");

    assert
      .dom(".dialog-body .confirm-session")
      .exists(
        "displays a dialog to confirm the user's identity before adding a passkey"
      );

    assert
      .dom(".dialog-body #password")
      .exists("dialog includes a password field");

    assert
      .dom(".dialog-body .confirm-session__passkey")
      .exists("dialog includes a passkey button");

    assert
      .dom(".dialog-body .confirm-session__reset")
      .exists("dialog includes a link to reset the password");

    await click(".dialog-body .confirm-session__reset-btn");

    assert
      .dom(".confirm-session__reset-email-sent")
      .exists("shows reset email confirmation message");

    await click(".dialog-close");

    const dropdown = selectKit(".passkey-options-dropdown");
    await dropdown.expand();
    await dropdown.selectRowByName("Edit");

    assert
      .dom(".dialog-body .rename-passkey__form")
      .exists("clicking Edit displays a dialog to rename the passkey");

    await click(".dialog-close");

    await dropdown.expand();
    await dropdown.selectRowByName("Delete");

    assert
      .dom(".dialog-body .confirm-session")
      .exists(
        "displays a dialog to confirm the user's identity before deleting a passkey"
      );

    await click(".dialog-close");
  });

  test("Viewing Passkeys - empty state", async function (assert) {
    this.siteSettings.enable_passkeys = true;

    await visit("/u/eviltrout/preferences/security");

    assert
      .dom(".pref-passkeys__add .btn")
      .exists("shows a button to add a passkey");

    await click(".pref-passkeys__add .btn");

    assert
      .dom(".dialog-body .confirm-session")
      .exists(
        "displays a dialog to confirm the user's identity before adding a passkey"
      );

    assert.dom(".dialog-body #password").exists("includes a password field");

    assert
      .dom(".dialog-body .confirm-session__passkey")
      .doesNotExist("does not include a passkey button");
  });

  test("disables passkeys and two-factor on another user's page", async function (assert) {
    this.siteSettings.enable_passkeys = true;

    await visit("/u/charlie/preferences/security");

    assert
      .dom(".pref-passkeys .access-notice.--self")
      .exists("explains only the user can add passkeys");
    assert
      .dom(".pref-passkeys__add .btn")
      .isDisabled("disables adding a passkey");
    assert
      .dom(".pref-second-factor .access-notice.--self")
      .exists("explains only the user can manage two-factor");
    assert.dom(".btn-second-factor").isDisabled("disables managing two-factor");
  });

  test("treats your own page as yours when opened with a separate user object", async function (assert) {
    this.siteSettings.enable_passkeys = true;

    await visit("/");
    await getOwner(this)
      .lookup("service:router")
      .transitionTo(
        "preferences.security",
        User.create({ username: "eviltrout" })
      );
    await settled();

    assert
      .dom(".pref-passkeys .access-notice.--self")
      .doesNotExist("does not show the self-only notice");
    assert.dom(".pref-passkeys__add .btn").isEnabled("lets you add a passkey");
  });

  test("Remove Password availability", async function (assert) {
    this.siteSettings.enable_passkeys = true;
    await visit("/u/eviltrout/preferences/security");
    // eviltrout starts with an entry in associated_accounts, can remove password
    assert
      .dom("#remove-password-link:not(:disabled)")
      .exists("is enabled for user with associated account");

    updateCurrentUser({
      associated_accounts: null,
    });

    assert
      .dom("#remove-password-link:disabled")
      .exists(
        "is disabled for user with no associated account and no passkeys"
      );

    updateCurrentUser({
      user_passkeys: [
        {
          id: 1,
          name: "Password Manager",
          last_used: "2023-10-09T20:03:20.986Z",
          created_at: "2023-10-09T20:01:37.578Z",
        },
      ],
    });
    assert
      .dom("#remove-password-link:not(:disabled)")
      .exists("is enabled for user with passkey");
  });

  test("Removing User Password", async function (assert) {
    await visit("/u/eviltrout/preferences/security");
    // eviltrout starts with an entry in associated_accounts, can remove password

    await click("#remove-password-link");
    assert
      .dom(".dialog-body .confirm-session")
      .exists(
        "displays a dialog to confirm the user's identity before deleting password"
      );
    await fillIn(".confirm-session #password", "correct");
    await click(".confirm-session .btn-primary");
    assert
      .dom(".dialog-body")
      .hasText(i18n("user.change_password.remove_detail"));
    await click(".dialog-footer .btn-danger");
    assert
      .dom("#remove-password-link")
      .doesNotExist("hides remove password button once password is removed");
    assert
      .dom("#change-password-button")
      .hasText(
        i18n("user.change_password.set_password"),
        "shows set password instead of change after password removed"
      );
  });

  test("confirms passwordless session with email code before adding a passkey", async function (assert) {
    this.siteSettings.enable_passkeys = true;
    this.owner.lookup("service:current-user").set("no_password", true);

    pretender.get("/u/trusted-session.json", () =>
      response({
        failed: "FAILED",
        methods: {
          password: false,
          passkey: false,
          email_code: true,
          external_providers: [],
        },
      })
    );
    pretender.post("/u/confirm-session/email-code.json", () =>
      response({ success: "OK", email: "eviltrout@example.com" })
    );
    pretender.post("/u/confirm-session.json", (request) => {
      assert.strictEqual(
        new URLSearchParams(request.requestBody).get("email_code"),
        "654321",
        "submits the email confirmation code"
      );
      return response({ success: "OK" });
    });

    let createCalled = 0;
    pretender.post("/u/create_passkey.json", () => {
      createCalled++;
      return response({
        challenge: "challenge",
        rp_name: "Discourse",
        rp_id: "localhost",
        user_secure_id: "user1",
        supported_algorithms: [-7],
        existing_passkey_credential_ids: [],
      });
    });
    const createStub = sinon
      .stub(navigator.credentials, "create")
      .rejects(new DOMException("Cancelled", "NotAllowedError"));

    await visit("/u/eviltrout/preferences/security");
    await click(".pref-passkeys__add .btn");

    assert
      .dom(".dialog-body .confirm-session #password")
      .doesNotExist("does not show password field for passwordless user");
    assert
      .dom(".confirm-session__email-code .btn")
      .exists("offers email code confirmation");

    await click(".confirm-session__email-code .btn");
    await fillIn(".confirm-session .d-otp-input", "654321");

    assert.strictEqual(
      createCalled,
      1,
      "starts passkey creation after confirming session with email code"
    );
    assert.true(createStub.calledOnce, "starts WebAuthn registration");
  });
});

acceptance("User Preferences - Security with external auth", function (needs) {
  needs.user({ no_password: true, user_passkeys: [] });
  needs.settings({ enable_local_logins: false, enable_passkeys: true });
  needs.pretender((server, helper) => {
    server.get("/u/trusted-session.json", () =>
      helper.response({ success: "OK" })
    );
  });

  test("shows passkey registration when local logins are disabled without confirming session", async function (assert) {
    let createCalled = 0;
    pretender.post("/u/create_passkey.json", () => {
      createCalled++;
      return response({
        challenge: "challenge",
        rp_name: "Discourse",
        rp_id: "localhost",
        user_secure_id: "user1",
        supported_algorithms: [-7],
        existing_passkey_credential_ids: [],
      });
    });
    const createStub = sinon
      .stub(navigator.credentials, "create")
      .rejects(new DOMException("Cancelled", "NotAllowedError"));

    await visit("/u/eviltrout/preferences/security");

    assert
      .dom("#change-password-button")
      .doesNotExist("keeps password controls hidden");
    assert
      .dom(".pref-passkeys__add .btn")
      .exists("renders passkey registration controls");

    await click(".pref-passkeys__add .btn");

    assert.strictEqual(
      createCalled,
      1,
      "requests a passkey challenge directly"
    );
    assert
      .dom(".confirm-session")
      .doesNotExist("does not ask for a local credential");
    assert.true(createStub.calledOnce, "starts WebAuthn registration");
  });

  test("offers external provider re-authentication when session is stale and provider is connected", async function (assert) {
    pretender.get("/u/trusted-session.json", () =>
      response({
        failed: "FAILED",
        methods: {
          password: false,
          passkey: false,
          email_code: false,
          external_providers: ["facebook"],
        },
      })
    );

    await visit("/u/eviltrout/preferences/security");
    await click(".pref-passkeys__add .btn");

    assert
      .dom(".confirm-session .confirm-session__provider-btn.facebook")
      .exists("shows connected external provider confirmation button");
    assert
      .dom(".confirm-session #password")
      .doesNotExist("does not render password form");
  });

  test("prompts to sign in again when session has no confirmation methods", async function (assert) {
    pretender.get("/u/trusted-session.json", () =>
      response({
        failed: "FAILED",
        methods: {
          password: false,
          passkey: false,
          email_code: false,
          external_providers: [],
        },
      })
    );

    await visit("/u/eviltrout/preferences/security");
    await click(".pref-passkeys__add .btn");

    assert.dom(".dialog-header h3").hasText(i18n("user.confirm_access.title"));
    assert
      .dom(".dialog-body")
      .hasText(i18n("user.passkeys.external_login_required"));
    assert.dom(".dialog-footer .btn-primary").hasText(i18n("user.log_out"));
  });

  test("prompts to sign in again when external passkey grant has expired", async function (assert) {
    pretender.post("/u/create_passkey.json", () =>
      response(403, {
        error_type: "second_factor_external_login_required",
        errors: ["Sign in again"],
      })
    );

    await visit("/u/eviltrout/preferences/security");
    await click(".pref-passkeys__add .btn");

    assert.dom(".dialog-header h3").hasText(i18n("user.confirm_access.title"));
    assert
      .dom(".dialog-body")
      .hasText(i18n("user.passkeys.external_login_required"));
    assert.dom(".dialog-footer .btn-primary").hasText(i18n("user.log_out"));
  });

  test("hides passkey and 2FA controls when external auth 2FA is disabled", async function (assert) {
    this.siteSettings.enforce_second_factor_on_external_auth = false;

    await visit("/u/eviltrout/preferences/security");

    assert.dom(".pref-passkeys").doesNotExist("hides passkey management");
    assert
      .dom(".pref-second-factor")
      .doesNotExist("hides two-factor management");
  });
});
