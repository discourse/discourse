import { click, currentRouteName, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Login Required", function (needs) {
  needs.settings({ login_required: true, full_page_login: false });

  test("redirect", async function (assert) {
    await visit("/latest");
    assert.strictEqual(
      currentRouteName(),
      "login",
      "it redirects them to login"
    );

    await click(".login-button");
    assert.dom(".login-modal").exists("login modal is shown");

    await click(".d-modal__header .modal-close");
    assert.dom(".login-modal").doesNotExist("closes the login modal");
  });
});

acceptance("Login Required - Full page login", function (needs) {
  needs.settings({ login_required: true, full_page_login: true });

  test("page", async function (assert) {
    await visit("/");
    assert.strictEqual(
      currentRouteName(),
      "login",
      "it redirects them to login"
    );

    await click(".login-button");
    assert.dom(".login-left-side").exists("login form is shown");
    assert
      .dom(".login-welcome")
      .doesNotExist("login welcome is no longer shown");

    await click(".logo-big");
    assert.dom(".login-left-side").doesNotExist("closes the login modal");
    assert.dom(".login-welcome").exists("login welcome is shown");
  });
});
