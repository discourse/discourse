import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  query,
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
  });

  test("recently connected devices", async function (assert) {
    await visit("/u/eviltrout/preferences/security");

    assert.strictEqual(
      query(
        ".auth-tokens > .auth-token:nth-of-type(1) .auth-token-device"
      ).innerText.trim(),
      "Linux Computer",
      "it should display active token first"
    );

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
    updateCurrentUser({
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

    await visit("/u/eviltrout/preferences/security");

    assert
      .dom(".pref-user-api-keys__application-name")
      .hasText(
        "Discourse Hub",
        "displays the application name for the API key"
      );

    assert
      .dom(".pref-user-api-keys__scopes-list-item")
      .hasText(
        "Read and clear notifications",
        "displays the scope for the API key"
      );

    assert
      .dom(".pref-user-api-keys__created-at")
      .exists("displays the created at date for the API key");

    assert
      .dom(".pref-user-api-keys__last-used-at")
      .exists("displays the last used at date for the API key");
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

  test("Viewing Passkeys - another user has a key", async function (assert) {
    this.siteSettings.enable_passkeys = true;

    // user charlie has passkeys in fixtures
    await visit("/u/charlie/preferences/security");

    assert
      .dom(".pref-passkeys__rows .row-passkey__name")
      .hasText("iCloud Keychain", "displays the passkey name");

    assert
      .dom(".row-passkey__created-date")
      .exists("displays the created at date for the passkey");

    assert
      .dom(".row-passkey__used-date")
      .exists("displays the last used at date for the passkey");

    assert
      .dom(".pref-passkeys__add")
      .doesNotExist("does not show add passkey button");

    assert
      .dom(".passkey-options-dropdown")
      .doesNotExist("does not show passkey options dropdown");
  });
});
