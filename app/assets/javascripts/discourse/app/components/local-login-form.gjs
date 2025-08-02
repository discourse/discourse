import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { isEmpty } from "@ember/utils";
import ForgotPassword from "discourse/components/modal/forgot-password";
import PasswordField from "discourse/components/password-field";
import SecondFactorForm from "discourse/components/second-factor-form";
import SecondFactorInput from "discourse/components/second-factor-input";
import SecurityKeyForm from "discourse/components/security-key-form";
import TogglePasswordMask from "discourse/components/toggle-password-mask";
import icon from "discourse/helpers/d-icon";
import valueEntered from "discourse/helpers/value-entered";
import withEventValue from "discourse/helpers/with-event-value";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { escapeExpression } from "discourse/lib/utilities";
import { getWebauthnCredential } from "discourse/lib/webauthn";
import { i18n } from "discourse-i18n";

export default class LocalLoginForm extends Component {
  @service modal;
  @service siteSettings;

  @tracked maskPassword = true;
  @tracked processingEmailLink = false;
  @tracked capsLockOn = false;

  get credentialsClass() {
    return this.args.showSecondFactor || this.args.showSecurityKey
      ? "hidden"
      : "";
  }

  get showSecondFactorForm() {
    return this.args.showSecondFactor || this.args.showSecurityKey;
  }

  get disableLoginFields() {
    return this.args.showSecondFactor || this.args.showSecurityKey;
  }

  @action
  passkeyConditionalLogin() {
    if (this.args.canUsePasskeys) {
      this.args.passkeyLogin("conditional");
    }
  }

  @action
  scrollInputIntoView(event) {
    event.target.scrollIntoView({
      behavior: "smooth",
      block: "center",
    });
  }

  @action
  togglePasswordMask() {
    this.maskPassword = !this.maskPassword;
  }

  @action
  async emailLogin(event) {
    event?.preventDefault();

    if (this.processingEmailLink) {
      return;
    }

    if (isEmpty(this.args.loginName)) {
      this.args.flashChanged(i18n("login.blank_username"));
      this.args.flashTypeChanged("info");
      return;
    }

    try {
      this.processingEmailLink = true;
      const data = await ajax("/u/email-login", {
        data: { login: this.args.loginName.trim() },
        type: "POST",
      });
      const loginName = escapeExpression(this.args.loginName);
      const isEmail = loginName.match(/@/);
      const key = isEmail
        ? "email_login.complete_email"
        : "email_login.complete_username";
      if (data.user_found === false) {
        this.args.flashChanged(
          htmlSafe(
            i18n(`${key}_not_found`, {
              email: loginName,
              username: loginName,
            })
          )
        );
        this.args.flashTypeChanged("error");
      } else {
        const postfix = data.hide_taken ? "" : "_found";
        this.args.flashChanged(
          htmlSafe(
            i18n(`${key}${postfix}`, {
              email: loginName,
              username: loginName,
            })
          )
        );
        this.args.flashTypeChanged("success");
      }
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.processingEmailLink = false;
    }
  }

  @action
  loginOnEnter(event) {
    if (event.key === "Enter") {
      this.args.login();
    }
  }

  @action
  handleForgotPassword(event) {
    event?.preventDefault();

    let filledLoginName = this.args.loginName;

    // no spaces, at least one dot, one @ with one or more characters before & after
    const likelyEmail = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(
      filledLoginName?.trim()
    );

    if (this.siteSettings.hide_email_address_taken && !likelyEmail) {
      filledLoginName = null;
    }

    this.modal.show(ForgotPassword, {
      model: {
        emailOrUsername: filledLoginName,
      },
    });
  }

  @action
  authenticateSecurityKey() {
    getWebauthnCredential(
      this.args.securityKeyChallenge,
      this.args.securityKeyAllowedCredentialIds,
      (credentialData) => {
        this.args.securityKeyCredentialChanged(credentialData);
        this.args.login();
      },
      (error) => {
        this.args.flashChanged(error);
        this.args.flashTypeChanged("error");
      }
    );
  }

