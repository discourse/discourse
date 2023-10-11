import Component from "@glimmer/component";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import { inject as service } from "@ember/service";
import ConfirmSession from "discourse/components/dialog-messages/confirm-session";
import RenamePasskey from "discourse/components/user-preferences/rename-passkey";
import { bufferToBase64, stringToBuffer } from "discourse/lib/webauthn";
import I18n from "I18n";

export default class UserPasskeys extends Component {
  @service dialog;
  @service currentUser;
  @service capabilities;
  @service router;

  passkeyDefaultName() {
    if (this.capabilities.isSafari) {
      return I18n.t("user.passkeys.name.icloud_keychain");
    }

    if (this.capabilities.isAndroid || this.capabilities.isChrome) {
      return I18n.t("user.passkeys.name.google_password_manager");
    }

    return I18n.t("user.passkeys.name.default");
  }

  createPasskey() {
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
            let credentialParam = {
              id: credential.id,
              rawId: bufferToBase64(credential.rawId),
              type: credential.type,
              attestation: bufferToBase64(
                credential.response.attestationObject
              ),
              clientData: bufferToBase64(credential.response.clientDataJSON),
              name: this.passkeyDefaultName(),
            };

            this.args.model
              .registerPasskey(credentialParam)
              .then((resp) => {
                if (resp.error) {
                  this.dialog.alert(resp.error);
                  return;
                }

                this.router.refresh();

                // Allow user to rename key after creating
                this.dialog.dialog({
                  title: I18n.t("user.passkeys.passkey_successfully_created"),
                  type: "notice",
                  bodyComponent: RenamePasskey,
                  bodyComponentModel: resp,
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

  confirmDelete(id) {
    schedule("afterRender", () => {
      this.dialog.deleteConfirm({
        title: I18n.t("user.passkeys.confirm_delete_passkey"),
        didConfirm: () => {
          this.args.model.deletePasskey(id).then(() => {
            this.router.refresh();
          });
        },
      });
    });
  }

  @action
  async addPasskey() {
    const trustedSession = await this.args.model.trustedSession();

    if (!trustedSession.success) {
      this.dialog.dialog({
        title: I18n.t("user.confirm_access.title"),
        type: "notice",
        bodyComponent: ConfirmSession,
        didConfirm: () => this.createPasskey(),
      });
    } else {
      this.createPasskey();
    }
  }

  @action
  async deletePasskey(id) {
    const trustedSession = await this.args.model.trustedSession();

    if (!trustedSession.success) {
      this.dialog.dialog({
        title: I18n.t("user.confirm_access.title"),
        type: "notice",
        bodyComponent: ConfirmSession,
        didConfirm: () => this.confirmDelete(id),
      });
    } else {
      this.confirmDelete(id);
    }
  }

  @action
  renamePasskey(id, name) {
    this.dialog.dialog({
      title: I18n.t("user.passkeys.rename_passkey"),
      type: "notice",
      bodyComponent: RenamePasskey,
      bodyComponentModel: { id, name },
    });
  }
}
