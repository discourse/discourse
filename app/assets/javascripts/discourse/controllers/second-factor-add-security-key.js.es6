import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import {
  bufferToBase64,
  stringToBuffer,
  isWebauthnSupported
} from "discourse/lib/webauthn";

// model for this controller is user.js.es6
export default Controller.extend(ModalFunctionality, {
  loading: false,
  errorMessage: null,

  onShow() {
    // clear properties every time because the controller is a singleton
    this.setProperties({
      errorMessage: null,
      loading: true,
      securityKeyName: I18n.t("user.second_factor.security_key.default_name"),
      webauthnUnsupported: !isWebauthnSupported()
    });

    this.model
      .requestSecurityKeyChallenge()
      .then(response => {
        if (response.error) {
          this.set("errorMessage", response.error);
          return;
        }

        this.setProperties({
          errorMessage: isWebauthnSupported()
            ? null
            : I18n.t("login.security_key_support_missing_error"),
          loading: false,
          challenge: response.challenge,
          relayingParty: {
            id: response.rp_id,
            name: response.rp_name
          },
          supported_algoriths: response.supported_algoriths,
          user_secure_id: response.user_secure_id,
          existing_active_credential_ids:
            response.existing_active_credential_ids
        });
      })
      .catch(error => {
        this.send("closeModal");
        this.onError(error);
      })
      .finally(() => this.set("loading", false));
  },

  actions: {
    registerSecurityKey() {
      const publicKeyCredentialCreationOptions = {
        challenge: Uint8Array.from(this.challenge, c => c.charCodeAt(0)),
        rp: {
          name: this.relayingParty.name,
          id: this.relayingParty.id
        },
        user: {
          id: Uint8Array.from(this.user_secure_id, c => c.charCodeAt(0)),
          displayName: this.model.username_lower,
          name: this.model.username_lower
        },
        pubKeyCredParams: this.supported_algoriths.map(alg => {
          return { type: "public-key", alg: alg };
        }),
        excludeCredentials: this.existing_active_credential_ids.map(
          credentialId => {
            return {
              type: "public-key",
              id: stringToBuffer(atob(credentialId))
            };
          }
        ),
        timeout: 20000,
        attestation: "none",
        authenticatorSelection: {
          // see https://chromium.googlesource.com/chromium/src/+/master/content/browser/webauth/uv_preferred.md for why
          // default value of preferred is not necesarrily what we want, it limits webauthn to only devices that support
          // user verification, which usually requires entering a PIN
          userVerification: "discouraged"
        }
      };

      navigator.credentials
        .create({
          publicKey: publicKeyCredentialCreationOptions
        })
        .then(
          credential => {
            let serverData = {
              id: credential.id,
              rawId: bufferToBase64(credential.rawId),
              type: credential.type,
              attestation: bufferToBase64(
                credential.response.attestationObject
              ),
              clientData: bufferToBase64(credential.response.clientDataJSON),
              name: this.securityKeyName
            };

            this.model
              .registerSecurityKey(serverData)
              .then(response => {
                if (response.error) {
                  this.set("errorMessage", response.error);
                  return;
                }
                this.markDirty();
                this.set("errorMessage", null);
                this.send("closeModal");
              })
              .catch(error => this.onError(error))
              .finally(() => this.set("loading", false));
          },
          err => {
            if (err.name === "InvalidStateError") {
              return this.set(
                "errorMessage",
                I18n.t("user.second_factor.security_key.already_added_error")
              );
            }
            if (err.name === "NotAllowedError") {
              return this.set(
                "errorMessage",
                I18n.t("user.second_factor.security_key.not_allowed_error")
              );
            }
            this.set("errorMessage", err.message);
          }
        );
    }
  }
});
