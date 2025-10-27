import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Create Account Fields - From Login Form", function () {
  test("autofills email field with login form value", async function (assert) {
    await visit("/");
    await click("header .login-button");
    await fillIn("#login-account-name", "isaac@foo.com");

    await click("#new-account-link");

    assert.dom("#new-account-username").hasText("");
    assert
      .dom("#new-account-email")
      .hasValue("isaac@foo.com", "email is autofilled");
  });

  test("autofills username field with login form value", async function (assert) {
    await visit("/");
    await click("header .login-button");
    await fillIn("#login-account-name", "isaac");
    await click("#new-account-link");

    assert.dom("#new-account-email").hasText("");
    assert
      .dom("#new-account-username")
      .hasValue("isaac", "username is autofilled");
  });
});
