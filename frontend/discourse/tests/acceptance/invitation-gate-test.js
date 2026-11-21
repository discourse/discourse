import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import cookie from "discourse/lib/cookie";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

for (const provider of ["discourse_id", "google_oauth2"]) {
  acceptance(`Invitation gate - ${provider}`, function (needs) {
    needs.settings({
      login_required: true,
      invite_only: true,
      enable_local_logins: false,
      auth_immediately: true,
    });
    needs.site({ auth_providers: [{ name: provider }] });

    test("explains invitations before handing off existing-member login", async function (assert) {
      const submit = sinon.stub(HTMLFormElement.prototype, "submit");

      await visit("/");
      assert
        .dom(".invitation-gate h1")
        .hasText(
          i18n("login.invitation_gate.title"),
          "the landing page explains the restriction"
        );
      assert
        .dom(".sign-up-button")
        .doesNotExist("public signup is unavailable");
      assert.false(
        submit.called,
        "the provider is not contacted automatically"
      );

      await click(`.invitation-gate .${provider}`);
      assert.true(
        submit.calledOnce,
        "existing members can continue to their provider"
      );
      assert.true(
        submit.firstCall.thisValue.action.endsWith(`/auth/${provider}`),
        "the login form targets the configured provider"
      );
    });

    test("direct login visits retain the destination and show the gate", async function (assert) {
      const submit = sinon.stub(HTMLFormElement.prototype, "submit");

      await visit("/login");
      cookie("destination_url", "/t/example/123");
      assert.dom(".invitation-gate").exists("direct login also shows the gate");
      assert.false(submit.called, "direct login waits for user confirmation");

      await click(`.invitation-gate .${provider}`);
      const form = submit.firstCall.thisValue;
      assert.strictEqual(
        form.querySelector('[name="origin"]').value,
        "/t/example/123",
        "the original destination survives the gate"
      );
      assert.strictEqual(
        form.querySelector('[name="signup"]'),
        null,
        "the action is login, not signup"
      );
    });
  });
}

acceptance("Invitation gate - local logins", function (needs) {
  needs.settings({ invite_only: true, enable_local_logins: true });

  test("keeps the normal login form", async function (assert) {
    await visit("/login");
    assert
      .dom(".invitation-gate")
      .doesNotExist("local login does not use the gate");
    assert
      .dom("#login-form")
      .exists("the existing login form remains available");
  });
});
