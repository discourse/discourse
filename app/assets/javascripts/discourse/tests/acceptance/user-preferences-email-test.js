import { test } from "qunit";
import I18n from "I18n";
import { click, fillIn, visit } from "@ember/test-helpers";
import {
  acceptance,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";

acceptance("User Preferences - Email", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    server.put("/u/eviltrout/preferences/email", () => {
      return helper.response({
        success: true,
      });
    });
  });

  test("email", async function (assert) {
    await visit("/u/eviltrout/preferences/email");

    assert.ok(exists("#change-email"), "it has the input element");

    await fillIn("#change-email", "invalid-email");

    assert.strictEqual(
      query(".tip.bad").innerText.trim(),
      I18n.t("user.email.invalid"),
      "it should display invalid email tip"
    );
  });

  test("email field always shows up", async function (assert) {
    await visit("/u/eviltrout/preferences/email");

    assert.ok(exists("#change-email"), "it has the input element");

    await fillIn("#change-email", "eviltrout@discourse.org");
    await click(".user-preferences button.btn-primary");

    await visit("/u/eviltrout/preferences");
    await visit("/u/eviltrout/preferences/email");

    assert.ok(exists("#change-email"), "it has the input element");
  });
});
