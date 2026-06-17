import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { cancel } from "@ember/runloop";
import { trustHTML } from "@ember/template";
import Form from "discourse/components/form";
import SecondFactorForm from "discourse/components/second-factor-form";
import SecurityKeyForm from "discourse/components/security-key-form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import cookie, { removeCookie } from "discourse/lib/cookie";
import escape from "discourse/lib/escape";
import getURL from "discourse/lib/get-url";
import discourseLater from "discourse/lib/later";
import { emailValid } from "discourse/lib/utilities";
import { getWebauthnCredential } from "discourse/lib/webauthn";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";
import DButton from "discourse/ui-kit/d-button";
import DOtp from "discourse/ui-kit/d-otp";
import DSecondFactorInput from "discourse/ui-kit/d-second-factor-input";
import { i18n } from "discourse-i18n";

const RESEND_COOLDOWN_SECONDS = 30;

export default class CodeLoginForm extends Component {
  @tracked step = "email";
  @tracked email = this.args.initialEmail ?? "";
  @tracked verifying = false;
  @tracked codeError;
  @tracked notice;
  @tracked resendCooldown = 0;
  @tracked otpGeneration = 0;

  @tracked secondFactorMethod = SECOND_FACTOR_METHODS.TOTP;
  @tracked secondFactorToken;
  @tracked securityKeyCredential;
  @tracked totpEnabled = false;
  @tracked backupCodesEnabled = false;
  @tracked securityKeyRequired = false;
  @tracked securityKeyChallenge;
  @tracked securityKeyAllowedCredentialIds;

  code = "";
  #cooldownTimer;

