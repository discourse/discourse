import { click, fillIn, tab, visit } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import { acceptance, chromeTest } from "discourse/tests/helpers/qunit-helpers";
import I18n from "discourse-i18n";

acceptance("Modal - Login", function () {
  chromeTest("You can tab to the login button", async function (assert) {
    await visit("/");
    await click("header .login-button");
    // you have to press the tab key thrice to get to the login button
    await tab({ unRestrainTabIndex: true });
    await tab({ unRestrainTabIndex: true });
    await tab({ unRestrainTabIndex: true });
    assert.dom(".d-modal__footer #login-button").isFocused();
  });
});

acceptance("Modal - Login - With 2FA", function (needs) {
  needs.settings({
    enable_local_logins_via_email: true,
  });

  needs.pretender((server, helper) => {
    server.post(`/session`, () =>
      helper.response({
        error: I18n.t("login.invalid_second_factor_code"),
        multiple_second_factor_methods: false,
        security_key_enabled: false,
        totp_enabled: true,
      })
    );
  });

  test("You can tab to 2FA login button", async function (assert) {
    await visit("/");
    await click("header .login-button");

    await fillIn("#login-account-name", "isaac@discourse.org");
    await fillIn("#login-account-password", "password");
    await click("#login-button");

    assert.dom("#login-second-factor").isFocused();
    await tab();
    assert.dom("#login-button").isFocused();
  });
});

acceptance("Modal - Login - With Passkeys enabled", function () {
  test("Includes passkeys button and conditional UI", async function (assert) {
    await visit("/");
    await click("header .login-button");

    assert.dom(".passkey-login-button").exists();

    assert
      .dom("#login-account-name")
      .hasAttribute("autocomplete", "username webauthn");
  });
});

acceptance("Modal - Login - With Passkeys disabled", function (needs) {
  needs.settings({
    enable_passkeys: false,
  });

  test("Excludes passkeys button and conditional UI", async function (assert) {
    await visit("/");
    await click("header .login-button");

    assert.dom(".passkey-login-button").doesNotExist();
    assert.dom("#login-account-name").hasAttribute("autocomplete", "username");
  });
});

acceptance("Modal - Login - Passkeys on mobile", function (needs) {
  needs.mobileView();

  test("Includes passkeys button and conditional UI", async function (assert) {
    await visit("/");
    await click("header .login-button");

    sinon.stub(navigator.credentials, "get").callsFake(function () {
      return Promise.reject(new Error("credentials.get got called"));
    });

    assert
      .dom("#login-account-name")
      .hasAttribute("autocomplete", "username webauthn");

    await click(".passkey-login-button");

    // clicking the button triggers credentials.get
    // but we can't really test that in frontend so an error is returned
    assert.dom(".dialog-body").exists();
  });
});

acceptance("Modal - Login - With no way to login", function (needs) {
  needs.settings({
    enable_local_logins: false,
    enable_facebook_logins: false,
  });
  needs.site({ auth_providers: [] });

  test("Displays a helpful message", async function (assert) {
    await visit("/");
    await click("header .login-button");

    assert.dom("#login-account-name").doesNotExist();
    assert.dom("#login-button").doesNotExist();
    assert.dom(".no-login-methods-configured").exists();
  });
});

acceptance("Login button", function () {
  test("with custom event on webview", async function (assert) {
    const capabilities = this.container.lookup("service:capabilities");
    sinon.stub(capabilities, "isAppWebview").value(true);

    window.ReactNativeWebView = {
      postMessage: () => {},
    };

    const webviewSpy = sinon.spy(window.ReactNativeWebView, "postMessage");

    await visit("/");
    await click("header .login-button");

    assert.true(
      webviewSpy.withArgs('{"showLogin":true}').calledOnce,
      "triggers postmessage event"
    );

    delete window.ReactNativeWebView;
  });
});
