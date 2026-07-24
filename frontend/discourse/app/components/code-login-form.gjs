import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { cancel } from "@ember/runloop";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import Form from "discourse/components/form";
import AvatarSelectorModal from "discourse/components/modal/avatar-selector";
import PluginOutlet from "discourse/components/plugin-outlet";
import SecondFactorForm from "discourse/components/second-factor-form";
import SecurityKeyForm from "discourse/components/security-key-form";
import UserField from "discourse/components/user-field";
import WelcomeHeader from "discourse/components/welcome-header";
import lazyHash from "discourse/helpers/lazy-hash";
import valueEntered from "discourse/helpers/value-entered";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import cookie, { removeCookie } from "discourse/lib/cookie";
import discourseDebounce from "discourse/lib/debounce";
import escape from "discourse/lib/escape";
import getURL from "discourse/lib/get-url";
import discourseLater from "discourse/lib/later";
import UserFieldsValidationHelper from "discourse/lib/user-fields-validation-helper";
import { emailValid } from "discourse/lib/utilities";
import { getWebauthnCredential } from "discourse/lib/webauthn";
import User, { SECOND_FACTOR_METHODS } from "discourse/models/user";
import DButton from "discourse/ui-kit/d-button";
import DOtp from "discourse/ui-kit/d-otp";
import DSecondFactorInput from "discourse/ui-kit/d-second-factor-input";
import dBoundAvatarTemplate from "discourse/ui-kit/helpers/d-bound-avatar-template";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const RESEND_COOLDOWN_SECONDS = 30;

export default class CodeLoginForm extends Component {
  @service site;
  @service modal;

  @tracked email = this.args.initialEmail ?? "";
  @tracked verifying = false;
  @tracked codeError;
  @tracked notice;
  @tracked resendCooldown = 0;
  @tracked otpGeneration = 0;
  @tracked newAccount;
  @tracked accountUser;
  @tracked name = "";
  @tracked nameRequired = false;
  @tracked nameError;
  @tracked username = "";
  @tracked usernameAvailable = false;
  @tracked usernameChecking = false;
  @tracked usernameError;
  @tracked usernameEditable = true;
  @tracked regenerating = false;
  @tracked avatarTemplate;
  @tracked avatarDetailsLoaded = false;
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
  #usernameCheckSeq = 0;
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

  // Login has its own page heading; only signup needs a per-step one here.
  get heading() {
    if (!this.isSignup) {
      return null;
    }

    switch (this.step) {
      case "code":
        return {
          title: i18n("code_login.check_your_email"),
          subtitle: this.codeInstructions,
        };
      case "user-fields":
        return {
          title: i18n("code_login.user_fields_title"),
          subtitle: i18n("code_login.user_fields_instructions"),
        };
      case "complete":
        return {
          title: i18n("code_login.account_ready_title"),
          subtitle: this.usernameEditable
            ? i18n("code_login.account_ready_edit")
            : null,
        };
      case "second-factor":
        return { title: i18n("login.second_factor_title"), subtitle: null };
      default:
        return { title: i18n("code_login.signup_title"), subtitle: null };
    }
  }

  get continueDisabled() {
    if (this.verifying) {
      return true;
    }
    // When the username can't be changed there's nothing to validate.
    if (!this.usernameEditable) {
      return false;
    }
    return !this.usernameAvailable || this.usernameChecking;
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
      if (this.nameRequired) {
        data.name = this.name.trim();
      }
    }

