import I18n from "I18n";
import { test } from "qunit";
import { click, visit } from "@ember/test-helpers";
import {
  acceptance,
  count,
  query,
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
});
