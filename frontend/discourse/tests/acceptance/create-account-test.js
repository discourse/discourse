import { click, currentURL, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import LoginMethod from "discourse/models/login-method";
import Session from "discourse/models/session";
import Site from "discourse/models/site";
import pretender, {
  parsePostData,
  response,
} from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance("Create Account", function () {
  test("create an account", async function (assert) {
    await visit("/");
    await click("header .sign-up-button");

    assert.dom(".signup-fullpage").exists("it shows the signup page");

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
    await click(".signup-fullpage .btn-primary");

    await fillIn("#new-account-username", "good-tuna");
    assert
      .dom("#username-validation.good")
      .exists("the username validation is good");

    pretender.post("/u", (request) => {
      assert.step("request");
      const data = parsePostData(request.requestBody);
      assert.strictEqual(data.name, "Dr. Good Tuna");
      assert.strictEqual(data.password, "cool password bro");
      assert.strictEqual(data.email, "good.tuna@test.com");
      assert.strictEqual(data.username, "good-tuna");
      return response({ success: true });
    });

    await click(".signup-fullpage .btn-primary");
    assert
      .dom(".signup-fullpage .btn-primary")
      .isDisabled("create account is disabled");

    assert.verifySteps(["request"]);
  });

  test("validate username", async function (assert) {
    await visit("/signup");
    await fillIn("#new-account-email", "z@z.co");
    await click(".signup-fullpage .btn-primary");

    assert
      .dom("#username-validation")
      .hasText(i18n("user.username.required"), "shows signup error");
  });

  test("hidden instructions", async function (assert) {
    await visit("/signup");

    assert
      .dom("#account-email-validation-more-info")
      .hasText(i18n("user.email.instructions"));
    assert.dom("#username-validation-more-info").doesNotExist();
    assert.dom("#password-validation-more-info").doesNotExist();
    assert.dom("#fullname-validation-more-info").doesNotExist();
  });

  test("visible instructions", async function (assert) {
    this.siteSettings.show_signup_form_username_instructions = true;
    this.siteSettings.show_signup_form_password_instructions = true;
    this.siteSettings.show_signup_form_full_name_instructions = true;

    await visit("/signup");

    assert
      .dom("#username-validation-more-info")
      .hasText(i18n("user.username.instructions"));
    assert
      .dom("#password-validation-more-info")
      .hasText(i18n("user.password.instructions", { count: 10 }));
    assert
      .dom("#fullname-validation-more-info")
      .hasText(i18n("user.name.instructions_required"));

    await fillIn("#new-account-email", "z@z.co");
    await fillIn("#new-account-username", "");
    await fillIn("#new-account-password", "supersecurepassword");

    await click(".signup-fullpage .btn-primary");

    assert.dom("#username-validation").hasText(i18n("user.username.required"));

    // only shows the instructions if the validation is not visible
    assert.dom("#account-email-validation-more-info").doesNotExist();
    assert.dom("#username-validation-more-info").doesNotExist();
    assert.dom("#password-validation-more-info").doesNotExist();
    assert.dom("#fullname-validation-more-info").exists();
  });

  test("can sign in using a third-party auth", async function (assert) {
    sinon.stub(LoginMethod, "buildPostForm").callsFake((url, params) => {
      assert.step("buildPostForm");
      assert.strictEqual(url, "/auth/facebook");
      assert.true(params.signup);
    });

    await visit("/signup");
    await click("#login-buttons button");

    assert.verifySteps(["buildPostForm"]);
  });

  test("it passes the email if it's stored in the session", async function (assert) {
    Session.current().email = "foo@bar.com";

    sinon.stub(LoginMethod, "buildPostForm").callsFake((_url, { email }) => {
      assert.step("buildPostForm");
      assert.strictEqual(email, "foo@bar.com");
    });

    await visit("/signup");
    await click("#login-buttons button");

    assert.verifySteps(["buildPostForm"]);
  });

  test("does not show passkeys button", async function (assert) {
    await visit("/signup");

    assert
      .dom(".signup-fullpage .btn-primary")
      .exists("create account button exists");

    assert.dom(".passkey-login-button").doesNotExist();
  });
});

acceptance("Create Account with email code available", function (needs) {
  needs.settings({
    enable_local_logins_via_code: true,
    enable_local_logins_via_email: true,
  });

  test("defaults to password signup and creates a password account", async function (assert) {
    await visit("/signup");

    assert.dom("#new-account-password").exists("shows the password form");
    assert.dom(".code-login-form").doesNotExist("does not open code signup");
    assert
      .dom(".signup-page-cta__code-signup")
      .exists("offers email-code signup");

    await fillIn("#new-account-name", "Password Person");
    await fillIn("#new-account-password", "cool password bro");
    await fillIn("#new-account-email", "password.person@example.com");
    await fillIn("#new-account-username", "password-person");

    pretender.post("/u", (request) => {
      const data = parsePostData(request.requestBody);
      assert.strictEqual(
        data.password,
        "cool password bro",
        "submits the password"
      );
      return response({ success: true });
    });

    await click(".signup-page-cta__signup");
  });

  test("restores a verified signup after a full page load", async function (assert) {
    this.owner.lookup("service:session-store").setObject({
      key: "email-code-signup-continuation",
      value: {
        email: "verified@example.com",
        expiresAt: Date.now() + 60_000,
        signupToken: "signup-token",
        username: "",
      },
    });

    await visit("/signup?mode=code");

    assert.strictEqual(
      currentURL(),
      "/signup?mode=code",
      "keeps the explicit signup mode"
    );
    assert
      .dom(".code-login-form__account-details-step")
      .exists("restores the account details step");
    assert
      .dom(".code-login-form__hidden-email")
      .hasValue("verified@example.com", "preserves the verified email");
  });

  test("opts into code signup and can return with the email preserved", async function (assert) {
    await visit("/signup");
    await fillIn("#new-account-email", "person@example.com");
    await click(".signup-page-cta__code-signup");

    assert.dom(".code-login-form").exists("opens code signup explicitly");
    assert.strictEqual(
      currentURL(),
      "/signup?mode=code",
      "keeps the opted-in mode across reloads"
    );
    assert
      .dom(".code-login-form__email-step input")
      .hasValue(
        "person@example.com",
        "carries the password-form email forward"
      );

    await fillIn(".code-login-form__email-step input", "updated@example.com");
    await click(".code-login-form__password-toggle");

    assert.dom("#new-account-password").exists("returns to password signup");
    assert
      .dom("#new-account-email")
      .hasValue("updated@example.com", "preserves the updated email");

    await visit("/signup?mode=unknown");
    assert
      .dom("#new-account-password")
      .exists("ignores an unknown signup mode");

    this.siteSettings.enable_local_logins_via_code = false;
    await visit("/signup?mode=code");
    assert
      .dom("#new-account-password")
      .exists("ignores unavailable code signup");
    assert
      .dom(".signup-page-cta__code-signup")
      .doesNotExist("hides unavailable code signup");
  });
});

acceptance("Create Account - full name requirement", function () {
  test("full name required", async function (assert) {
    const site = Site.current();
    site.set("full_name_required_for_signup", true);
    site.set("full_name_visible_in_signup", true);

    await visit("/signup");

    await fillIn("#new-account-email", "z@z.co");
    await fillIn("#new-account-username", "good-tuna");
    await fillIn("#new-account-password", "cool password bro");

    await click(".signup-fullpage .btn-primary");
    assert.dom("#fullname-validation").hasText(i18n("user.name.required"));

    await fillIn("#new-account-name", "Full Name");

    pretender.post("/u", (request) => {
      assert.step("request");
      const data = parsePostData(request.requestBody);
      assert.strictEqual(data.name, "Full Name");
      assert.strictEqual(data.password, "cool password bro");
      assert.strictEqual(data.email, "z@z.co");
      assert.strictEqual(data.username, "good-tuna");
      return response({ success: true });
    });

    await click(".signup-fullpage .btn-primary");
    assert
      .dom(".signup-fullpage .btn-primary")
      .isDisabled("create account is disabled");

    assert.verifySteps(["request"]);
  });

  test("full name hidden at signup", async function (assert) {
    const site = Site.current();
    site.set("full_name_required_for_signup", false);
    site.set("full_name_visible_in_signup", false);

    await visit("/signup");

    assert.dom("#new-account-name").doesNotExist();

    await fillIn("#new-account-email", "z@z.co");
    await fillIn("#new-account-username", "good-tuna");
    await fillIn("#new-account-password", "cool password bro");

    pretender.post("/u", (request) => {
      assert.step("request");
      const data = parsePostData(request.requestBody);
      assert.strictEqual(data.password, "cool password bro");
      assert.strictEqual(data.email, "z@z.co");
      assert.strictEqual(data.username, "good-tuna");
      return response({ success: true });
    });

    await click(".signup-fullpage .btn-primary");
    assert
      .dom(".signup-fullpage .btn-primary")
      .isDisabled("create account is disabled");

    assert.verifySteps(["request"]);
  });

  test("full name optional at signup", async function (assert) {
    const site = Site.current();
    site.set("full_name_required_for_signup", false);
    site.set("full_name_visible_in_signup", true);

    await visit("/signup");

    assert.dom("#new-account-name").exists();

    await fillIn("#new-account-email", "z@z.co");
    await fillIn("#new-account-username", "good-tuna");
    await fillIn("#new-account-password", "cool password bro");

    pretender.post("/u", (request) => {
      assert.step("request");
      const data = parsePostData(request.requestBody);
      assert.strictEqual(data.password, "cool password bro");
      assert.strictEqual(data.email, "z@z.co");
      assert.strictEqual(data.username, "good-tuna");
      return response({ success: true });
    });

    await click(".signup-fullpage .btn-primary");
    assert
      .dom(".signup-fullpage .btn-primary")
      .isDisabled("create account is disabled");

    assert.verifySteps(["request"]);
  });
});