    try {
      const result = await ajax("/session/login-code/verify", {
        type: "POST",
        data,
      });

      if (
        (result?.user_fields_required || result?.name_required) &&
        !this.isUserFieldsStep
      ) {
        this.nameRequired = !!result.name_required;
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
        this.setupNewAccount(result);
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
  nameChanged(event) {
    this.name = event.target.value;
    this.nameError = null;
  }

  @action
  async submitUserFields() {
    this.userFieldsValidationHelper.validationVisible = true;
    if (this.nameRequired && !this.name.trim()) {
      this.nameError = i18n("user.name.required");
    }
    if (
      this.nameError ||
      this.userFieldsValidationHelper.userFieldsValidation.failed
    ) {
      return;
    }
    return this.verifyCode();
  }

  // The account is logged in server-side but the app is still in its anonymous
  // boot state, so username/avatar are edited through authenticated requests on
  // a User model built from the verify response rather than the current user.
  setupNewAccount(result) {
    const user = result.user;
    this.newAccount = user;
    // can_upload_avatar isn't in UserSerializer, so carry it from the response.
    this.accountUser = User.create({
      ...user,
      can_upload_avatar: result.can_upload_avatar,
    });
    this.usernameEditable = result.can_edit_username;
    this.username = user.username;
    this.avatarTemplate = user.avatar_template;
    if (this.usernameEditable) {
      this.checkUsernameAvailability();
    }
  }

  @action
  async regenerateUsername() {
    if (this.regenerating) {
      return;
    }

    this.regenerating = true;
    try {
      const before = this.username;
      // Hold the rolling state for at least one animation cycle so a fast
      // response doesn't cut the dice spin (and the text fade) short.
      const [result] = await Promise.all([
        ajax("/u/random-username.json"),
        new Promise((resolve) => discourseLater(resolve, 400)),
      ]);

      // Don't touch state (or fire the availability check) if the component
      // was torn down mid-roll, or clobber a name the user typed while the
      // request was in flight.
      if (this.isDestroying || this.username !== before) {
        return;
      }

      this.username = result.username;
      this.usernameError = null;
      this.usernameAvailable = false;
      await this.checkUsernameAvailability();
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.regenerating = false;
    }
  }

  @action
  usernameChanged(event) {
    this.username = event.target.value;
    this.usernameAvailable = false;
    this.usernameError = null;
    discourseDebounce(this, this.checkUsernameAvailability, 350);
  }

  async checkUsernameAvailability() {
    const username = this.username?.trim();
    if (!username) {
      this.usernameAvailable = false;
      this.usernameError = null;
      return;
    }

    // Ignore responses that arrive out of order behind a newer check.
    const seq = ++this.#usernameCheckSeq;
    this.usernameChecking = true;
    try {
      const result = await User.checkUsername(
        username,
        this.email,
        this.newAccount.id
      );

      if (seq !== this.#usernameCheckSeq) {
        return;
      }

      if (result.available) {
        this.usernameAvailable = true;
        this.usernameError = null;
      } else {
        this.usernameAvailable = false;
        this.usernameError =
          result.errors?.join(" ") ||
          (result.suggestion
            ? i18n("code_login.username_unavailable", {
                suggestion: result.suggestion,
              })
            : i18n("code_login.username_taken"));
      }
    } catch {
      if (seq === this.#usernameCheckSeq) {
        this.usernameAvailable = false;
      }
    } finally {
      if (seq === this.#usernameCheckSeq) {
        this.usernameChecking = false;
      }
    }
  }

  @action
  async changeAvatar() {
    try {
      // The picker needs the gravatar/system/upload state, loaded on demand.
      if (!this.avatarDetailsLoaded) {
        await this.accountUser.findDetails();
        this.avatarDetailsLoaded = true;
      }
    } catch (e) {
      return popupAjaxError(e);
    }

    this.modal.show(AvatarSelectorModal, {
      model: {
        user: this.accountUser,
        onAvatarChange: () => this.avatarChanged(),
      },
    });
  }

  async avatarChanged() {
    // pickAvatar doesn't update the model, so reload to show the new avatar.
    try {
      await this.accountUser.findDetails();
      this.avatarTemplate = this.accountUser.avatar_template;
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  async continueAfterSignup() {
    if (this.continueDisabled) {
      return;
    }

    this.verifying = true;

    const username = this.username.trim();
    if (
      this.usernameEditable &&
      username.toLowerCase() !== this.newAccount.username.toLowerCase()
    ) {
      try {
        await this.accountUser.changeUsername(username);
      } catch (e) {
        this.verifying = false;
        popupAjaxError(e);
        return;
      }
    }

    // Leave the button disabled and spinning through the redirect so it doesn't
    // flash back to its idle state before the page navigates away.
    this.redirectAfterLogin();
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
      {{#if this.heading}}
        {{! Plugins can replace this via the signup-heading outlet. }}
        <PluginOutlet
          @name="signup-heading"
          @outletArgs={{lazyHash
            step=this.step
            context=@context
            title=this.heading.title
            subtitle=this.heading.subtitle
          }}
        >
          <WelcomeHeader
            id="create-account-title"
            @header={{this.heading.title}}
          >
            {{#if this.heading.subtitle}}
              <p class="login-subheader">{{this.heading.subtitle}}</p>
            {{/if}}
          </WelcomeHeader>
        </PluginOutlet>
      {{/if}}

      {{#unless this.isEmailStep}}
        {{! Steps replace each other in the DOM, so without this hidden field
        password managers lose track of which account is authenticating once
        the email input unmounts. }}
        <input
          type="email"
          value={{this.email}}
          name="email"
          autocomplete="username"
          readonly={{true}}
          tabindex="-1"
          aria-hidden="true"
          class="code-login-form__hidden-email sr-only"
        />
      {{/unless}}

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
            <field.Control autofocus="autofocus" autocomplete="username" />
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
          {{#unless this.isSignup}}
            <h2 class="code-login-form__title">
              {{i18n "code_login.check_your_email"}}
            </h2>
            <p class="code-login-form__instructions">
              {{this.codeInstructions}}
            </p>
          {{/unless}}

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
          {{#unless this.isSignup}}
            <h2 class="code-login-form__title">
              {{i18n "code_login.account_ready_title"}}
            </h2>
            {{#if this.usernameEditable}}
              <p class="code-login-form__instructions">
                {{i18n "code_login.account_ready_edit"}}
              </p>
            {{/if}}
          {{/unless}}

          <div class="code-login-form__new-account">
            <button
              type="button"
              class="code-login-form__avatar"
              title={{i18n "code_login.change_avatar"}}
              {{on "click" this.changeAvatar}}
            >
              {{dBoundAvatarTemplate this.avatarTemplate "huge"}}
              <span class="code-login-form__avatar-edit">
                {{dIcon "pencil"}}
              </span>
            </button>

            {{#if this.usernameEditable}}
              <div class="code-login-form__username-field">
                <label for="code-login-username">
                  {{i18n "code_login.username_label"}}
                </label>
                <div class="code-login-form__username-input">
                  <input
                    {{on "input" this.usernameChanged}}
                    type="text"
                    value={{this.username}}
                    id="code-login-username"
                    name="username"
                    autocomplete="off"
                    placeholder={{i18n "code_login.username_placeholder"}}
                    class="code-login-form__new-account-username
                      {{if this.regenerating '--swapping'}}"
                    aria-invalid={{if this.usernameError "true"}}
                    aria-describedby="code-login-username-error"
                  />
                  <DButton
                    @action={{this.regenerateUsername}}
                    @icon="dice"
                    @title="code_login.regenerate_username"
                    @ariaLabel="code_login.regenerate_username"
                    aria-busy={{if this.regenerating "true"}}
                    class="btn-transparent code-login-form__username-regen
                      {{if this.regenerating '--rolling'}}"
                  />
                </div>
                <div
                  id="code-login-username-error"
                  class="code-login-form__error"
                  aria-live="polite"
                  role="alert"
                >
                  {{this.usernameError}}
                </div>
              </div>
            {{else}}
              <div class="code-login-form__new-account-username">
                {{this.newAccount.username}}
              </div>
            {{/if}}
          </div>

          <DButton
            @action={{this.continueAfterSignup}}
            @label="code_login.account_ready_continue"
            @disabled={{this.continueDisabled}}
            @isLoading={{this.verifying}}
            class="btn-large btn-primary code-login-form__continue-to-site"
          />
        </div>
      {{else if this.isUserFieldsStep}}
        <div class="code-login-form__user-fields-step">
          {{#unless this.isSignup}}
            <h2 class="code-login-form__title">
              {{i18n "code_login.user_fields_title"}}
            </h2>
            <p class="code-login-form__instructions">
              {{i18n "code_login.user_fields_instructions"}}
            </p>
          {{/unless}}

          {{#if this.nameRequired}}
            <div class="code-login-form__name-field">
              <label for="code-login-name">
                {{i18n "user.name.title"}}
              </label>
              <input
                {{on "input" this.nameChanged}}
                type="text"
                value={{this.name}}
                id="code-login-name"
                name="name"
                autocomplete="name"
                maxlength="255"
                class="code-login-form__name"
                aria-invalid={{if this.nameError "true"}}
                aria-describedby="code-login-name-error"
              />
              <div
                id="code-login-name-error"
                class="code-login-form__error"
                aria-live="polite"
                role="alert"
              >
                {{this.nameError}}
              </div>
            </div>
          {{/if}}

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