  willDestroy() {
    super.willDestroy(...arguments);
    cancel(this.#cooldownTimer);
  }

  get isEmailStep() {
    return this.step === "email";
  }

  get isCodeStep() {
    return this.step === "code";
  }

  get isSecondFactorStep() {
    return this.step === "second-factor";
  }

  // Whether a second factor other than the security key is available to fall
  // back to (TOTP or backup codes).
  get otherSecondFactorAllowed() {
    return this.totpEnabled || this.backupCodesEnabled;
  }

  // Re-rendering DOtp with a fresh identity is the only way to clear it
  get otpGenerationArray() {
    return [this.otpGeneration];
  }

  get codeInstructions() {
    return trustHTML(
      i18n("code_login.code_instructions", { email: escape(this.email) })
    );
  }

  get resendLabel() {
    if (this.resendCooldown > 0) {
      return i18n("code_login.resend_countdown", {
        count: this.resendCooldown,
      });
    }
    return i18n("code_login.resend");
  }

  get resendDisabled() {
    return this.resendCooldown > 0 || this.verifying;
  }

  @action
  validateEmail(name, value, { addError }) {
    if (value && !emailValid(value)) {
      addError("email", {
        title: i18n("code_login.email_label"),
        message: i18n("user.email.invalid"),
      });
    }
  }

  @action
  async submitEmail(data) {
    this.email = data.email.trim();
    await this.sendCode();
  }

  @action
  async resendCode() {
    if (this.resendDisabled) {
      return;
    }

    if (await this.sendCode()) {
      this.notice = i18n("code_login.code_resent");
      this.code = "";
      this.otpGeneration++;
    }
  }

  @action
  changeEmail() {
    cancel(this.#cooldownTimer);
    this.resendCooldown = 0;
    this.code = "";
    this.codeError = null;
    this.notice = null;
    this.otpGeneration++;
    this.step = "email";
  }

  @action
  codeChanged(value) {
    this.code = value;
    this.codeError = null;
  }

  @action
  async verifyCode(code) {
    if (typeof code === "string") {
      this.code = code;
    }

    if (this.code.length < 6 || this.verifying) {
      return;
    }

    this.verifying = true;
    this.codeError = null;
    this.notice = null;

    const data = {
      email: this.email,
      code: this.code,
      timezone: moment.tz.guess(),
    };

    if (this.isSecondFactorStep) {
      data.second_factor_token =
        this.securityKeyCredential || this.secondFactorToken;
      data.second_factor_method = this.secondFactorMethod;
    }

    try {
      const result = await ajax("/session/login-code/verify", {
        type: "POST",
        data,
      });

      if (result?.second_factor_required && !this.isSecondFactorStep) {
        this.totpEnabled = result.totp_enabled;
        this.backupCodesEnabled = result.backup_codes_enabled;
        this.securityKeyRequired = result.security_key_required;
        this.securityKeyChallenge = result.challenge;
        this.securityKeyAllowedCredentialIds = result.allowed_credential_ids;
        this.secondFactorMethod = result.security_key_required
          ? SECOND_FACTOR_METHODS.SECURITY_KEY
          : SECOND_FACTOR_METHODS.TOTP;
        this.step = "second-factor";
        return;
      }

      if (result?.error) {
        if (this.isSecondFactorStep) {
          this.securityKeyCredential = null;
          this.codeError = result.error;
        } else {
          this.codeError = result.error;
          this.code = "";
          this.otpGeneration++;
        }
        return;
      }

      const destinationUrl = cookie("destination_url");
      if (result?.redirect_url) {
        window.location.assign(result.redirect_url);
      } else if (destinationUrl) {
        removeCookie("destination_url");
        window.location.assign(destinationUrl);
      } else {
        window.location.assign(getURL("/"));
      }
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.verifying = false;
    }
  }

  @action
  submitSecondFactor() {
    this.securityKeyCredential = null;
    return this.verifyCode();
  }

  @action
  secondFactorTokenChanged(value) {
    this.secondFactorToken = value;
    this.codeError = null;
  }

  @action
  setShowSecurityKey(value) {
    this.securityKeyRequired = value;
  }

  @action
  setSecondFactorMethod(value) {
    this.secondFactorMethod = value;
  }

  @action
  authenticateSecurityKey() {
    getWebauthnCredential(
      this.securityKeyChallenge,
      this.securityKeyAllowedCredentialIds,
      (credentialData) => {
        this.securityKeyCredential = credentialData;
        this.verifyCode();
      },
      (errorMessage) => {
        this.codeError = errorMessage;
      }
    );
  }

  async sendCode() {
    this.codeError = null;
    this.notice = null;

    try {
      const honeypot = await ajax("/session/hp.json");
      await ajax("/session/login-code", {
        type: "POST",
        data: {
          email: this.email,
          password_confirmation: honeypot.value,
          challenge: honeypot.challenge.split("").reverse().join(""),
        },
      });

      this.step = "code";
      this.startResendCooldown();
      return true;
    } catch (e) {
      popupAjaxError(e);
      return false;
    }
  }

  startResendCooldown() {
    cancel(this.#cooldownTimer);
    this.resendCooldown = RESEND_COOLDOWN_SECONDS;
    this.tickCooldown();
  }

  tickCooldown() {
    if (this.resendCooldown <= 0) {
      return;
    }

    this.#cooldownTimer = discourseLater(() => {
      this.resendCooldown -= 1;
      this.tickCooldown();
    }, 1000);
  }

  <template>
    <div class="code-login-form">
      {{#if this.isEmailStep}}
        <Form
          @data={{hash email=this.email}}
          @onSubmit={{this.submitEmail}}
          class="code-login-form__email-step"
          as |form|
        >
          <form.Field
            @name="email"
            @title={{i18n "code_login.email_label"}}
            @type="input-email"
            @validation="required"
            @validate={{this.validateEmail}}
            @format="full"
            as |field|
          >
            <field.Control
              autofocus="autofocus"
              autocomplete="username email"
            />
          </form.Field>

          <div class="code-login-form__email-actions">
            <form.Submit
              @label="code_login.continue_button"
              class="btn-primary code-login-form__continue"
            />

            {{#if @onUsePassword}}
              <DButton
                @action={{@onUsePassword}}
                @label="code_login.use_password_instead"
                class="btn-flat code-login-form__password-toggle"
              />
            {{/if}}
          </div>
        </Form>
      {{else if this.isCodeStep}}
        <div class="code-login-form__code-step">
          <h2 class="code-login-form__title">
            {{i18n "code_login.check_your_email"}}
          </h2>
          <p class="code-login-form__instructions">
            {{this.codeInstructions}}
          </p>

          {{#each this.otpGenerationArray as |generation|}}
            <DOtp
              @onChange={{this.codeChanged}}
              @onFill={{this.verifyCode}}
              id="code-login-otp-{{generation}}"
            />
          {{/each}}

          <div class="code-login-form__error" aria-live="polite" role="alert">
            {{this.codeError}}
          </div>

          {{#if this.notice}}
            <p class="code-login-form__notice" aria-live="polite">
              {{this.notice}}
            </p>
          {{/if}}

          <DButton
            @action={{this.verifyCode}}
            @label="code_login.verify_button"
            @isLoading={{this.verifying}}
            type="submit"
            class="btn-primary code-login-form__verify"
          />

          <div class="code-login-form__actions">
            <DButton
              @action={{this.resendCode}}
              @translatedLabel={{this.resendLabel}}
              @disabled={{this.resendDisabled}}
              class="btn-flat code-login-form__resend"
            />
            <DButton
              @action={{this.changeEmail}}
              @label="code_login.use_different_email"
              class="btn-flat code-login-form__change-email"
            />
          </div>
        </div>
      {{else}}
        <div class="code-login-form__second-factor-step">
          {{#if this.codeError}}
            <div class="code-login-form__error" role="alert">
              {{this.codeError}}
            </div>
          {{/if}}

          {{#if this.securityKeyRequired}}
            <SecurityKeyForm
              @setShowSecurityKey={{this.setShowSecurityKey}}
              @setSecondFactorMethod={{this.setSecondFactorMethod}}
              @backupEnabled={{this.backupCodesEnabled}}
              @totpEnabled={{this.totpEnabled}}
              @otherMethodAllowed={{this.otherSecondFactorAllowed}}
              @action={{this.authenticateSecurityKey}}
            />
          {{else}}
            <SecondFactorForm
              @secondFactorMethod={{this.secondFactorMethod}}
              @secondFactorToken={{this.secondFactorToken}}
              @backupEnabled={{this.backupCodesEnabled}}
              @totpEnabled={{this.totpEnabled}}
              @isLogin={{true}}
            >
              <DSecondFactorInput
                @onChange={{this.secondFactorTokenChanged}}
                @secondFactorMethod={{this.secondFactorMethod}}
                value={{this.secondFactorToken}}
              />
            </SecondFactorForm>

            <DButton
              @action={{this.submitSecondFactor}}
              @label="email_login.confirm_button"
              @isLoading={{this.verifying}}
              type="submit"
              class="btn-primary code-login-form__verify"
            />
          {{/if}}
        </div>
      {{/if}}
    </div>
  </template>
}
