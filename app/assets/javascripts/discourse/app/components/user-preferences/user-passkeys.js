import I18n from "I18n";
import { bufferToBase64, stringToBuffer } from "discourse/lib/webauthn";
import RenamePasskey from "discourse/components/user-preferences/rename-passkey";
import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

export default class UserPasskeys extends Component {
  @service dialog;
  @service currentUser;
  @service capabilities;

  get isCurrentUser() {
    return this.currentUser.id === this.args.model.id;
  }

  get passkeyName() {
    if (this.capabilities.isSafari) {
      return I18n.t("user.first_factor.name.icloud_keychain");
    }

    if (this.capabilities.isAndroid || this.capabilities.isChrome) {
      return I18n.t("user.first_factor.name.google_password_manager");
    }

    return I18n.t("user.first_factor.name.default");
  }

  @action
  addPasskey() {
    this.args.model.createPasskey().then((response) => {
      const publicKeyCredentialCreationOptions = {
        challenge: Uint8Array.from(response.challenge, (c) => c.charCodeAt(0)),
        rp: {
          name: response.rp_name,
          id: response.rp_id,
        },
        user: {
          id: Uint8Array.from(response.user_secure_id, (c) => c.charCodeAt(0)),
          name: this.currentUser.username,
          displayName: this.currentUser.username,
        },
        pubKeyCredParams: response.supported_algorithms.map((alg) => {
          return { type: "public-key", alg };
        }),
        excludeCredentials: response.existing_passkey_credential_ids.map(
          (credentialId) => {
            return {
              type: "public-key",
              id: stringToBuffer(atob(credentialId)),
            };
          }
        ),
        authenticatorSelection: {
          // https://www.w3.org/TR/webauthn-2/#user-verification
          // for passkeys (first factor), user verification should be marked as required
          // it ensures browser prompts user for PIN/fingerprint/faceID before authenticating
          userVerification: "required",
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
              attestation: bufferToBase64(
                credential.response.attestationObject
              ),
              clientData: bufferToBase64(credential.response.clientDataJSON),
              name: this.passkeyName,
            };

            this.args.model
              .registerPasskey(serverData)
              .then((resp) => {
                if (resp.error) {
                  this.dialog.alert(resp.error);
                  return;
                }

                // Show rename alert after creating/saving new key
                this.dialog.dialog({
                  title: I18n.t(
                    "user.first_factor.passkey_successfully_created"
                  ),
                  type: "notice",
                  bodyComponent: RenamePasskey,
                  bodyComponentModel: resp,
                  didCancel: () => {
                    // TODO(pmusaraj): avoid refreshing the page
                    window.location.reload();
                  },
                });
              })
              .catch((res) => {
                this.dialog.alert(res.error);
              });
          },
          (err) => {
            if (err.name === "InvalidStateError") {
              this.errorMessage = I18n.t(
                "user.second_factor.security_key.already_added_error"
              );
            }
            if (err.name === "NotAllowedError") {
              this.errorMessage = I18n.t(
                "user.second_factor.security_key.not_allowed_error"
              );
            }
            this.dialog.alert(this.errorMessage);
          }
        );
    });
  }

  @action
  deletePasskey(id) {
    this.dialog.deleteConfirm({
      title: I18n.t("user.first_factor.confirm_delete_passkey"),
      didConfirm: () => {
        this.args.model.deletePasskey(id).then(() => {
          window.location.reload();
        });
      },
    });
  }

  @action
  renamePasskey(id, name) {
    this.dialog.dialog({
      title: I18n.t("user.first_factor.rename_passkey"),
      type: "notice",
      bodyComponent: RenamePasskey,
      bodyComponentModel: { id, name },
    });
  }
}
