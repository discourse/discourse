import { click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import CodeLoginForm from "discourse/components/code-login-form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import formKit from "discourse/tests/helpers/form-kit-helper";
import { i18n } from "discourse-i18n";

function stubCodeRequest() {
  pretender.get("/session/hp.json", () =>
    response({ value: "hp-value", challenge: "abc", expires_in: 300 })
  );
  pretender.post("/session/login-code", () => response({ success: "OK" }));
}

async function goToCodeStep() {
  await render(<template><CodeLoginForm /></template>);
  await fillIn(
    ".code-login-form__email-step .form-kit__control-input",
    "user@example.com"
  );
  await formKit().submit();
}

module("Integration | Component | CodeLoginForm", function (hooks) {
  setupRenderingTest(hooks);

  test("renders the email step initially", async function (assert) {
    await render(
      <template><CodeLoginForm @initialEmail="foo@example.com" /></template>
    );

    assert.dom(".code-login-form__email-step").exists();
    assert.form().field("email").hasValue("foo@example.com");
    assert.dom(".d-otp-input").doesNotExist();
  });

  test("rejects an invalid email address", async function (assert) {
    await render(<template><CodeLoginForm /></template>);

    await formKit().field("email").fillIn("not-an-email");
    await formKit().submit();

    assert.form().field("email").hasError(i18n("user.email.invalid"));
    assert.dom(".code-login-form__email-step").exists();
  });

  test("advances to the code step after submitting an email", async function (assert) {
    stubCodeRequest();

    await goToCodeStep();

    assert.dom(".code-login-form__code-step").exists();
    assert
      .dom(".code-login-form__instructions")
      .includesText("user@example.com");
    assert.dom(".d-otp-input").exists();
    assert.dom(".code-login-form__resend").exists();
  });

  test("shows an error and clears the input for a wrong code", async function (assert) {
    stubCodeRequest();
    pretender.post("/session/login-code/verify", () =>
      response({ error: i18n("email_login_code.invalid_code") })
    );

    await goToCodeStep();
    await fillIn(".d-otp-input", "000000");

    assert
      .dom(".code-login-form__error")
      .hasText(i18n("email_login_code.invalid_code"));
    assert.dom(".d-otp-input").hasValue("", "the code input is cleared");
  });

  test("shows the second factor form when required", async function (assert) {
    stubCodeRequest();
    pretender.post("/session/login-code/verify", () =>
      response({
        second_factor_required: true,
        totp_enabled: true,
        backup_codes_enabled: false,
      })
    );

    await goToCodeStep();
    await fillIn(".d-otp-input", "123456");

    assert.dom(".code-login-form__second-factor-step").exists();
    assert.dom("#second-factor").exists();
  });

  test("returns to the email step when using a different email", async function (assert) {
    stubCodeRequest();

    await goToCodeStep();
    await click(".code-login-form__change-email");

    assert.dom(".code-login-form__email-step").exists();
    assert.form().field("email").hasValue("user@example.com");
  });
});
