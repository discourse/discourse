import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { cancel } from "@ember/runloop";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import GoogleIcon from "discourse/components/google-icon";
import ForgotPassword from "discourse/components/modal/forgot-password";
import { ajax } from "discourse/lib/ajax";
import { extractError, popupAjaxError } from "discourse/lib/ajax-error";
import escape from "discourse/lib/escape";
import discourseLater from "discourse/lib/later";
import {
  getPasskeyCredential,
  isWebauthnSupported,
} from "discourse/lib/webauthn";
import { findAll } from "discourse/models/login-method";
import DButton from "discourse/ui-kit/d-button";
import DOtp from "discourse/ui-kit/d-otp";
import DUserLink from "discourse/ui-kit/d-user-link";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const RESEND_COOLDOWN_SECONDS = 30;

export function hasConfirmSessionMethod(methods) {
  return Boolean(
    methods?.password ||
    methods?.passkey ||
    methods?.email_code ||
    methods?.external_providers?.length
  );
}

export default class ConfirmSession extends Component {
  @service currentUser;
  @service dialog;
  @service modal;
  @service siteSettings;

  /** @type {string | null} */
  @tracked codeEmail = null;

  /** @type {string | null} */
  @tracked codeNotice = null;
  @tracked errorMessage;
  @tracked isLoading = false;
  @tracked mode = "default";
  @tracked otpGeneration = 0;
  @tracked resendCooldown = 0;

  /** @type {string | null} */
  @tracked resetEmailSent = null;
  @tracked sendingEmailCode = false;

  finePrint = i18n("user.confirm_access.fine_print");
  instructions = i18n("user.confirm_access.instructions");
  loggedInAs = i18n("user.confirm_access.logged_in_as");
  password = "";
  passwordLabel = i18n("user.password.title");

  #cooldownTimer;
  #emailCode = "";

