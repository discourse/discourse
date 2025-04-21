import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

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

    assert.dom("#change-email").exists("has the input element");

    await fillIn("#change-email", "invalid-email");

    assert
      .dom(".tip.bad")
      .hasText(
        i18n("user.email.invalid"),
        "it should display invalid email tip"
      );
  });

  test("email field always shows up", async function (assert) {
    await visit("/u/eviltrout/preferences/email");

    assert.dom("#change-email").exists("has the input element");

    await fillIn("#change-email", "eviltrout@discourse.org");
    await click(".user-preferences button.btn-primary");

    await visit("/u/eviltrout/preferences");
    await visit("/u/eviltrout/preferences/email");

    assert.dom("#change-email").exists("has the input element");
  });
});
