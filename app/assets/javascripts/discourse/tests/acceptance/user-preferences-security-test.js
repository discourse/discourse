import I18n from "I18n";
import { test } from "qunit";
import { click, visit } from "@ember/test-helpers";
import {
  acceptance,
  count,
  exists,
  query,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

acceptance("User Preferences - Security", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    server.get("/u/eviltrout/activity.json", () => {
      return helper.response({});
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

    assert.strictEqual(
      query(".pref-auth-tokens > a:nth-of-type(1)").innerText.trim(),
      I18n.t("user.auth_tokens.show_all", { count: 3 }),
      "it should display two tokens"
    );
    assert.strictEqual(
      count(".pref-auth-tokens .auth-token"),
      2,
      "it should display two tokens"
    );

    await click(".pref-auth-tokens > a:nth-of-type(1)");

    assert.strictEqual(
      count(".pref-auth-tokens .auth-token"),
      3,
      "it should display three tokens"
    );

    const authTokenDropdown = selectKit(".auth-token-dropdown");
    await authTokenDropdown.expand();
    await authTokenDropdown.selectRowByValue("notYou");

    assert.strictEqual(count(".d-modal:visible"), 1, "modal should appear");

    await click(".modal-footer .btn-primary");

    assert.strictEqual(
      count(".pref-password.highlighted"),
      1,
      "it should highlight password preferences"
    );
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

    assert.strictEqual(
      query(".pref-user-api-keys__application-name").innerText.trim(),
      "Discourse Hub",
      "displays the application name for the API key"
    );

    assert.strictEqual(
      query(".pref-user-api-keys__scopes-list-item").innerText.trim(),
      "Read and clear notifications",
      "displays the scope for the API key"
    );

    assert.ok(
      exists(".pref-user-api-keys__created-at"),
      "displays the created at date for the API key"
    );

    assert.ok(
      exists(".pref-user-api-keys__last-used-at"),
      "displays the last used at date for the API key"
    );
  });
});