  willDestroy() {
    super.willDestroy(...arguments);
    cancel(this.#cooldownTimer);
  }

  get canUseEmailCode() {
    const methods = this.args.model?.methods;
    if (methods) {
      return Boolean(methods.email_code);
    }

    return (
      this.siteSettings.enable_local_logins &&
      this.siteSettings.enable_local_logins_via_email
    );
  }

  get canUsePasskeys() {
    const methods = this.args.model?.methods;
    if (methods) {
      return Boolean(methods.passkey);
    }

    return (
      this.siteSettings.enable_local_logins &&
      this.siteSettings.enable_passkeys &&
      this.currentUser.user_passkeys?.length > 0 &&
      isWebauthnSupported()
    );
  }

  get canUsePassword() {
    const methods = this.args.model?.methods;
    if (methods) {
      return Boolean(methods.password);
    }

    return (
      this.siteSettings.enable_local_logins && !this.currentUser?.no_password
    );
  }

  get codeInstructions() {
    if (this.codeEmail) {
      return trustHTML(
        i18n("user.confirm_access.code_instructions", {
          email: escape(this.codeEmail),
        })
      );
    }

    return i18n("user.confirm_access.code_instructions_generic");
  }

  get emailCodeButtonClass() {
    return this.isEmailCodePrimary ? "btn-primary" : "btn-default";
  }

  get emailCodeButtonLabel() {
    return this.isEmailCodePrimary
      ? "user.confirm_access.send_email_code"
      : "user.confirm_access.use_email_code";
  }

  get externalProviders() {
    const providerNames = this.args.model?.methods?.external_providers;
    if (!providerNames?.length) {
      return [];
    }

    const available = findAll();
    return providerNames
      .map((name) => available.find((method) => method.name === name))
      .filter((method) => method && !method.custom_url);
  }

  get hasAlternativeMethods() {
    return (
      this.canUsePassword ||
      this.canUsePasskeys ||
      this.externalProviders.length > 0
    );
  }

  get isEmailCodeMode() {
    return this.mode === "email-code";
  }

  get isEmailCodePrimary() {
    return (
      this.canUseEmailCode &&
      !this.canUsePassword &&
      !this.canUsePasskeys &&
      this.externalProviders.length === 0
    );
  }

  get isPasskeyPrimary() {
    return this.canUsePasskeys && !this.canUsePassword;
  }

  get otpGenerationArray() {
    return [this.otpGeneration];
  }

  get passkeyButtonClass() {
    return this.isPasskeyPrimary ? "btn-primary" : "btn-default";
  }

  get resendDisabled() {
    return this.resendCooldown > 0 || this.sendingEmailCode || this.isLoading;
  }

  get resendLabel() {
    if (this.resendCooldown > 0) {
      return i18n("user.confirm_access.resend_code_countdown", {
        count: this.resendCooldown,
      });
    }

    return i18n("user.confirm_access.resend_code");
  }

  get showAdditionalMethods() {
    return (
      this.canUsePasskeys ||
      this.canUseEmailCode ||
      this.externalProviders.length > 0
    );
  }

  @action
  async confirmWithEmailCode(code) {
    if (typeof code === "string") {
      this.#emailCode = code;
    }

    if (this.isLoading) {
      return;
    }

    if (this.#emailCode.length < 6) {
      this.errorMessage = i18n("user.confirm_access.incorrect_code");
      return;
    }

    try {
      this.isLoading = true;
      this.errorMessage = null;
      this.codeNotice = null;

      const result = await ajax("/u/confirm-session.json", {
        type: "POST",
        data: { email_code: this.#emailCode },
      });

      if (this.isDestroying) {
        return;
      }

      if (result.success) {
        this.dialog.didConfirmWrapped();
      } else {
        this.errorMessage =
          result.error || i18n("user.confirm_access.incorrect_code");
        this.#emailCode = "";
        this.otpGeneration++;
      }
    } catch (e) {
      if (!this.isDestroying) {
        this.errorMessage = extractError(
          e,
          i18n("user.confirm_access.incorrect_code")
        );
      }
    } finally {
      if (!this.isDestroying) {
        this.isLoading = false;
      }
    }
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
  confirmWithProvider(provider) {
    provider.doLogin({
      confirmSession: true,
      params: {
        origin: window.location.pathname + window.location.search,
      },
    });
  }

  @action
  emailCodeChanged(value) {
    this.#emailCode = value;
    this.errorMessage = null;
  }

  @action
  async requestEmailCode() {
    if (this.sendingEmailCode || this.isLoading) {
      return;
    }

    try {
      this.sendingEmailCode = true;
      this.errorMessage = null;

      const result = await ajax("/u/confirm-session/email-code.json", {
        type: "POST",
      });

      if (this.isDestroying) {
        return;
      }

      if (result?.success) {
        this.codeEmail = result.email || null;
        this.codeNotice = null;
        this.#emailCode = "";
        this.otpGeneration++;
        this.mode = "email-code";
        this.#startResendCooldown();
      } else {
        this.errorMessage =
          result?.error || i18n("user.confirm_access.cannot_send_email_code");
      }
    } catch (e) {
      if (!this.isDestroying) {
        this.errorMessage = extractError(
          e,
          i18n("user.confirm_access.cannot_send_email_code")
        );
      }
    } finally {
      if (!this.isDestroying) {
        this.sendingEmailCode = false;
      }
    }
  }

  @action
  async resendEmailCode() {
    if (this.resendDisabled) {
      return;
    }

    try {
      this.sendingEmailCode = true;
      this.errorMessage = null;

      const result = await ajax("/u/confirm-session/email-code.json", {
        type: "POST",
      });

      if (this.isDestroying) {
        return;
      }

      if (result?.success) {
        this.codeEmail = result.email || this.codeEmail;
        this.codeNotice = i18n("user.confirm_access.code_resent");
        this.#emailCode = "";
        this.otpGeneration++;
        this.#startResendCooldown();
      } else {
        this.errorMessage =
          result?.error || i18n("user.confirm_access.cannot_send_email_code");
      }
    } catch (e) {
      if (!this.isDestroying) {
        this.errorMessage = extractError(
          e,
          i18n("user.confirm_access.cannot_send_email_code")
        );
      }
    } finally {
      if (!this.isDestroying) {
        this.sendingEmailCode = false;
      }
    }
  }

  @action
  async sendPasswordResetEmail() {
    try {
      const result = await this.currentUser.changePassword();

      if (result.email_code) {
        this.dialog.cancel();
        this.modal.show(ForgotPassword, {
          model: {
            codeSent: true,
            emailOrUsername:
              this.currentUser.email || this.currentUser.username,
          },
        });
        return;
      }

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

  @action
  async submit() {
    try {
      this.isLoading = true;

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
    } finally {
      this.isLoading = false;
    }
  }

  @action
  useAnotherMethod() {
    cancel(this.#cooldownTimer);
    this.resendCooldown = 0;
    this.mode = "default";
    this.errorMessage = null;
    this.codeNotice = null;
    this.#emailCode = "";
  }

  #startResendCooldown() {
    cancel(this.#cooldownTimer);
    this.resendCooldown = RESEND_COOLDOWN_SECONDS;
    this.#tickCooldown();
  }

  #tickCooldown() {
    if (this.resendCooldown <= 0) {
      return;
    }

    this.#cooldownTimer = discourseLater(() => {
      if (!this.isDestroying) {
        this.resendCooldown -= 1;
        this.#tickCooldown();
      }
    }, 1000);
  }

  <template>
    {{#if this.errorMessage}}
      <div class="alert alert-error" role="alert">
        {{this.errorMessage}}
      </div>
    {{/if}}

    <div class="control-group confirm-session">
      <div class="confirm-session__instructions">
        {{this.instructions}}
      </div>

      <div class="confirm-session__instructions">
        <span>{{this.loggedInAs}}</span>
        <DUserLink @user={{this.currentUser}}>
          {{this.currentUser.username}}
        </DUserLink>
      </div>

      {{#if this.isEmailCodeMode}}
        <div class="confirm-session__code-step">
          <div class="confirm-session__code-instructions">
            {{this.codeInstructions}}
          </div>

          {{#each this.otpGenerationArray as |generation|}}
            <DOtp
              id="confirm-session-otp-{{generation}}"
              @onChange={{this.emailCodeChanged}}
              @onFill={{this.confirmWithEmailCode}}
            />
          {{/each}}

          {{#if this.codeNotice}}
            <p class="confirm-session__notice" role="status">
              {{this.codeNotice}}
            </p>
          {{/if}}

          <div class="confirm-session__code-actions">
            <DButton
              class="btn-primary confirm-session__confirm-code"
              @action={{this.confirmWithEmailCode}}
              @isLoading={{this.isLoading}}
              @label="user.confirm_access.confirm_code"
            />
            <DButton
              class="btn-flat confirm-session__resend-code"
              @action={{this.resendEmailCode}}
              @disabled={{this.resendDisabled}}
              @translatedLabel={{this.resendLabel}}
            />
            {{#if this.hasAlternativeMethods}}
              <DButton
                class="btn-flat confirm-session__another-method"
                @action={{this.useAnotherMethod}}
                @label="user.confirm_access.use_another_method"
              />
            {{/if}}
          </div>
        </div>
      {{else}}
        {{#if this.canUsePassword}}
          <form>
            <label class="control-label" for="password">
              {{this.passwordLabel}}
            </label>
            <div class="controls">
              <div class="inline-form">
                <Input
                  autofocus="autofocus"
                  class="input-large"
                  id="password"
                  @type="password"
                  @value={{this.password}}
                />
                <DButton
                  class="btn-primary"
                  @action={{this.submit}}
                  @isLoading={{this.isLoading}}
                  @label="user.password.confirm"
                  @type="submit"
                />
              </div>
              <div class="confirm-session__reset">
                <DButton
                  class="btn-link btn-flat confirm-session__reset-btn"
                  @action={{this.sendPasswordResetEmail}}
                  @label="user.confirm_access.forgot_password"
                />
                {{#if this.resetEmailSent}}
                  <span class="confirm-session__reset-email-sent">
                    {{this.resetEmailSent}}
                  </span>
                {{/if}}
              </div>
            </div>
          </form>
        {{/if}}

        {{#if this.showAdditionalMethods}}
          <div class="confirm-session__methods">
            {{#if this.canUsePasskeys}}
              <div class="confirm-session__passkey">
                <DButton
                  class={{this.passkeyButtonClass}}
                  @action={{this.confirmWithPasskey}}
                  @icon="user"
                  @label="user.passkeys.confirm_button"
                />
              </div>
            {{/if}}

            {{#if this.canUseEmailCode}}
              <div class="confirm-session__email-code">
                <DButton
                  class={{this.emailCodeButtonClass}}
                  @action={{this.requestEmailCode}}
                  @icon="envelope"
                  @isLoading={{this.sendingEmailCode}}
                  @label={{this.emailCodeButtonLabel}}
                />
              </div>
            {{/if}}

            {{#if this.externalProviders.length}}
              <div class="confirm-session__external-providers">
                {{#each this.externalProviders as |provider|}}
                  <button
                    aria-label={{i18n
                      "user.confirm_access.confirm_with_provider"
                      provider=provider.prettyName
                    }}
                    class="btn btn-social
                      {{provider.name}}
                      confirm-session__provider-btn"
                    type="button"
                    {{on "click" (fn this.confirmWithProvider provider)}}
                  >
                    {{#if provider.isGoogle}}
                      <GoogleIcon />
                    {{else if provider.icon}}
                      {{dIcon provider.icon}}
                    {{else}}
                      {{dIcon "right-to-bracket"}}
                    {{/if}}
                    <span class="btn-social-title">
                      {{i18n
                        "user.confirm_access.confirm_with_provider"
                        provider=provider.prettyName
                      }}
                    </span>
                  </button>
                {{/each}}
              </div>
            {{/if}}
          </div>
        {{/if}}
      {{/if}}

      <div class="confirm-session__fine-print">
        {{this.finePrint}}
      </div>
    </div>
  </template>
}
