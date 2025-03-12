import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import {
  bufferToBase64,
  isWebauthnSupported,
  stringToBuffer,
} from "discourse/lib/webauthn";
import { MAX_SECOND_FACTOR_NAME_LENGTH } from "discourse/models/user";
import { i18n } from "discourse-i18n";

export default class SecondFactorAddSecurityKey extends Component {
  @service capabilities;

  @tracked loading = false;
  @tracked errorMessage = null;
  @tracked securityKeyName;

  maxSecondFactorNameLength = MAX_SECOND_FACTOR_NAME_LENGTH;

  get webauthnUnsupported() {
    return !isWebauthnSupported();
  }

  @action
  securityKeyRequested() {
    let key;
    if (this.capabilities.isIOS && !this.capabilities.isIpadOS) {
      key = "user.second_factor.security_key.iphone_default_name";
    } else if (this.capabilities.isAndroid) {
      key = "user.second_factor.security_key.android_default_name";
    } else {
      key = "user.second_factor.security_key.default_name";
    }
    this.securityKeyName = i18n(key);

    this.loading = true;
    this.args.model.secondFactor
      .requestSecurityKeyChallenge()
      .then((response) => {
        if (response.error) {
          this.errorMessage = response.error;
          return;
        }

        this.errorMessage = isWebauthnSupported()
          ? null
          : i18n("login.security_key_support_missing_error");
        this.loading = false;
        this.challenge = response.challenge;
        this.relayingParty = {
          id: response.rp_id,
          name: response.rp_name,
        };
        this.supported_algorithms = response.supported_algorithms;
        this.user_secure_id = response.user_secure_id;
        this.existing_active_credential_ids =
          response.existing_active_credential_ids;
      })
      .catch((error) => {
        this.args.closeModal();
        this.args.model.onError(error);
      })
      .finally(() => (this.loading = false));
  }

  @action
  registerSecurityKey() {
    if (!this.securityKeyName) {
      this.errorMessage = i18n(
        "user.second_factor.security_key.name_required_error"
      );
      return;
    }
    const publicKeyCredentialCreationOptions = {
      challenge: Uint8Array.from(this.challenge, (c) => c.charCodeAt(0)),
      rp: {
        name: this.relayingParty.name,
        id: this.relayingParty.id,
      },
      user: {
        id: Uint8Array.from(this.user_secure_id, (c) => c.charCodeAt(0)),
        displayName: this.args.model.secondFactor.username_lower,
        name: this.args.model.secondFactor.username_lower,
      },
      pubKeyCredParams: this.supported_algorithms.map((alg) => {
        return { type: "public-key", alg };
      }),
      excludeCredentials: this.existing_active_credential_ids.map(
        (credentialId) => {
          return {
            type: "public-key",
            id: stringToBuffer(atob(credentialId)),
          };
        }
      ),
      timeout: 20000,
      attestation: "none",
      authenticatorSelection: {
        // see https://chromium.googlesource.com/chromium/src/+/master/content/browser/webauth/uv_preferred.md for why
        // default value of preferred is not necessarily what we want, it limits webauthn to only devices that support
        // user verification, which usually requires entering a PIN
        userVerification: "discouraged",
      },
    };

    navigator.credentials
      .create({
        publicKey: publicKeyCredentialCreationOptions,
      })
      .then(
        (credential) => {
          let serverData = {
            id: credential.id,
            rawId: bufferToBase64(credential.rawId),
            type: credential.type,
            attestation: bufferToBase64(credential.response.attestationObject),
            clientData: bufferToBase64(credential.response.clientDataJSON),
            name: this.securityKeyName,
          };

          this.args.model.secondFactor
            .registerSecurityKey(serverData)
            .then((response) => {
              if (response.error) {
                this.errorMessage = response.error;
                return;
              }
              this.args.model.markDirty();
              this.errorMessage = null;
              this.args.closeModal();
              if (this.args.model.enforcedSecondFactor) {
                window.location.reload();
              }
            })
            .catch((error) => this.args.model.onError(error))
            .finally(() => (this.loading = false));
        },
        (err) => {
          if (err.name === "InvalidStateError") {
            this.errorMessage = i18n(
              "user.second_factor.security_key.already_added_error"
            );
            return;
          }
          if (err.name === "NotAllowedError") {
            this.errorMessage = i18n(
              "user.second_factor.security_key.not_allowed_error"
            );
            return;
          }
          this.errorMessage = err.message;
        }
      );
  }
}
