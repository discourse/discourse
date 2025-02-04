import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import UserLink from "discourse/components/user-link";
import { ajax } from "discourse/lib/ajax";
import { extractError, popupAjaxError } from "discourse/lib/ajax-error";
import {
  getPasskeyCredential,
  isWebauthnSupported,
} from "discourse/lib/webauthn";
import { i18n } from "discourse-i18n";

export default class ConfirmSession extends Component {
  @service dialog;
  @service currentUser;
  @service siteSettings;

  @tracked errorMessage;
  @tracked resetEmailSent = null;

  passwordLabel = i18n("user.password.title");
  instructions = i18n("user.confirm_access.instructions");
  loggedInAs = i18n("user.confirm_access.logged_in_as");
  finePrint = i18n("user.confirm_access.fine_print");

  get canUsePasskeys() {
    return (
      this.siteSettings.enable_local_logins &&
      this.siteSettings.enable_passkeys &&
      this.currentUser.user_passkeys?.length > 0 &&
      isWebauthnSupported()
    );
  }

  @action
  async confirmWithPasskey() {
    try {
      const publicKeyCredential = await getPasskeyCredential((e) =>
        this.dialog.alert(e)
      );

      if (!publicKeyCredential) {
        return;
      }

      const result = await ajax("/u/confirm-session.json", {
        type: "POST",
        data: { publicKeyCredential },
      });

      if (result.success) {
        this.errorMessage = null;
        this.dialog.didConfirmWrapped();
      } else {
        this.errorMessage = i18n("user.confirm_access.incorrect_passkey");
      }
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  async submit() {
    this.errorMessage = this.password
      ? null
      : i18n("user.confirm_access.incorrect_password");

    const result = await ajax("/u/confirm-session.json", {
      type: "POST",
      data: {
        password: this.password,
      },
    });

    if (result.success) {
      this.errorMessage = null;
      this.dialog.didConfirmWrapped();
    } else {
      this.errorMessage = i18n("user.confirm_access.incorrect_password");
    }
  }

  @action
  async sendPasswordResetEmail() {
    try {
      const result = await ajax("/session/forgot_password.json", {
        data: { login: this.currentUser.username },
        type: "POST",
      });

      if (result.success) {
        this.errorMessage = null;
        this.resetEmailSent = i18n(
          "user.confirm_access.password_reset_email_sent"
        );
      } else {
        this.errorMessage = i18n(
          "user.confirm_access.cannot_send_password_reset_email"
        );
      }
    } catch (e) {
      this.errorMessage = extractError(
        e,
        i18n("user.confirm_access.cannot_send_password_reset_email")
      );
    }
  }

  <template>
    {{#if this.errorMessage}}
      <div class="alert alert-error">
        {{this.errorMessage}}
      </div>
    {{/if}}

    <div class="control-group confirm-session">
      <div class="confirm-session__instructions">
        {{this.instructions}}
      </div>

      <div class="confirm-session__instructions">
        <span>{{this.loggedInAs}}</span>
        <UserLink @user={{this.currentUser}}>
          {{this.currentUser.username}}
        </UserLink>
      </div>

      <form>
        <label class="control-label">{{this.passwordLabel}}</label>
        <div class="controls">
          <div class="inline-form">
            <Input
              @value={{this.password}}
              @type="password"
              id="password"
              class="input-large"
              autofocus="autofocus"
            />
            <DButton
              class="btn-primary"
              @type="submit"
              @action={{this.submit}}
              @label="user.password.confirm"
            />
          </div>
          <div class="confirm-session__reset">
            <DButton
              @label="user.confirm_access.forgot_password"
              @action={{this.sendPasswordResetEmail}}
              class="btn-link btn-flat confirm-session__reset-btn"
            />
            {{#if this.resetEmailSent}}
              <span class="confirm-session__reset-email-sent">
                {{this.resetEmailSent}}
              </span>
            {{/if}}
          </div>
          {{#if this.canUsePasskeys}}
            <div class="confirm-session__passkey">
              <DButton
                @action={{this.confirmWithPasskey}}
                @label="user.passkeys.confirm_button"
                @icon="user"
              />
            </div>
          {{/if}}
        </div>
      </form>

      <div class="confirm-session__fine-print">
        {{this.finePrint}}
      </div>

    </div>
  </template>
}
