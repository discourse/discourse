import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

const RESPONSES = {
  totponly: {
    can_login: true,
    token: "totponly",
    token_email: "eviltrout@example.com",
    second_factor_required: true,
    totp_enabled: true,
    backup_codes_enabled: false,
  },
  passkeyonly: {
    can_login: true,
    token: "passkeyonly",
    token_email: "eviltrout@example.com",
    passkeys_enabled: true,
    security_key_required: false,
    passkey_allowed_credential_ids: ["cGFzc2tleS1jcmVkZW50aWFs"],
    challenge: "somechallenge",
  },
  mixedwebauthn: {
    can_login: true,
    token: "mixedwebauthn",
    token_email: "eviltrout@example.com",
    passkeys_enabled: true,
    security_key_required: true,
    allowed_credential_ids: ["c2VjdXJpdHkta2V5LWNyZWRlbnRpYWw="],
    passkey_allowed_credential_ids: ["cGFzc2tleS1jcmVkZW50aWFs"],
    challenge: "somechallenge",
  },
};

function stubWebauthnCredentialGet() {
  const calls = [];
  sinon.stub(navigator.credentials, "get").callsFake((options) => {
    calls.push(options);
    const error = new Error("credential get cancelled in tests");
    error.name = "NotAllowedError";
    return Promise.reject(error);
  });
  return calls;
}

acceptance("Email login", function (needs) {
  needs.pretender((server, helper) => {
    Object.keys(RESPONSES).forEach((token) => {
      server.get(`/session/email-login/${token}.json`, () =>
        helper.response(RESPONSES[token])
      );
    });
  });

  test("second factor with TOTP", async function (assert) {
    await visit("/session/email-login/totponly");

    assert.dom("#second-factor").exists("shows the second factor token prompt");
    assert
      .dom(".email-login-form .btn-primary")
      .exists("shows the confirm button");
  });

  test("second factor with a passkey only", async function (assert) {
    const calls = stubWebauthnCredentialGet();

    await visit("/session/email-login/passkeyonly");

    assert
      .dom("#passkey-authenticate-button")
      .exists("shows the passkey button");
    assert
      .dom("#security-key-authenticate-button")
      .doesNotExist("security key button is not shown without a security key");
    assert
      .dom(".email-login-form button[type='submit']")
      .doesNotExist("hides the confirm button while a ceremony is offered");

    await click("#passkey-authenticate-button");
    assert.strictEqual(
      calls[0].publicKey.userVerification,
      "required",
      "the passkey ceremony requires user verification"
    );
  });

  test("second factor with a passkey and a security key", async function (assert) {
    const calls = stubWebauthnCredentialGet();

    await visit("/session/email-login/mixedwebauthn");

    assert
      .dom("#passkey-authenticate-button")
      .exists("shows the passkey button");
    assert
      .dom("#security-key-authenticate-button")
      .exists("shows the security key button");

    await click("#security-key-authenticate-button");
    assert.strictEqual(
      calls[0].publicKey.userVerification,
      "discouraged",
      "the security key ceremony discourages user verification"
    );
  });
});
