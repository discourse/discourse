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
    assert
      .dom(".code-login-form__email-step .form-kit__control-input")
      .hasAttribute("autocomplete", "username");
    assert.dom(".d-otp-input").doesNotExist();
    assert.dom(".code-login-form__hidden-email").doesNotExist();
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

  test("keeps a hidden email field for password managers after the email step", async function (assert) {
    stubCodeRequest();

    await goToCodeStep();

    assert
      .dom(".code-login-form__hidden-email")
      .hasValue("user@example.com")
      .hasAttribute("autocomplete", "username")
      .hasAttribute("readonly");

    await click(".code-login-form__change-email");

    assert.dom(".code-login-form__hidden-email").doesNotExist();
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

  test("collects a required full name before completing signup", async function (assert) {
    stubCodeRequest();

    const verifyRequests = [];
    pretender.post("/session/login-code/verify", (request) => {
      const params = new URLSearchParams(request.requestBody);
      verifyRequests.push(params);

      if (params.get("name")) {
        return response({
          account_created: true,
          user: { id: 1, username: "jane", avatar_template: "/letter/j.png" },
          can_edit_username: true,
        });
      }

      return response({ name_required: true });
    });

    await goToCodeStep();
    await fillIn(".d-otp-input", "123456");

    assert.dom(".code-login-form__user-fields-step").exists();
    assert
      .dom("#code-login-name")
      .exists()
      .hasAttribute("autocomplete", "name");

    await click(".code-login-form__verify");

    assert
      .dom(".code-login-form__name-field .code-login-form__error")
      .hasText(i18n("user.name.required"));
    assert.strictEqual(
      verifyRequests.length,
      1,
      "an empty name is not submitted"
    );

    await fillIn("#code-login-name", "  Jane Doe  ");
    await click(".code-login-form__verify");

    assert.strictEqual(verifyRequests.length, 2);
    assert.strictEqual(
      verifyRequests[1].get("name"),
      "Jane Doe",
      "the trimmed name is sent"
    );
    assert.dom(".code-login-form__complete-step").exists();
    assert
      .dom("#code-login-username")
      .hasValue("jane", "the assigned username is prefilled");
  });

  test("regenerates a random username suggestion on the account-ready step", async function (assert) {
    stubCodeRequest();
    pretender.post("/session/login-code/verify", () =>
      response({
        account_created: true,
        user: { id: 1, username: "jane", avatar_template: "/letter/j.png" },
        can_edit_username: true,
      })
    );
    pretender.get("/u/random-username.json", () =>
      response({ username: "QuietFalcon" })
    );

    await goToCodeStep();
    await fillIn(".d-otp-input", "123456");

    assert.dom("#code-login-username").hasValue("jane");

    await click(".code-login-form__username-regen");

    assert.dom("#code-login-username").hasValue("QuietFalcon");
    assert.dom(".code-login-form__continue-to-site").isEnabled();
  });

  test("keeps continue disabled when the regenerated username is unavailable", async function (assert) {
    stubCodeRequest();
    pretender.post("/session/login-code/verify", () =>
      response({
        account_created: true,
        user: { id: 1, username: "jane", avatar_template: "/letter/j.png" },
        can_edit_username: true,
      })
    );
    // The default pretender handler reports the username "taken" as
    // unavailable with the suggestion "nottaken".
    pretender.get("/u/random-username.json", () =>
      response({ username: "taken" })
    );

    await goToCodeStep();
    await fillIn(".d-otp-input", "123456");

    await click(".code-login-form__username-regen");

    assert.dom("#code-login-username").hasValue("taken");
    assert
      .dom(".code-login-form__username-field .code-login-form__error")
      .hasText(
        i18n("code_login.username_unavailable", { suggestion: "nottaken" })
      );
    assert.dom(".code-login-form__continue-to-site").isDisabled();
  });

  test("shows a fixed username without editing controls when it can't be changed", async function (assert) {
    stubCodeRequest();
    pretender.post("/session/login-code/verify", () =>
      response({
        account_created: true,
        user: { id: 1, username: "jane", avatar_template: "/letter/j.png" },
        can_edit_username: false,
      })
    );

    await goToCodeStep();
    await fillIn(".d-otp-input", "123456");

    assert.dom(".code-login-form__new-account-username").hasText("jane");
    assert.dom("#code-login-username").doesNotExist();
    assert.dom(".code-login-form__username-regen").doesNotExist();
    assert.dom(".code-login-form__continue-to-site").isEnabled();
  });

  test("returns to the email step when using a different email", async function (assert) {
    stubCodeRequest();

    await goToCodeStep();
    await click(".code-login-form__change-email");

    assert.dom(".code-login-form__email-step").exists();
    assert.form().field("email").hasValue("user@example.com");
  });

  test("signup context shows a single step-aware heading that is replaced, not stacked", async function (assert) {
    stubCodeRequest();

    await render(<template><CodeLoginForm @context="signup" /></template>);

    assert.dom(".login-welcome-header").exists({ count: 1 });
    assert.dom(".login-title").hasText(i18n("code_login.signup_title"));
    assert.dom(".login-subheader").doesNotExist();
    assert.dom(".code-login-form__title").doesNotExist();
    assert
      .dom(".code-login-form__instructions")
      .hasText(i18n("code_login.signup_instructions"));

    await fillIn(
      ".code-login-form__email-step .form-kit__control-input",
      "user@example.com"
    );
    await formKit().submit();

    assert.dom(".code-login-form__code-step").exists();
    assert.dom(".login-welcome-header").exists({ count: 1 });
    assert.dom(".login-title").hasText(i18n("code_login.check_your_email"));
    assert.dom(".login-subheader").includesText("user@example.com");
    assert.dom(".code-login-form__title").doesNotExist();
  });

  test("login context keeps the inline step heading and adds no page header", async function (assert) {
    stubCodeRequest();

    await goToCodeStep();

    assert.dom(".login-welcome-header").doesNotExist();
    assert
      .dom(".code-login-form__title")
      .hasText(i18n("code_login.check_your_email"));
  });
});
