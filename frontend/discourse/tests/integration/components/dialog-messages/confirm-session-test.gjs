import { click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import ConfirmSession from "discourse/components/dialog-messages/confirm-session";
import LoginMethod, { clearAuthMethods } from "discourse/models/login-method";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { i18n } from "discourse-i18n";

module(
  "Integration | Component | DialogMessages | ConfirmSession",
  function (hooks) {
    setupRenderingTest(hooks);

    let originalAuthProviders;

    hooks.beforeEach(function () {
      originalAuthProviders = this.site.auth_providers;
      clearAuthMethods();
    });

    hooks.afterEach(function () {
      this.site.set("auth_providers", originalAuthProviders);
      clearAuthMethods();
    });

    test("renders available methods from model and excludes custom_url providers", async function (assert) {
      this.site.set("auth_providers", [
        {
          name: "facebook",
          custom_url: null,
          pretty_name_override: "Facebook",
          title_override: null,
          frame_width: 580,
          frame_height: 400,
          can_connect: true,
          can_revoke: true,
        },
        {
          name: "custom_sso",
          custom_url: "https://example.com/auth",
          pretty_name_override: "Custom SSO",
          title_override: null,
          frame_width: 580,
          frame_height: 400,
          can_connect: true,
          can_revoke: true,
        },
      ]);

      this.model = {
        methods: {
          password: true,
          passkey: true,
          email_code: true,
          external_providers: ["facebook", "custom_sso"],
        },
      };

      await render(
        <template><ConfirmSession @model={{this.model}} /></template>
      );

      assert.dom(".confirm-session #password").exists();
      assert.dom(".confirm-session__passkey .btn").exists();
      assert.dom(".confirm-session__email-code .btn").exists();
      assert.dom(".confirm-session__email-code .btn").hasClass("btn-default");
      assert.dom(".confirm-session__provider-btn.facebook").exists();
      assert.dom(".confirm-session__provider-btn.custom_sso").doesNotExist();
    });

    test("hides password form when unavailable and makes email code primary when sole method", async function (assert) {
      this.model = {
        methods: {
          password: false,
          passkey: false,
          email_code: true,
          external_providers: [],
        },
      };

      await render(
        <template><ConfirmSession @model={{this.model}} /></template>
      );

      assert.dom(".confirm-session #password").doesNotExist();
      assert.dom(".confirm-session__passkey").doesNotExist();
      assert.dom(".confirm-session__external-providers").doesNotExist();
      assert
        .dom(".confirm-session__email-code .btn")
        .hasClass("btn-primary")
        .hasText(i18n("user.confirm_access.send_email_code"));
    });

    test("handles email code request, resend, validation, errors, and confirmation", async function (assert) {
      let sendCodeCalls = 0;
      let confirmCalls = 0;
      let confirmed = false;

      const dialog = this.owner.lookup("service:dialog");
      dialog.didConfirm = () => {
        confirmed = true;
      };

      pretender.post("/u/confirm-session/email-code.json", () => {
        sendCodeCalls++;
        return response({ success: "OK", email: "robin@example.com" });
      });
      pretender.post("/u/confirm-session.json", (request) => {
        confirmCalls++;
        const code = new URLSearchParams(request.requestBody).get("email_code");
        if (code === "654321") {
          return response({ success: "OK" });
        }
        return response({
          failed: "FAILED",
          error: "Invalid verification code.",
        });
      });

      this.model = {
        methods: {
          password: true,
          passkey: false,
          email_code: true,
          external_providers: [],
        },
      };

      await render(
        <template><ConfirmSession @model={{this.model}} /></template>
      );

      await click(".confirm-session__email-code .btn");

      assert.strictEqual(sendCodeCalls, 1);
      assert.dom(".confirm-session__code-step").exists();
      assert
        .dom(".confirm-session__code-instructions")
        .includesText("robin@example.com");

      await click(".confirm-session__resend-code");

      assert.strictEqual(sendCodeCalls, 2);
      assert
        .dom(".confirm-session__notice")
        .hasText(i18n("user.confirm_access.code_resent"));

      await fillIn(".confirm-session .d-otp-input", "123");
      await click(".confirm-session__confirm-code");

      assert
        .dom(".alert.alert-error")
        .hasText(i18n("user.confirm_access.incorrect_code"));
      assert.strictEqual(confirmCalls, 0);

      await fillIn(".confirm-session .d-otp-input", "000000");

      assert.strictEqual(confirmCalls, 1);
      assert.dom(".confirm-session__notice").doesNotExist();
      assert.dom(".alert.alert-error").hasText("Invalid verification code.");
      assert.dom(".confirm-session .d-otp-input").hasValue("");

      await fillIn(".confirm-session .d-otp-input", "654321");

      assert.strictEqual(confirmCalls, 2);
      assert.true(
        confirmed,
        "invokes dialog didConfirm after valid email code"
      );
    });

    test("returns to method selector when clicking use another method", async function (assert) {
      pretender.post("/u/confirm-session/email-code.json", () =>
        response({ success: "OK", email: "robin@example.com" })
      );

      this.model = {
        methods: {
          password: true,
          passkey: false,
          email_code: true,
          external_providers: [],
        },
      };

      await render(
        <template><ConfirmSession @model={{this.model}} /></template>
      );

      await click(".confirm-session__email-code .btn");
      assert.dom(".confirm-session__code-step").exists();
      assert.dom(".confirm-session #password").doesNotExist();

      await click(".confirm-session__another-method");
      assert.dom(".confirm-session__code-step").doesNotExist();
      assert.dom(".confirm-session #password").exists();
    });

    test("starts external confirmation with origin when clicking an external provider", async function (assert) {
      this.site.set("auth_providers", [
        {
          name: "facebook",
          custom_url: null,
          pretty_name_override: "Facebook",
          title_override: null,
          frame_width: 580,
          frame_height: 400,
          can_connect: true,
          can_revoke: true,
        },
      ]);

      const doLoginStub = sinon
        .stub(LoginMethod.prototype, "doLogin")
        .resolves();

      this.model = {
        methods: {
          password: false,
          passkey: false,
          email_code: false,
          external_providers: ["facebook"],
        },
      };

      await render(
        <template><ConfirmSession @model={{this.model}} /></template>
      );

      await click(".confirm-session__provider-btn.facebook");

      assert.true(
        doLoginStub.calledOnceWithExactly({
          confirmSession: true,
          params: {
            origin: window.location.pathname + window.location.search,
          },
        }),
        "calls LoginMethod#doLogin with confirmSession and current origin"
      );
    });
  }
);
