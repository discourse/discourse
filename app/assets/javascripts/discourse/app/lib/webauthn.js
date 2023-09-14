import I18n from "I18n";

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
      // 1. if there is a credential, check if the raw ID base64 matches
      // any of the allowed credential ids
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
    })
    .catch((err) => {
      if (err.name === "NotAllowedError") {
        return errorCallback(I18n.t("login.security_key_not_allowed_error"));
      }
      errorCallback(err);
    });
}

export async function prepPasskeyCredential(challenge, errorCallback) {
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
      };
    })
    .catch((err) => {
      if (err.name === "NotAllowedError") {
        return errorCallback(I18n.t("login.security_key_not_allowed_error"));
      }
      errorCallback(err);
    });
}