  <template>
    <form id="login-form" method="post">
      <div id="credentials" class={{this.credentialsClass}}>
        <div class="input-group" {{didInsert this.passkeyConditionalLogin}}>
          <Input
            {{on "focusin" this.scrollInputIntoView}}
            @value={{@loginName}}
            @type="email"
            id="login-account-name"
            class={{valueEntered @loginName}}
            autocomplete={{if @canUsePasskeys "username webauthn" "username"}}
            autocorrect="off"
            autocapitalize="off"
            disabled={{@showSecondFactor}}
            autofocus="autofocus"
            tabindex="1"
            {{on "input" @loginNameChanged}}
            {{on "keydown" this.loginOnEnter}}
          />
          <label class="alt-placeholder" for="login-account-name">
            {{i18n "login.email_placeholder"}}
          </label>
          {{#if @canLoginLocalWithEmail}}
            <a
              href
              class={{if @loginName "" "no-login-filled"}}
              tabindex="3"
              id="email-login-link"
              {{on "click" this.emailLogin}}
            >
              {{i18n "email_login.login_link"}}
            </a>
          {{/if}}
        </div>
        <div class="input-group">
          <PasswordField
            {{on "focusin" this.scrollInputIntoView}}
            {{on "keydown" this.loginOnEnter}}
            @value={{@loginPassword}}
            @capsLockOn={{this.capsLockOn}}
            type={{if this.maskPassword "password" "text"}}
            disabled={{this.disableLoginFields}}
            autocomplete="current-password"
            maxlength="200"
            tabindex="1"
            id="login-account-password"
            class={{valueEntered @loginPassword}}
          />
          <label class="alt-placeholder" for="login-account-password">
            {{i18n "login.password"}}
          </label>
          {{#if @loginPassword}}
            <TogglePasswordMask
              @maskPassword={{this.maskPassword}}
              @togglePasswordMask={{this.togglePasswordMask}}
              tabindex="3"
            />
          {{/if}}
          <div class="login__password-links">
            <a
              href
              id="forgot-password-link"
              tabindex="2"
              {{on "click" this.handleForgotPassword}}
            >
              {{i18n "forgot_password.action"}}
            </a>
          </div>
          <div class="caps-lock-warning {{unless this.capsLockOn 'hidden'}}">
            {{icon "triangle-exclamation"}}
            {{i18n "login.caps_lock_warning"}}</div>
        </div>
      </div>
      {{#if this.showSecondFactorForm}}
        <SecondFactorForm
          @secondFactorMethod={{@secondFactorMethod}}
          @secondFactorToken={{@secondFactorToken}}
          @backupEnabled={{@backupEnabled}}
          @totpEnabled={{@totpEnabled}}
          @isLogin={{true}}
        >
          {{#if @showSecurityKey}}
            <SecurityKeyForm
              @setShowSecurityKey={{fn (mut @showSecurityKey)}}
              @setShowSecondFactor={{fn (mut @showSecondFactor)}}
              @setSecondFactorMethod={{fn (mut @secondFactorMethod)}}
              @backupEnabled={{@backupEnabled}}
              @totpEnabled={{@totpEnabled}}
              @otherMethodAllowed={{@otherMethodAllowed}}
              @action={{this.authenticateSecurityKey}}
            />
          {{else}}
            <SecondFactorInput
              {{on "keydown" this.loginOnEnter}}
              {{on "input" (withEventValue (fn (mut @secondFactorToken)))}}
              {{on "focusin" this.scrollInputIntoView}}
              @secondFactorMethod={{@secondFactorMethod}}
              value={{@secondFactorToken}}
              id="login-second-factor"
            />
          {{/if}}
        </SecondFactorForm>
      {{/if}}
    </form>
  </template>
}
