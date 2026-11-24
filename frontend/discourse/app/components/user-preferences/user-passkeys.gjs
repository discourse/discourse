import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import AccessNotice from "discourse/components/access-notice";
import ConfirmSession from "discourse/components/dialog-messages/confirm-session";
import PasskeyOptionsDropdown from "discourse/components/user-preferences/passkey-options-dropdown";
import RenamePasskey from "discourse/components/user-preferences/rename-passkey";
import { popupAjaxError } from "discourse/lib/ajax-error";
import {
  bufferToBase64,
  stringToBuffer,
  WebauthnAbortHandler,
} from "discourse/lib/webauthn";
import DButton from "discourse/ui-kit/d-button";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import { i18n } from "discourse-i18n";

export default class UserPasskeys extends Component {
  @service dialog;
  @service currentUser;
  @service capabilities;
  @service router;
  @service siteSettings;

  get showActions() {
    return this.args.model.isCurrent && !this.capabilities.isAppWebview;
  }

  get canConfirmLocally() {
    return (
      this.siteSettings.enable_local_logins &&
      (!this.args.model.no_password ||
        this.args.model.user_passkeys?.length > 0)
    );
  }

  handlePasskeyRequestError(error) {
    const xhr = error?.jqXHR ?? error?.source ?? error;
    if (
      xhr?.responseJSON?.error_type === "second_factor_external_login_required"
    ) {
      this.dialog.confirm({
        title: i18n("user.confirm_access.title"),
        message: i18n("user.passkeys.external_login_required"),
        confirmButtonLabel: "user.log_out",
        didConfirm: () => this.args.logout?.(),
      });
    } else {
      popupAjaxError(error);
    }
  }

  async createPasskey() {
    let response;
    try {
      response = await this.args.model.createPasskey();
    } catch (error) {
      this.handlePasskeyRequestError(error);
      return;
    }

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
        // See https://w3c.github.io/webauthn/#sctn-createCredential for context
        // This ensures that the authenticator stores a client-side private key
        // physical security keys (like Yubikey) need this
        requireResidentKey: true,
      },
    };

    let credential;
    try {
      credential = await navigator.credentials.create({
        publicKey: publicKeyCredentialCreationOptions,
        signal: WebauthnAbortHandler.signal(),
      });
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error(error);
      this.errorMessage =
        error.name === "InvalidStateError"
          ? i18n("user.passkeys.already_added_error")
          : i18n("user.passkeys.not_allowed_error");
      this.dialog.alert(this.errorMessage);
      return;
    }

    const credentialParam = {
      id: credential.id,
      rawId: bufferToBase64(credential.rawId),
      type: credential.type,
      attestation: bufferToBase64(credential.response.attestationObject),
      clientData: bufferToBase64(credential.response.clientDataJSON),
      name: i18n("user.passkeys.name.default"),
    };

    try {
      const registrationResponse =
        await this.args.model.registerPasskey(credentialParam);

      if (registrationResponse.error) {
        this.dialog.alert(registrationResponse.error);
        return;
      }

      this.router.refresh();

      // Prompt to rename key after creating
      this.dialog.dialog({
        title: i18n("user.passkeys.passkey_successfully_created"),
        type: "notice",
        bodyComponent: RenamePasskey,
        bodyComponentModel: registrationResponse,
      });
    } catch (error) {
      this.handlePasskeyRequestError(error);
    }
  }

  confirmDelete(id) {
    schedule("afterRender", () => {
      this.dialog.deleteConfirm({
        title: i18n("user.passkeys.confirm_delete_passkey"),
        didConfirm: () => {
          this.args.model
            .deletePasskey(id)
            .then((response) => {
              if (response.success) {
                this.router.refresh();
              } else {
                this.dialog.alert(response.message);
              }
            })
            .catch((error) => this.handlePasskeyRequestError(error));
        },
      });
    });
  }

  @action
  async addPasskey() {
    if (!this.canConfirmLocally) {
      await this.createPasskey();
      return;
    }

    try {
      const trustedSession = await this.args.model.trustedSession();

      if (!trustedSession.success) {
        this.dialog.dialog({
          title: i18n("user.confirm_access.title"),
          type: "notice",
          bodyComponent: ConfirmSession,
          didConfirm: () => this.createPasskey(),
        });
      } else {
        await this.createPasskey();
      }
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async deletePasskey(id) {
    if (!this.canConfirmLocally) {
      this.confirmDelete(id);
      return;
    }

    try {
      const trustedSession = await this.args.model.trustedSession();

      if (!trustedSession.success) {
        this.dialog.dialog({
          title: i18n("user.confirm_access.title"),
          type: "notice",
          bodyComponent: ConfirmSession,
          didConfirm: () => this.confirmDelete(id),
        });
      } else {
        this.confirmDelete(id);
      }
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  renamePasskey(id, name) {
    this.dialog.dialog({
      title: i18n("user.passkeys.rename_passkey"),
      type: "notice",
      bodyComponent: RenamePasskey,
      bodyComponentModel: { id, name },
    });
  }

  <template>
    <div class="control-group pref-passkeys">
      <label class="control-label">
        {{i18n "user.passkeys.title"}}
      </label>
      <div class="instructions">
        {{i18n "user.passkeys.short_description"}}
      </div>

      <div class="pref-passkeys__rows">
        {{#each @model.user_passkeys as |passkey|}}
          <div class="row">
            <div class="passkey-left">
              <div class="row-passkey__name">{{passkey.name}}</div>
              <div class="row-passkey__created-date">
                {{trustHTML
                  (i18n
                    "user.passkeys.added_date"
                    date=(dFormatDate
                      passkey.created_at format="medium" leaveAgo="true"
                    )
                  )
                }}
              </div>
              <div class="row-passkey__used-date">
                {{#if passkey.last_used}}
                  {{trustHTML
                    (i18n
                      "user.passkeys.last_used_date"
                      date=(dFormatDate
                        passkey.last_used format="medium" leaveAgo="true"
                      )
                    )
                  }}
                {{else}}
                  {{i18n "user.passkeys.never_used"}}
                {{/if}}
              </div>
            </div>
            {{#if this.showActions}}
              <div class="passkey-right">
                <div class="actions">
                  <PasskeyOptionsDropdown
                    @deletePasskey={{fn this.deletePasskey passkey.id}}
                    @renamePasskey={{fn
                      this.renamePasskey
                      passkey.id
                      passkey.name
                    }}
                  />
                </div>
              </div>
            {{/if}}
          </div>
        {{/each}}
      </div>

      {{#unless this.capabilities.isAppWebview}}
        <AccessNotice @kind="self" @user={{@model}} as |disabled|>
          <div class="controls pref-passkeys__add">
            <DButton
              class="btn-default"
              @action={{this.addPasskey}}
              @disabled={{disabled}}
              @icon="plus"
              @label="user.passkeys.add_passkey"
            />
          </div>
        </AccessNotice>
      {{/unless}}
    </div>
  </template>
}
