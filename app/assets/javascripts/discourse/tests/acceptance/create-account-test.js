import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import LoginMethod from "discourse/models/login-method";
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
    await click(".d-modal__footer .btn-primary");

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

    await click(".d-modal__footer .btn-primary");
    assert
      .dom(".d-modal__footer .btn-primary")
      .isDisabled("create account is disabled");

    assert.verifySteps(["request"]);
  });

  test("validate username", async function (assert) {
    await visit("/");
    await click("header .sign-up-button");

    await fillIn("#new-account-email", "z@z.co");
    await click(".d-modal__footer .btn-primary");

    assert
      .dom("#username-validation")
      .hasText(i18n("user.username.required"), "shows signup error");
  });

  test("can sign in using a third-party auth", async function (assert) {
    sinon.stub(LoginMethod, "buildPostForm").callsFake((url) => {
      assert.step("buildPostForm");
      assert.strictEqual(url, "/auth/facebook?signup=true");
    });

    await visit("/");
    await click("header .sign-up-button");
    await click("#login-buttons button");

    assert.verifySteps(["buildPostForm"]);
  });

  test("does not show passkeys button", async function (assert) {
    await visit("/");
    await click("header .sign-up-button");

    assert
      .dom(".d-modal.create-account .btn-primary")
      .exists("create account button exists");

    assert.dom(".passkey-login-button").doesNotExist();
  });
});

acceptance("Create Account - full_name_required", function (needs) {
  needs.settings({ full_name_required: true });

  test("full_name_required", async function (assert) {
    await visit("/");
    await click("header .sign-up-button");

    await fillIn("#new-account-email", "z@z.co");
    await fillIn("#new-account-username", "good-tuna");
    await fillIn("#new-account-password", "cool password bro");

    await click(".d-modal__footer .btn-primary");
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

    await click(".d-modal__footer .btn-primary");
    assert
      .dom(".d-modal__footer .btn-primary")
      .isDisabled("create account is disabled");

    assert.verifySteps(["request"]);
  });
});
