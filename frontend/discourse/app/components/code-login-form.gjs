import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { cancel } from "@ember/runloop";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import Form from "discourse/components/form";
import SecondFactorForm from "discourse/components/second-factor-form";
import SecurityKeyForm from "discourse/components/security-key-form";
import UserField from "discourse/components/user-field";
import valueEntered from "discourse/helpers/value-entered";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import cookie, { removeCookie } from "discourse/lib/cookie";
import escape from "discourse/lib/escape";
import getURL from "discourse/lib/get-url";
import discourseLater from "discourse/lib/later";
import UserFieldsValidationHelper from "discourse/lib/user-fields-validation-helper";
import { emailValid } from "discourse/lib/utilities";
import { getWebauthnCredential } from "discourse/lib/webauthn";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";
import DButton from "discourse/ui-kit/d-button";
import DOtp from "discourse/ui-kit/d-otp";
import DSecondFactorInput from "discourse/ui-kit/d-second-factor-input";
import dBoundAvatarTemplate from "discourse/ui-kit/helpers/d-bound-avatar-template";
import { i18n } from "discourse-i18n";

const RESEND_COOLDOWN_SECONDS = 30;

export default class CodeLoginForm extends Component {
  @service site;

  @tracked email = this.args.initialEmail ?? "";
  @tracked verifying = false;
  @tracked codeError;
  @tracked notice;
  @tracked resendCooldown = 0;
  @tracked otpGeneration = 0;
  @tracked newAccount;
  @tracked secondFactorMethod = SECOND_FACTOR_METHODS.TOTP;
  @tracked secondFactorToken;
  @tracked securityKeyCredential;
  @tracked totpEnabled = false;
  @tracked backupCodesEnabled = false;
  @tracked securityKeyRequired = false;
  @tracked securityKeyChallenge;
  @tracked securityKeyAllowedCredentialIds;
  code = "";
  userFieldsValidationHelper = new UserFieldsValidationHelper({
    getUserFields: () =>
      this.site.get("user_fields")?.filter((f) => f.show_on_signup),
    getAccountPassword: () => null,
    showValidationOnInit: false,
  });
  #cooldownTimer;
  @tracked _step = "email";

  willDestroy() {
    super.willDestroy(...arguments);
    cancel(this.#cooldownTimer);
  }

  // Tracked-backed so the parent can react to step transitions via onStepChange.
  get step() {
    return this._step;
  }

  set step(value) {
    this._step = value;
    this.args.onStepChange?.(value);
  }

  get isSignup() {
    return this.args.context === "signup";
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

  get isUserFieldsStep() {
    return this.step === "user-fields";
  }

  get isCompleteStep() {
    return this.step === "complete";
  }

  get editProfileUrl() {
    return getURL("/my/preferences/account");
  }

  get userFields() {
    return this.userFieldsValidationHelper.userFields;
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

    if (this.isUserFieldsStep) {
      data.user_fields = {};
      this.userFields.forEach((f) => (data.user_fields[f.field.id] = f.value));
    }

    try {
      const result = await ajax("/session/login-code/verify", {
        type: "POST",
        data,
      });

      if (result?.user_fields_required && !this.isUserFieldsStep) {
        this.step = "user-fields";
        return;
      }

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
        } else if (this.isUserFieldsStep) {
          this.codeError = result.error;
        } else {
          this.codeError = result.error;
          this.code = "";
          this.otpGeneration++;
        }
        return;
      }

      if (result?.account_created) {
        this.newAccount = result.user;
        this.step = "complete";
        return;
      }

      this.redirectAfterLogin(result?.redirect_url);
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.verifying = false;
    }
  }

  @action
  async submitUserFields() {
    this.userFieldsValidationHelper.validationVisible = true;
    if (this.userFieldsValidationHelper.userFieldsValidation.failed) {
      return;
    }
    return this.verifyCode();
  }

  @action
  continueAfterSignup() {
    this.redirectAfterLogin();
  }

  @action
  editProfile(event) {
    // The account was logged in server-side without a page reload, so the
    // app is still in its anonymous boot state. Navigate with a full page
    // load so it reboots authenticated rather than client-side routing into
    // a user-only route as an anonymous user.
    event?.preventDefault();
    window.location.assign(this.editProfileUrl);
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

  redirectAfterLogin(redirectUrl) {
    const destinationUrl = cookie("destination_url");
    if (redirectUrl) {
      window.location.assign(redirectUrl);
    } else if (destinationUrl) {
      removeCookie("destination_url");
      window.location.assign(destinationUrl);
    } else {
      window.location.assign(getURL("/"));
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
        {{#if this.isSignup}}
          <p class="code-login-form__instructions">
            {{i18n "code_login.signup_instructions"}}
          </p>
        {{/if}}

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
      {{else if this.isCompleteStep}}
        <div class="code-login-form__complete-step">
          <h2 class="code-login-form__title">
            {{i18n "code_login.account_ready_title"}}
          </h2>

          <div class="code-login-form__new-account">
            {{dBoundAvatarTemplate this.newAccount.avatar_template "huge"}}
            <div class="code-login-form__new-account-username">
              {{this.newAccount.username}}
            </div>
            <a
              href={{this.editProfileUrl}}
              class="code-login-form__edit-profile"
              {{on "click" this.editProfile}}
            >
              {{i18n "code_login.account_ready_edit"}}
            </a>
          </div>

          <DButton
            @action={{this.continueAfterSignup}}
            @label="code_login.account_ready_continue"
            class="btn-large btn-primary code-login-form__continue-to-site"
          />
        </div>
      {{else if this.isUserFieldsStep}}
        <div class="code-login-form__user-fields-step">
          <h2 class="code-login-form__title">
            {{i18n "code_login.user_fields_title"}}
          </h2>
          <p class="code-login-form__instructions">
            {{i18n "code_login.user_fields_instructions"}}
          </p>

          <div class="user-fields">
            {{#each this.userFields as |f|}}
              <div class="input-group">
                <UserField
                  @field={{f.field}}
                  @value={{f.value}}
                  @validation={{f.validation}}
                  class={{valueEntered f.value}}
                />
              </div>
            {{/each}}
          </div>

          <div class="code-login-form__error" aria-live="polite" role="alert">
            {{this.codeError}}
          </div>

          <DButton
            @action={{this.submitUserFields}}
            @label="code_login.continue_button"
            @isLoading={{this.verifying}}
            type="submit"
            class="btn-primary code-login-form__verify"
          />
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
