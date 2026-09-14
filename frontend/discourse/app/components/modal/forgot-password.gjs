import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { isEmpty } from "@ember/utils";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import cookie from "discourse/lib/cookie";
import getURL from "discourse/lib/get-url";
import { escapeExpression } from "discourse/lib/utilities";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class ForgotPassword extends Component {
  @service siteSettings;

  @tracked
  emailOrUsername = cookie("email") || this.args.model?.emailOrUsername || "";
  @tracked disabled = false;
  @tracked helpSeen = false;
  @tracked offerHelp;
  @tracked flash;

  get submitDisabled() {
    if (this.disabled) {
      return true;
    } else if (this.siteSettings.hide_email_address_taken) {
      return !this.emailOrUsername.includes("@");
    } else {
      return isEmpty(this.emailOrUsername.trim());
    }
  }

  @action
  updateEmailOrUsername(event) {
    this.emailOrUsername = event.target.value;
  }

  @action
  help() {
    this.offerHelp = i18n("forgot_password.help", { basePath: getURL("") });
    this.helpSeen = true;
  }

  @action
  async resetPassword() {
    if (this.submitDisabled) {
      return false;
    }

    this.disabled = true;
    this.flash = null;

    try {
      const data = await ajax("/session/forgot_password", {
        data: { login: this.emailOrUsername.trim() },
        type: "POST",
      });

      const emailOrUsername = escapeExpression(this.emailOrUsername);

      let key = "forgot_password.complete";
      key += emailOrUsername.match(/@/) ? "_email" : "_username";

      if (data.user_found === false) {
        key += "_not_found";

        this.flash = trustHTML(
          i18n(key, {
            email: emailOrUsername,
            username: emailOrUsername,
          })
        );
      } else {
        key += data.user_found ? "_found" : "";

        this.emailOrUsername = "";
        this.offerHelp = i18n(key, {
          email: emailOrUsername,
          username: emailOrUsername,
        });

        this.helpSeen = !data.user_found;
      }
    } catch (error) {
      this.flash = extractError(error);
    } finally {
      this.disabled = false;
    }
  }

  <template>
    <DModal
      class="forgot-password-modal"
      @closeModal={{@closeModal}}
      @flash={{this.flash}}
      @flashType="error"
      @title={{i18n "forgot_password.title"}}
    >
      <:body>
        {{#if this.offerHelp}}
          {{trustHTML this.offerHelp}}
        {{else if this.siteSettings.hide_email_address_taken}}
          <label for="username-or-email">
            {{i18n "forgot_password.invite_no_username"}}
          </label>
          <input
            autocapitalize="off"
            autocorrect="off"
            id="username-or-email"
            placeholder={{i18n "email"}}
            type="text"
            value={{this.emailOrUsername}}
            {{on "input" this.updateEmailOrUsername}}
          />
        {{else}}
          <p>{{i18n "forgot_password.invite"}}</p>
          <label for="username-or-email">
            {{i18n "forgot_password.email-username"}}
          </label>
          <input
            autocapitalize="off"
            autocorrect="off"
            id="username-or-email"
            placeholder={{i18n "login.email_placeholder"}}
            type="text"
            value={{this.emailOrUsername}}
            {{on "input" this.updateEmailOrUsername}}
          />
        {{/if}}
      </:body>

      <:footer>
        {{#if this.offerHelp}}
          <DButton
            class="btn-large btn-primary"
            type="submit"
            @action={{@closeModal}}
            @label="forgot_password.button_ok"
          />
          {{#unless this.helpSeen}}
            <DButton
              class="btn-large"
              @action={{this.help}}
              @icon="circle-question"
              @label="forgot_password.button_help"
            />
          {{/unless}}
        {{else}}
          <DButton
            class="btn-primary forgot-password-reset"
            type="submit"
            @action={{this.resetPassword}}
            @disabled={{this.submitDisabled}}
            @label="forgot_password.reset"
          />
        {{/if}}
      </:footer>
    </DModal>
  </template>
}
