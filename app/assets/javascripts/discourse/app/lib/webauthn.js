import I18n from "discourse-i18n";

export function stringToBuffer(str) {
  let buffer = new ArrayBuffer(str.length);
  let byteView = new Uint8Array(buffer);
  for (let i = 0; i < str.length; i++) {
    byteView[i] = str.charCodeAt(i);
  }
  return buffer;
}

export function bufferToBase64(buffer) {
  return btoa(String.fromCharCode(...new Uint8Array(buffer)));
}

export function isWebauthnSupported() {
  return typeof PublicKeyCredential !== "undefined";
}

export function getWebauthnCredential(
  challenge,
  allowedCredentialIds,
  successCallback,
  errorCallback
) {
  if (!isWebauthnSupported()) {
    return errorCallback(I18n.t("login.security_key_support_missing_error"));
  }

  let challengeBuffer = stringToBuffer(challenge);
  let allowCredentials = allowedCredentialIds.map((credentialId) => {
    return {
      id: stringToBuffer(atob(credentialId)),
      type: "public-key",
    };
  });
  // See https://w3c.github.io/webauthn/#sctn-verifying-assertion for the steps followed here.

  // 1. Let options be a new PublicKeyCredentialRequestOptions structure configured to the Relying Party's needs
  // 2. Call navigator.credentials.get() and pass options as the publicKey option.
  navigator.credentials
    .get({
      publicKey: {
        challenge: challengeBuffer,
        allowCredentials,
        timeout: 60000, // this is just a hint
        // in the backend, we don't check for user verification for 2FA
        // therefore we should indicate to browser that it's not necessary
        // (this is only a hint, though, browser may still prompt)
        userVerification: "discouraged",
      },
    })
    .then((credential) => {
      // 3. If credential.response is not an instance of AuthenticatorAssertionResponse, abort the ceremony.
      // eslint-disable-next-line no-undef
      if (!(credential.response instanceof AuthenticatorAssertionResponse)) {
        return errorCallback(
          I18n.t("login.security_key_invalid_response_error")
        );
      }

      // 4. Let clientExtensionResults be the result of calling credential.getClientExtensionResults().
      // We are not using this

      // 5. If options.allowCredentials is not empty, verify that credential.id identifies one of the public key
      // credentials listed in options.allowCredentials.
      if (
        !allowedCredentialIds.some(
          (credentialId) => bufferToBase64(credential.rawId) === credentialId
        )
      ) {
        return errorCallback(
          I18n.t("login.security_key_no_matching_credential_error")
        );
      }

      const credentialData = {
        signature: bufferToBase64(credential.response.signature),
        clientData: bufferToBase64(credential.response.clientDataJSON),
        authenticatorData: bufferToBase64(
          credential.response.authenticatorData
        ),
        credentialId: bufferToBase64(credential.rawId),
      };

      successCallback(credentialData);
      // steps 6+ of this flow are handled by lib/discourse_webauthn/authentication_service.rb
    })
    .catch((err) => {
      if (err.name === "NotAllowedError") {
        return errorCallback(I18n.t("login.security_key_not_allowed_error"));
      }
      errorCallback(err);
    });
}

export async function getPasskeyCredential(challenge, errorCallback) {
  if (!isWebauthnSupported()) {
    return errorCallback(I18n.t("login.security_key_support_missing_error"));
  }

  return navigator.credentials
    .get({
      publicKey: {
        challenge: stringToBuffer(challenge),
        // https://www.w3.org/TR/webauthn-2/#user-verification
        // for passkeys (first factor), user verification should be marked as required
        // it ensures browser requests PIN or biometrics before authenticating
        // lib/discourse_webauthn/authentication_service.rb requires this flag too
        userVerification: "required",
      },
    })
    .then((credential) => {
      return {
        signature: bufferToBase64(credential.response.signature),
        clientData: bufferToBase64(credential.response.clientDataJSON),
        authenticatorData: bufferToBase64(
          credential.response.authenticatorData
        ),
        credentialId: bufferToBase64(credential.rawId),
        userHandle: bufferToBase64(credential.response.userHandle),
      };
    })
    .catch((err) => {
      if (err.name === "NotAllowedError") {
        return errorCallback(I18n.t("login.security_key_not_allowed_error"));
      }
      errorCallback(err);
    });
}
