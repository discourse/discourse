import {
  click,
  fillIn,
  find,
  render,
  triggerEvent,
  waitFor,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import CodeLoginForm from "discourse/components/code-login-form";
import ModalContainer from "discourse/components/modal-container";
import { withPluginApi } from "discourse/lib/plugin-api";
import DiscourseURL from "discourse/lib/url";
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
  await render(<template><CodeLoginForm /><ModalContainer /></template>);
  await fillIn(
    ".code-login-form__email-step .form-kit__control-input",
    "user@example.com"
  );
  await formKit().submit();
}

async function selectLocalAvatar() {
  await click(".code-login-form__avatar");
  const file = new File(["avatar"], "avatar.png", { type: "image/png" });
  const transfer = new DataTransfer();
  transfer.items.add(file);
  find("#deferred-avatar-upload").files = transfer.files;
  await triggerEvent("#deferred-avatar-upload", "change");
  await click(".avatar-selector-modal .btn-primary");
  return file;
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
    assert
      .dom(".code-login-form__change-email")
      .exists("the email can still be corrected before verification");
  });

  test("signup requests declare their intent", async function (assert) {
    let signup;
    pretender.get("/session/hp.json", () =>
      response({ value: "hp-value", challenge: "abc", expires_in: 300 })
    );
    pretender.post("/session/login-code", (request) => {
      signup = new URLSearchParams(request.requestBody).get("signup");
      return response({ success: "OK" });
    });

    await render(<template><CodeLoginForm @context="signup" /></template>);
    await fillIn(
      ".code-login-form__email-step .form-kit__control-input",
      "user@example.com"
    );
    await formKit().submit();

    assert.strictEqual(signup, "true", "the request identifies signup intent");
    assert
      .dom(".code-login-form__code-step")
      .exists("the form advances after the request succeeds");
  });

  test("email invitations request a code without exposing the address", async function (assert) {
    let requestParams;
    pretender.get("/session/hp.json", () =>
      response({ value: "hp-value", challenge: "abc", expires_in: 300 })
    );
    pretender.post("/session/login-code", (request) => {
      requestParams = new URLSearchParams(request.requestBody);
      return response({ success: "OK" });
    });

    await render(
      <template>
        <CodeLoginForm
          @context="invite"
          @emailLocked={{true}}
          @initialEmail="u***@example.com"
          @inviteKey="invite-key"
        />
      </template>
    );

    assert
      .dom(".code-login-form__email-step input")
      .doesNotExist("the masked address is not rendered in an editable field");

    await click(".code-login-form__continue");

    assert.strictEqual(
      requestParams.get("invite_key"),
      "invite-key",
      "the code request identifies the invitation"
    );
    assert
      .dom(".code-login-form__code-step")
      .exists("the code entry step is shown");
    assert
      .dom(".code-login-form__change-email")
      .doesNotExist("the scoped invitation address cannot be changed");
  });

  test("runs create-account behavior transformers only when submitting the chosen username", async function (assert) {
    stubCodeRequest();

    let transformed = false;
    let verificationRequests = 0;
    withPluginApi((api) =>
      api.registerBehaviorTransformer("create-account", async ({ next }) => {
        transformed = true;
        return next();
      })
    );
    pretender.post("/session/login-code/verify", (request) => {
      verificationRequests++;
      const params = new URLSearchParams(request.requestBody);
      return response(
        params.get("username")
          ? { success: false, message: "Signup verification failed" }
          : {
              username_required: true,
              username: "jane",
              avatar_template: "/letter/j.png",
            }
      );
    });

    await render(<template><CodeLoginForm @context="signup" /></template>);
    await fillIn(
      ".code-login-form__email-step .form-kit__control-input",
      "user@example.com"
    );
    await formKit().submit();
    await fillIn(".d-otp-input", "123456");

    assert.false(
      transformed,
      "checking the email code does not run account creation challenges"
    );
    await click(".code-login-form__continue-to-site");

    assert.true(transformed, "account creation passes through the transformer");
    assert.strictEqual(
      verificationRequests,
      2,
      "the transformer continues to account creation"
    );
    assert
      .dom(".code-login-form__complete-step")
      .exists("signup remains on the username step after rejection");
    assert
      .dom(".code-login-form__complete-step > p.code-login-form__error")
      .hasText(
        "Signup verification failed",
        "the account creation rejection is shown"
      );
  });

  test("shows a request error without advancing to the code step", async function (assert) {
    const error =
      "New registrations are not allowed from your IP address (maximum limit reached). Contact a staff member.";
    pretender.get("/session/hp.json", () =>
      response({ value: "hp-value", challenge: "abc", expires_in: 300 })
    );
    pretender.post("/session/login-code", () => response({ error }));

    await render(<template><CodeLoginForm @context="signup" /></template>);
    await fillIn(
      ".code-login-form__email-step .form-kit__control-input",
      "user@example.com"
    );
    await formKit().submit();

    assert
      .dom(".code-login-form__email-step")
      .exists("the email step remains visible");
    assert
      .dom(".code-login-form__error")
      .hasText(error, "the account limit error is shown inline");
    assert
      .dom(".code-login-form__code-step")
      .doesNotExist("the code step is not rendered");
    assert.dom(".d-otp-input").doesNotExist("the code input is not rendered");
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

  test("collects valid account details before submitting for approval", async function (assert) {
    stubCodeRequest();
    this.siteSettings.enable_random_usernames = true;
    this.site.setProperties({
      full_name_required_for_signup: true,
      full_name_visible_in_signup: true,
    });

    const verifyRequests = [];
    let accountDetailAttempts = 0;
    pretender.post("/session/login-code/verify", (request) => {
      const params = new URLSearchParams(request.requestBody);
      verifyRequests.push(params);

      if (!params.get("signup_token")) {
        return response({
          signup_details_required: true,
          signup_token: "signup-token",
          username: "suggested-name",
          expires_in: 600,
        });
      }

      accountDetailAttempts++;
      return accountDetailAttempts === 1
        ? response({
            error: "Password is too common",
            password_error: "Choose a more secure password",
          })
        : response({ pending_approval: true });
    });

    await render(<template><CodeLoginForm @context="signup" /></template>);
    await fillIn(
      ".code-login-form__email-step .form-kit__control-input",
      "user@example.com"
    );
    await formKit().submit();
    await fillIn(".d-otp-input", "123456");

    assert
      .dom(".login-title")
      .hasText(i18n("code_login.account_details_title"));
    assert.dom(".code-login-form__account-details-step").exists();
    assert
      .dom(".code-login-form__create-password")
      .hasClass("btn-link", "the optional password action uses link styling")
      .hasText(i18n("code_login.create_password_optional"));
    assert.dom("#new-account-password").doesNotExist();
    assert
      .dom(".code-login-form__change-email")
      .doesNotExist("a verified email cannot be changed from account details");

    await click(".code-login-form__create-password");
    assert.dom("#new-account-password").hasAttribute("type", "password");
    assert.strictEqual(
      document.querySelector("#new-account-password").getBoundingClientRect()
        .width,
      document.querySelector("#code-login-username").getBoundingClientRect()
        .width,
      "the password and username inputs have the same visible width"
    );
    await click(".toggle-password-mask");
    assert
      .dom("#new-account-password")
      .hasAttribute("type", "text", "the standard mask control reveals it");
    await fillIn("#new-account-password", "short");
    assert
      .dom(".code-login-form__submit-approval")
      .isDisabled("a locally invalid password cannot be submitted");
    await fillIn("#new-account-password", "Correct Horse Battery Staple");

    assert.strictEqual(
      verifyRequests.length,
      1,
      "verifying the code does not create the account"
    );

    await fillIn("#code-login-username", "taken");
    await waitFor(".code-login-form__submit-approval[disabled]");
    assert
      .dom(".code-login-form__username-field .code-login-form__error")
      .includesText("nottaken");

    await fillIn("#code-login-username", "chosen-name");
    await waitFor(".code-login-form__submit-approval:not([disabled])");
    await click(".code-login-form__submit-approval");

    assert
      .dom(".code-login-form__name-field .code-login-form__error")
      .hasText(i18n("user.name.required"));
    assert.strictEqual(
      verifyRequests.length,
      1,
      "invalid details are not submitted"
    );

    await fillIn("#code-login-name", "  Chosen Name  ");
    await click(".code-login-form__submit-approval");

    assert
      .dom(".code-login-form__account-details-step")
      .exists("a server error keeps the details editable");
    assert.dom("#code-login-username").hasValue("chosen-name");
    assert.dom("#code-login-name").hasValue("  Chosen Name  ");
    assert
      .dom("#new-account-password")
      .hasValue("Correct Horse Battery Staple");
    assert
      .dom("#password-validation")
      .includesText("Choose a more secure password");
    assert.strictEqual(accountDetailAttempts, 1, "the first attempt failed");

    await fillIn("#new-account-password", "A different secure password 42!");
    await click(".code-login-form__submit-approval");

    assert.dom(".code-login-form__pending-approval-step").exists();
    assert.strictEqual(verifyRequests[1].get("signup_token"), "signup-token");
    assert.strictEqual(verifyRequests[1].get("username"), "chosen-name");
    assert.strictEqual(verifyRequests[1].get("name"), "Chosen Name");
    assert.strictEqual(
      verifyRequests[2].get("password"),
      "A different secure password 42!",
      "the password is only sent with final account-detail submissions"
    );
    assert.strictEqual(
      accountDetailAttempts,
      2,
      "the verified continuation can be retried"
    );
  });

  test("restores a verified signup continuation at the account details step", async function (assert) {
    this.owner.lookup("service:session-store").setObject({
      key: "email-code-signup-continuation",
      value: {
        email: "user@example.com",
        expiresAt: Date.now() + 60_000,
        signupToken: "signup-token",
        username: "",
      },
    });

    let verificationRequests = 0;
    pretender.post("/session/login-code/verify", () => {
      verificationRequests++;
      return response({ pending_approval: true });
    });

    await render(<template><CodeLoginForm @context="signup" /></template>);

    assert
      .dom(".code-login-form__account-details-step")
      .exists("the account details step is restored");
    assert
      .dom(".code-login-form__hidden-email")
      .hasValue("user@example.com", "the verified email is preserved");
    assert.strictEqual(
      verificationRequests,
      0,
      "restoring the continuation does not create an account"
    );

    await fillIn("#code-login-username", "chosen-name");
    await waitFor(".code-login-form__submit-approval:not([disabled])");
    await click(".code-login-form__submit-approval");

    assert.strictEqual(verificationRequests, 1, "the proof remains usable");
    assert
      .dom(".code-login-form__pending-approval-step")
      .exists("valid details submit for approval");
  });

  test("ignores missing and expired signup continuations", async function (assert) {
    const sessionStore = this.owner.lookup("service:session-store");

    await render(<template><CodeLoginForm @context="signup" /></template>);

    assert
      .dom(".code-login-form__email-step")
      .exists("a missing continuation starts a fresh signup");

    sessionStore.setObject({
      key: "email-code-signup-continuation",
      value: {
        email: "user@example.com",
        expiresAt: Date.now() - 1,
        signupToken: "expired-token",
        username: "",
      },
    });

    await render(<template><CodeLoginForm @context="signup" /></template>);

    assert
      .dom(".code-login-form__email-step")
      .exists("an expired continuation starts a fresh signup");
    assert.strictEqual(
      sessionStore.getObject("email-code-signup-continuation"),
      null,
      "the expired continuation is removed"
    );
  });

  test("shows the pending approval screen after a valid signup code", async function (assert) {
    stubCodeRequest();
    pretender.post("/session/login-code/verify", () =>
      response({ pending_approval: true })
    );

    await render(<template><CodeLoginForm @context="signup" /></template>);
    await fillIn(
      ".code-login-form__email-step .form-kit__control-input",
      "user@example.com"
    );
    await formKit().submit();
    await fillIn(".d-otp-input", "123456");

    assert
      .dom(".login-title")
      .hasText(i18n("code_login.pending_approval_title"));
    assert
      .dom(".login-subheader")
      .hasText(i18n("code_login.pending_approval_instructions"));
    assert
      .dom(".code-login-form__pending-approval-step")
      .hasNoText("does not add extra instructions below the explanation");
    assert.dom(".d-otp-input").doesNotExist("removes the code input");
    assert.dom(".code-login-form__resend").doesNotExist("removes resend");
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

  test("sends prefilled user fields with the code, skipping the extra step", async function (assert) {
    stubCodeRequest();
    this.owner
      .lookup("service:site")
      .set("user_fields", [
        { id: 7, position: 1, required: true, show_on_signup: true },
      ]);
    withPluginApi((api) =>
      api.registerValueTransformer("code-login-user-field-values", () => ({
        7: "true",
      }))
    );

    let verifyParams;
    pretender.post("/session/login-code/verify", (request) => {
      verifyParams = new URLSearchParams(request.requestBody);

      return response({
        username_required: true,
        username: "jane",
        avatar_template: "/letter/j.png",
        can_upload_avatar: true,
      });
    });

    await goToCodeStep();
    await fillIn(".d-otp-input", "123456");

    assert.strictEqual(
      verifyParams.get("user_fields[7]"),
      "true",
      "the prefilled answer rides along with the code"
    );
    assert
      .dom(".code-login-form__user-fields-step")
      .doesNotExist("the fields are already answered, so the step is skipped");

    await click(".code-login-form__continue-to-site");

    assert.strictEqual(
      verifyParams.get("username"),
      "jane",
      "the final request submits the chosen username"
    );
    assert.strictEqual(
      verifyParams.get("user_fields[7]"),
      "true",
      "the prefilled answer is retained for account creation"
    );
  });

  test("withholds prefilled user fields while a required one is unanswered", async function (assert) {
    stubCodeRequest();
    this.owner.lookup("service:site").set("user_fields", [
      { id: 7, position: 1, required: true, show_on_signup: true },
      { id: 8, position: 2, required: true, show_on_signup: true },
    ]);
    withPluginApi((api) =>
      api.registerValueTransformer("code-login-user-field-values", () => ({
        7: "true",
      }))
    );

    let verifyParams;
    pretender.post("/session/login-code/verify", (request) => {
      verifyParams = new URLSearchParams(request.requestBody);

      return response({ user_fields_required: true });
    });

    await goToCodeStep();
    await fillIn(".d-otp-input", "123456");

    assert.strictEqual(
      verifyParams.get("user_fields[7]"),
      null,
      "a partial set is not sent, which the server would read as complete"
    );
    assert
      .dom(".code-login-form__user-fields-step")
      .exists("the remaining field is still collected");
  });

  test("collects a required full name before completing signup", async function (assert) {
    stubCodeRequest();
    const redirect = sinon.stub(DiscourseURL, "redirectTo");

    const verifyRequests = [];
    pretender.post("/session/login-code/verify", (request) => {
      const params = new URLSearchParams(request.requestBody);
      verifyRequests.push(params);

      if (params.get("username")) {
        return response({
          account_created: true,
          user: {
            id: 1,
            username: "jane",
            avatar_template: "/letter/j.png",
          },
          redirect_url: "/latest",
        });
      }

      if (params.get("name")) {
        return response({
          username_required: true,
          username: "jane",
          avatar_template: "/letter/j.png",
          can_upload_avatar: true,
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
      .hasValue("jane", "the suggested username is prefilled");
    await click(".code-login-form__continue-to-site");

    assert.strictEqual(
      verifyRequests.length,
      3,
      "Continue submits account creation"
    );
    assert.strictEqual(
      verifyRequests[2].get("name"),
      "Jane Doe",
      "the full name is retained for account creation"
    );
    assert.strictEqual(
      verifyRequests[2].get("username"),
      "jane",
      "the chosen username is submitted"
    );
    assert.true(
      redirect.calledOnceWithExactly("/latest"),
      "signup completes after username selection"
    );
  });

  test("regenerates a random username suggestion before creating the account", async function (assert) {
    this.siteSettings.enable_random_usernames = true;
    stubCodeRequest();
    pretender.post("/session/login-code/verify", () =>
      response({
        username_required: true,
        username: "jane",
        avatar_template: "/letter/j.png",
        can_upload_avatar: true,
      })
    );
    pretender.get("/u/random-username.json", () =>
      response({
        username: "QuietFalcon",
        avatar_template: "/letter/q.png",
      })
    );

    await goToCodeStep();
    await fillIn(".d-otp-input", "123456");

    assert.dom("#code-login-username").hasValue("jane");
    assert.dom(".code-login-form__avatar img").hasAttribute("src", /letter\/j/);

    await click(".code-login-form__username-regen");

    assert.dom("#code-login-username").hasValue("QuietFalcon");
    assert
      .dom(".code-login-form__avatar img")
      .hasAttribute("src", /letter\/q/, "the avatar follows the new username");
    assert.dom(".code-login-form__continue-to-site").isEnabled();
  });

  test("keeps continue disabled when the regenerated username is unavailable", async function (assert) {
    this.siteSettings.enable_random_usernames = true;
    stubCodeRequest();
    pretender.post("/session/login-code/verify", () =>
      response({
        username_required: true,
        username: "jane",
        avatar_template: "/letter/j.png",
        can_upload_avatar: true,
      })
    );
    // The default pretender handler reports the username "taken" as
    // unavailable with the suggestion "nottaken".
    pretender.get("/u/random-username.json", () =>
      response({ username: "taken", avatar_template: "/letter/t.png" })
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

  test("previews the avatar for a valid username and uses a person icon otherwise", async function (assert) {
    stubCodeRequest();
    pretender.post("/session/login-code/verify", () =>
      response({
        username_required: true,
        username: null,
        avatar_template: null,
        can_upload_avatar: true,
      })
    );
    pretender.get("/u/check_username", (request) =>
      response(
        request.queryParams.username === "taken"
          ? { available: false }
          : { available: true, avatar_template: "/letter/j.png" }
      )
    );

    await goToCodeStep();
    await fillIn(".d-otp-input", "123456");

    assert
      .dom(".code-login-form__avatar .d-icon-user")
      .exists("a blank username has a neutral person icon");
    assert
      .dom(".code-login-form__avatar img")
      .doesNotExist("the fallback avatar is hidden");

    await fillIn("#code-login-username", "jane");

    assert
      .dom(".code-login-form__avatar img")
      .hasAttribute(
        "src",
        /letter\/j/,
        "the preview matches the validated username"
      );
    assert
      .dom(".code-login-form__avatar .d-icon-user")
      .doesNotExist("the letter avatar replaces the icon");

    await fillIn("#code-login-username", "taken");

    assert
      .dom(".code-login-form__avatar .d-icon-user")
      .exists("an unavailable username has no letter preview");

    await fillIn("#code-login-username", "jane");
    await fillIn("#code-login-username", "");

    assert
      .dom(".code-login-form__avatar .d-icon-user")
      .exists("clearing the username restores the icon");
    assert
      .dom(".code-login-form__continue-to-site")
      .isDisabled("a username is still required");
  });

  test("hides the regenerate button and makes the user pick by default", async function (assert) {
    stubCodeRequest();
    pretender.post("/session/login-code/verify", () =>
      response({
        username_required: true,
        username: null,
        avatar_template: null,
        can_upload_avatar: true,
      })
    );

    await goToCodeStep();
    await fillIn(".d-otp-input", "123456");

    assert.dom(".code-login-form__username-regen").doesNotExist();
    assert
      .dom("#code-login-username")
      .hasNoValue("the generic fallback name isn't prefilled");
    assert.dom(".code-login-form__continue-to-site").isDisabled();
  });

  test("keeps a local avatar preview without uploading before account creation", async function (assert) {
    stubCodeRequest();
    this.siteSettings.selectable_avatars_mode = "tl2";
    let uploads = 0;
    pretender.post("/uploads.json", () => {
      uploads++;
      return response({ id: 42 });
    });
    pretender.post("/session/login-code/verify", () =>
      response({
        username_required: true,
        can_upload_avatar: true,
        trust_level: 2,
      })
    );
    pretender.get("/u/check_username", () =>
      response({ available: true, avatar_template: "/letter/j.png" })
    );

    await goToCodeStep();
    await fillIn(".d-otp-input", "123456");
    await selectLocalAvatar();

    const preview = find(".code-login-form__avatar img").getAttribute("src");
    assert.true(preview.startsWith("blob:"), "the preview uses a local file");

    await fillIn("#code-login-username", "jane");
    await fillIn("#code-login-username", "");

    assert
      .dom(".code-login-form__avatar img")
      .hasAttribute(
        "src",
        preview,
        "username changes preserve the selected image"
      );
    assert.strictEqual(
      uploads,
      0,
      "no avatar is uploaded before signup completes"
    );
    assert
      .dom(".code-login-form__continue-to-site")
      .isDisabled("an avatar does not replace the username requirement");
  });

  for (const failure of [null, "upload", "pick"]) {
    test(`creates the account before uploading and continues ${failure ? `after ${failure} failure` : "after selecting the avatar"}`, async function (assert) {
      stubCodeRequest();
      const requests = [];
      const redirect = sinon.stub(DiscourseURL, "redirectTo").callsFake(() => {
        requests.push("redirect");
      });
      const alert = sinon.spy(this.owner.lookup("service:dialog"), "alert");
      let uploadBody;
      let creationParams;
      pretender.post("/session/login-code/verify", (request) => {
        const params = new URLSearchParams(request.requestBody);
        let result = { username_required: true, can_upload_avatar: true };
        if (params.get("username")) {
          requests.push("create");
          creationParams = params;
          result = {
            account_created: true,
            user: {
              id: 1,
              username: "jane",
              avatar_template: "/letter/j.png",
            },
            can_upload_avatar: true,
            redirect_url: "/latest",
          };
        }
        return response(result);
      });
      pretender.get("/u/check_username", () =>
        response({ available: true, avatar_template: "/letter/j.png" })
      );
      pretender.post("/uploads.json", (request) => {
        requests.push("upload");
        uploadBody = request.requestBody;
        return failure === "upload"
          ? response(500, { errors: ["Upload failed"] })
          : response({ id: 42 });
      });
      pretender.put("/u/jane/preferences/avatar/pick", (request) => {
        requests.push("pick");
        const params = new URLSearchParams(request.requestBody);
        assert.strictEqual(
          params.get("upload_id"),
          "42",
          "the uploaded image is selected"
        );
        return failure === "pick"
          ? response(500, { errors: ["Selection failed"] })
          : response({ success: "OK" });
      });

      await goToCodeStep();
      await fillIn(".d-otp-input", "123456");
      const file = await selectLocalAvatar();
      await fillIn("#code-login-username", "jane");
      await click(".code-login-form__continue-to-site");

      assert.strictEqual(
        creationParams.get("username"),
        "jane",
        "account creation receives the chosen username"
      );
      assert.strictEqual(
        creationParams.get("code"),
        "123456",
        "the verified code accompanies account creation"
      );
      assert.deepEqual(
        requests,
        failure === "upload"
          ? ["create", "upload", "redirect"]
          : ["create", "upload", "pick", "redirect"],
        "signup finishes after attempting the authenticated avatar upload"
      );
      assert.strictEqual(
        uploadBody.get("type"),
        "avatar",
        "the file is uploaded as an avatar"
      );
      assert.strictEqual(
        uploadBody.get("user_id"),
        "1",
        "the upload belongs to the newly created user"
      );
      assert.strictEqual(
        uploadBody.get("files[]").name,
        file.name,
        "the selected file is uploaded"
      );
      assert.true(
        redirect.calledOnceWithExactly("/latest"),
        "signup continues to the destination"
      );
      assert.false(alert.called, "avatar failures do not show a retry dialog");
    });
  }

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
