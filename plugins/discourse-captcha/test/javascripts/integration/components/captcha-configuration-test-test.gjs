import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { i18n } from "discourse-i18n";
import CaptchaConfigurationTest from "discourse/plugins/discourse-captcha/discourse/components/captcha-configuration-test";

module("Integration | Component | CaptchaConfigurationTest", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.configuration = {
      configured: true,
      provider: "recaptcha",
      site_key: "saved-site-key",
    };
    this.originalRecaptcha = window.grecaptcha;
    this.originalHcaptcha = window.hcaptcha;
    this.originalRecaptchaCallback = window.discourseReCaptchaCallback;
    window.grecaptcha = window.hcaptcha = {
      render: (element, options) => {
        this.widgetOptions = options;
        return 1;
      },
    };
  });

  hooks.afterEach(function () {
    this.scriptStub?.restore();
    window.discourseReCaptchaCallback = this.originalRecaptchaCallback;
    window.grecaptcha = this.originalRecaptcha;
    window.hcaptcha = this.originalHcaptcha;
  });

  test("verifies saved keys and keeps signup state separate", async function (assert) {
    const captchaService = this.owner.lookup("service:captcha-service");
    captchaService.token = "signup-token";
    captchaService.invalid = false;
    pretender.post("/admin/plugins/discourse-captcha/test.json", (request) => {
      const data = new URLSearchParams(request.requestBody);
      assert.strictEqual(
        data.get("token"),
        "test-token",
        "sends the challenge token"
      );
      assert.strictEqual(
        data.get("site_key"),
        "saved-site-key",
        "identifies the tested site key"
      );
      assert.strictEqual(
        data.get("provider"),
        "recaptcha",
        "identifies the tested provider"
      );
      return response({ success: true, message: "Verification succeeded." });
    });

    await render(
      <template>
        <CaptchaConfigurationTest @configuration={{this.configuration}} />
      </template>
    );
    assert
      .dom("#g-recaptcha")
      .doesNotExist("waits for an explicit test action");
    await click(".captcha-configuration-test .btn-primary");
    assert.strictEqual(
      this.widgetOptions.sitekey,
      "saved-site-key",
      "renders the saved site key"
    );

    this.widgetOptions.callback("test-token");
    await settled();

    assert
      .dom(".alert-success")
      .hasText("Verification succeeded.", "displays the verification result");
    assert.strictEqual(
      captchaService.token,
      "signup-token",
      "preserves the signup token"
    );
    assert.false(captchaService.invalid, "preserves signup validity");
    assert
      .dom(".captcha-configuration-test .btn-primary")
      .hasText(
        i18n("discourse_captcha.configuration_test.retry"),
        "offers another test"
      );
  });

  test("shows provider failures and allows a fresh challenge", async function (assert) {
    this.configuration.provider = "hcaptcha";
    pretender.post("/admin/plugins/discourse-captcha/test.json", () =>
      response({ success: false, message: "The secret key was rejected." })
    );

    await render(
      <template>
        <CaptchaConfigurationTest @configuration={{this.configuration}} />
      </template>
    );
    await click(".captcha-configuration-test .btn-primary");
    this.widgetOptions.callback("test-token");
    await settled();

    assert
      .dom(".alert-error")
      .hasText("The secret key was rejected.", "displays the provider failure");

    await click(".captcha-configuration-test .btn-primary");
    assert.dom("#h-captcha-field").exists("renders a new hCaptcha challenge");
    assert.dom(".alert-error").doesNotExist("clears the previous result");
  });

  test("handles expiration and widget errors", async function (assert) {
    await render(
      <template>
        <CaptchaConfigurationTest @configuration={{this.configuration}} />
      </template>
    );
    await click(".captcha-configuration-test .btn-primary");
    this.widgetOptions["expired-callback"]();
    await settled();

    assert
      .dom(".alert-error")
      .hasText(
        i18n("discourse_captcha.configuration_test.expired"),
        "explains expiration"
      );

    await click(".captcha-configuration-test .btn-primary");
    this.widgetOptions["error-callback"]();
    await settled();

    assert
      .dom(".alert-error")
      .hasText(
        i18n("discourse_captcha.configuration_test.challenge_failed"),
        "explains a widget failure"
      );
    assert.dom("#g-recaptcha").exists("keeps provider error details visible");
    assert
      .dom(".captcha-configuration-test")
      .doesNotIncludeText(
        i18n("discourse_captcha.configuration_test.complete_challenge"),
        "hides completion instructions after failure"
      );
    await click(".captcha-configuration-test .btn-primary");
    assert.dom(".alert-error").doesNotExist("clears the failed state on retry");
  });

  test("offers a retry when the provider script fails to load", async function (assert) {
    const captchaApi = window.grecaptcha;
    delete window.grecaptcha;
    const appendChild = document.head.appendChild;
    this.scriptStub = sinon
      .stub(document.head, "appendChild")
      .callsFake(function (element) {
        if (
          element.tagName === "SCRIPT" &&
          element.src.includes("/recaptcha/api.js")
        ) {
          queueMicrotask(() => element.dispatchEvent(new Event("error")));
          return element;
        }
        return appendChild.call(this, element);
      });

    await render(
      <template>
        <CaptchaConfigurationTest @configuration={{this.configuration}} />
      </template>
    );
    await click(".captcha-configuration-test .btn-primary");

    assert
      .dom(".alert-error")
      .exists({ count: 1 }, "shows a single failure message");
    assert
      .dom(".captcha-configuration-test")
      .doesNotIncludeText(
        i18n("discourse_captcha.configuration_test.complete_challenge"),
        "hides instructions for the unavailable challenge"
      );
    assert
      .dom(".captcha-configuration-test .btn-primary")
      .hasText(
        i18n("discourse_captcha.configuration_test.retry"),
        "offers a retry"
      );

    window.grecaptcha = captchaApi;
    await click(".captcha-configuration-test .btn-primary");
    assert.dom("#g-recaptcha").exists("loads the challenge after recovery");
    assert.dom(".alert-error").doesNotExist("clears the failure");
  });

  for (const provider of ["recaptcha", "hcaptcha"]) {
    test(`${provider} ignores callbacks from a replaced challenge`, async function (assert) {
      this.configuration.provider = provider;
      let verificationRequests = 0;
      pretender.post("/admin/plugins/discourse-captcha/test.json", () => {
        verificationRequests++;
        return response({ success: true, message: "Verified" });
      });

      await render(
        <template>
          <CaptchaConfigurationTest @configuration={{this.configuration}} />
        </template>
      );
      await click(".captcha-configuration-test .btn-primary");
      const previousWidget = this.widgetOptions;
      previousWidget["error-callback"]();
      await settled();
      await click(".captcha-configuration-test .btn-primary");

      previousWidget["expired-callback"]();
      previousWidget["error-callback"]();
      previousWidget.callback("old-token");
      await settled();

      assert
        .dom(".captcha-container")
        .exists("keeps the current challenge visible");
      assert
        .dom(".alert-error")
        .doesNotExist("ignores previous errors and expiration");
      assert.strictEqual(
        verificationRequests,
        0,
        "does not verify an old challenge token"
      );

      this.widgetOptions.callback("current-token");
      await settled();
      assert
        .dom(".alert-success")
        .hasText("Verified", "the current challenge still works");
      assert.strictEqual(
        verificationRequests,
        1,
        "verifies only the current challenge"
      );
    });
  }

  test("explains missing configuration before loading a challenge", async function (assert) {
    this.configuration.configured = false;

    await render(
      <template>
        <CaptchaConfigurationTest @configuration={{this.configuration}} />
      </template>
    );

    assert
      .dom(".alert-info")
      .hasText(
        i18n("discourse_captcha.configuration_test.not_configured"),
        "explains which settings are needed"
      );
    assert
      .dom(".captcha-configuration-test button")
      .doesNotExist("does not offer an unconfigured test");
  });

  test("displays request errors", async function (assert) {
    pretender.post("/admin/plugins/discourse-captcha/test.json", () =>
      response(429, { errors: ["Please wait before trying again."] })
    );
    await render(
      <template>
        <CaptchaConfigurationTest @configuration={{this.configuration}} />
      </template>
    );
    await click(".captcha-configuration-test .btn-primary");
    this.widgetOptions.callback("test-token");
    await settled();

    assert.dom(".alert-error").hasText(
      i18n("generic_error_with_reason", {
        error: "Please wait before trying again.",
      }),
      "displays the server error"
    );
  });
});
