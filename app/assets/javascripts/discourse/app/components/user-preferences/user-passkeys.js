import I18n from "I18n";
import { bufferToBase64, stringToBuffer } from "discourse/lib/webauthn";
import { popupAjaxError } from "discourse/lib/ajax-error";
import RenamePasskey from "discourse/components/user-preferences/rename-passkey";
import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

export default class UserPasskeys extends Component {
  @service dialog;
  @service currentUser;

  get isCurrentUser() {
    return this.currentUser.id === this.args.model.id;
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
              name: "placeholder",
            };

            this.args.model
              .registerPasskey(serverData)
              .then((resp) => {
                if (resp.error) {
                  popupAjaxError(resp.error);
                  return;
                }

                // Show rename alert after creating/saving new key
                this.dialog.dialog({
                  title: "Success! Passkey was created.",
                  type: "notice",
                  bodyComponent: RenamePasskey,
                  bodyComponentModel: resp,
                });
              })
              .catch(popupAjaxError);
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
      title: "Are you sure you want to delete this passkey?",
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
      title: "Rename Passkey",
      type: "notice",
      bodyComponent: RenamePasskey,
      bodyComponentModel: { id, name },
    });
  }
}
