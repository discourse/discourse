import { stringToBuffer, bufferToBase64 } from "discourse/lib/utilities";

export function getWebauthnCredential(
  challenge,
  allowedCredentialIds,
  successCallback,
  errorCallback
) {
  if (typeof PublicKeyCredential === "undefined") {
    return errorCallback(I18n.t("login.security_key_support_missing_error"));
  }

  let challengeBuffer = stringToBuffer(challenge);
  let allowCredentials = allowedCredentialIds.map(credentialId => {
    return {
      id: stringToBuffer(atob(credentialId)),
      type: "public-key"
    };
  });

  navigator.credentials
    .get({
      publicKey: {
        challenge: challengeBuffer,
        allowCredentials: allowCredentials,
        timeout: 60000,

        // see https://chromium.googlesource.com/chromium/src/+/master/content/browser/webauth/uv_preferred.md for why
        // default value of preferred is not necesarrily what we want, it limits webauthn to only devices that support
        // user verification, which usually requires entering a PIN
        userVerification: "discouraged"
      }
    })
    .then(credential => {
      // 1. if there is a credential, check if the raw ID base64 matches
      // any of the allowed credential ids
      if (
        !allowedCredentialIds.some(
          credentialId => bufferToBase64(credential.rawId) === credentialId
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
        credentialId: bufferToBase64(credential.rawId)
      };
      successCallback(credentialData);
    })
    .catch(err => {
      if (err.name === "NotAllowedError") {
        return errorCallback(I18n.t("login.security_key_not_allowed_error"));
      }
      errorCallback(err);
    });
}
