import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import I18n from "discourse-i18n";

acceptance("Create Account", function () {
  test("create an account", async function (assert) {
    await visit("/");
    await click("header .sign-up-button");

    assert.dom(".create-account").exists("it shows the create account modal");

    await fillIn("#new-account-name", "Dr. Good Tuna");
    await fillIn("#new-account-password", "cool password bro");

    // without this double fill, field will sometimes being empty
    // got consistent repro by having browser search bar focused when starting test
    await fillIn("#new-account-email", "good.tuna@test.com");
    await fillIn("#new-account-email", "good.tuna@test.com");

    // Check username
    await fillIn("#new-account-username", "taken");
    assert
      .dom("#username-validation.bad")
      .exists("the username validation is bad");
    await click(".modal-footer .btn-primary");

    await fillIn("#new-account-username", "good-tuna");
    assert
      .dom("#username-validation.good")
      .exists("the username validation is good");

    await click(".modal-footer .btn-primary");
    assert
      .dom(".modal-footer .btn-primary:disabled")
      .exists("create account is disabled");
  });

  test("validate username", async function (assert) {
    await visit("/");
    await click("header .sign-up-button");

    await fillIn("#new-account-email", "z@z.co");
    await click(".modal-footer .btn-primary");

    assert
      .dom("#username-validation")
      .hasText(I18n.t("user.username.required"), "shows signup error");
  });
});
