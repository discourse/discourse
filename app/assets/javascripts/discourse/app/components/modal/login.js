import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import { inject as service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import cookie, { removeCookie } from "discourse/lib/cookie";
import { areCookiesEnabled } from "discourse/lib/utilities";
import { wavingHandURL } from "discourse/lib/waving-hand-url";
import {
  getPasskeyCredential,
  isWebauthnSupported,
} from "discourse/lib/webauthn";
import { findAll } from "discourse/models/login-method";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";
import escape from "discourse-common/lib/escape";
import I18n from "discourse-i18n";

export default class Login extends Component {
  @service capabilities;
  @service dialog;
  @service siteSettings;
  @service site;

  @tracked loggingIn = false;
  @tracked loggedIn = false;
  @tracked showLoginButtons = true;
  @tracked showSecondFactor = false;
  @tracked loginPassword = "";
  @tracked loginName = "";
  @tracked flash = this.args.model.flash;
  @tracked flashType = this.args.model.flashType;
  @tracked canLoginLocal = this.siteSettings.enable_local_logins;
  @tracked
  canLoginLocalWithEmail = this.siteSettings.enable_local_logins_via_email;
  @tracked secondFactorMethod = SECOND_FACTOR_METHODS.TOTP;
  @tracked securityKeyCredential;
  @tracked otherMethodAllowed;
  @tracked secondFactorRequired;
  @tracked backupEnabled;
  @tracked totpEnabled;
  @tracked showSecurityKey;
  @tracked securityKeyChallenge;
  @tracked securityKeyAllowedCredentialIds;
  @tracked secondFactorToken;

  constructor() {
    super(...arguments);

    if (this.args.model.isExternalLogin) {
      this.externalLogin(this.args.model.externalLoginMethod, {
        signup: this.args.model.signup,
      });
    }
  }

  get awaitingApproval() {
    return (
      this.args.model.awaitingApproval &&
      !this.canLoginLocal &&
      !this.canLoginLocalWithEmail
    );
  }

  get loginDisabled() {
    return this.loggingIn || this.loggedIn;
  }

  get wavingHandURL() {
    return wavingHandURL();
  }

  get modalBodyClasses() {
    const classes = ["login-modal-body"];
    if (this.awaitingApproval) {
      classes.push("awaiting-approval");
    }
    if (
      this.hasAtLeastOneLoginButton &&
      !this.showSecondFactor &&
      !this.showSecurityKey
    ) {
      classes.push("has-alt-auth");
    }
    if (!this.canLoginLocal) {
      classes.push("no-local-login");
    }
    if (this.showSecondFactor || this.showSecurityKey) {
      classes.push("second-factor");
    }
    return classes.join(" ");
  }

  get canUsePasskeys() {
    return (
      this.siteSettings.enable_local_logins &&
      this.siteSettings.experimental_passkeys &&
      isWebauthnSupported()
    );
  }

  get hasAtLeastOneLoginButton() {
    return findAll().length > 0 || this.canUsePasskeys;
  }

  get loginButtonLabel() {
    return this.loggingIn ? "login.logging_in" : "login.title";
  }

  get showSignupLink() {
    return (
      this.args.model.canSignUp && !this.loggingIn && !this.showSecondFactor
    );
  }

  @action
  async passkeyLogin(mediation = "optional") {
    try {
      // we need to check isConditionalMediationAvailable for Firefox
      // without it, Firefox will throw console errors
      // We cannot do a general check because iOS Safari and Chrome in Selenium quietly support the feature
      // but they do not support the PublicKeyCredential.isConditionalMediationAvailable() method
      if (
        mediation === "conditional" &&
        this.capabilities.isFirefox &&
        window.PublicKeyCredential
      ) {
        const isCMA =
          // eslint-disable-next-line no-undef
          await PublicKeyCredential.isConditionalMediationAvailable();
        if (!isCMA) {
          return;
        }
      }
      const response = await ajax("/session/passkey/challenge.json");

      const publicKeyCredential = await getPasskeyCredential(
        response.challenge,
        (errorMessage) => this.dialog.alert(errorMessage),
        mediation
      );

      if (publicKeyCredential) {
        const authResult = await ajax("/session/passkey/auth.json", {
          type: "POST",
          data: { publicKeyCredential },
        });

        if (authResult && !authResult.error) {
          const destinationUrl = cookie("destination_url");
          if (destinationUrl) {
            removeCookie("destination_url");
            window.location.assign(destinationUrl);
          } else {
            window.location.reload();
          }
        } else {
          this.dialog.alert(authResult.error);
        }
      }
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  preloadLogin() {
    const prefillUsername = document.querySelector(
      "#hidden-login-form input[name=username]"
    )?.value;
    if (prefillUsername) {
      this.loginName = prefillUsername;
      this.loginPassword = document.querySelector(
        "#hidden-login-form input[name=password]"
      ).value;
    } else if (cookie("email")) {
      this.loginName = cookie("email");
    }
  }

  @action
  securityKeyCredentialChanged(value) {
    this.securityKeyCredential = value;
  }

  @action
  flashChanged(value) {
    this.flash = value;
  }

  @action
  flashTypeChanged(value) {
    this.flashType = value;
  }

  @action
  loginNameChanged(event) {
    this.loginName = event.target.value;
  }

  @action
  async login() {
    if (this.loginDisabled) {
      return;
    }

    if (isEmpty(this.loginName) || isEmpty(this.loginPassword)) {
      this.flash = I18n.t("login.blank_username_or_password");
      this.flashType = "error";
      return;
    }

    try {
      this.loggingIn = true;
      const result = await ajax("/session", {
        type: "POST",
        data: {
          login: this.loginName,
          password: this.loginPassword,
          second_factor_token:
            this.securityKeyCredential || this.secondFactorToken,
          second_factor_method: this.secondFactorMethod,
          timezone: moment.tz.guess(),
        },
      });
      if (result && result.error) {
        this.loggingIn = false;
        this.flash = null;

        if (
          (result.security_key_enabled || result.totp_enabled) &&
          !this.secondFactorRequired
        ) {
          this.otherMethodAllowed = result.multiple_second_factor_methods;
          this.secondFactorRequired = true;
          this.showLoginButtons = false;
          this.backupEnabled = result.backup_enabled;
          this.totpEnabled = result.totp_enabled;
          this.showSecondFactor = result.totp_enabled;
          this.showSecurityKey = result.security_key_enabled;
          this.secondFactorMethod = result.security_key_enabled
            ? SECOND_FACTOR_METHODS.SECURITY_KEY
            : SECOND_FACTOR_METHODS.TOTP;
          this.securityKeyChallenge = result.challenge;
          this.securityKeyAllowedCredentialIds = result.allowed_credential_ids;

          // only need to focus the 2FA input for TOTP
          if (!this.showSecurityKey) {
            schedule("afterRender", () =>
              document
                .getElementById("second-factor")
                .querySelector("input")
                .focus()
            );
          }

          return;
        } else if (result.reason === "not_activated") {
          this.args.model.showNotActivated({
            username: this.loginName,
            sentTo: escape(result.sent_to_email),
            currentEmail: escape(result.current_email),
          });
        } else if (result.reason === "suspended") {
          this.args.closeModal();
          this.dialog.alert(result.error);
        } else {
          this.flash = result.error;
          this.flashType = "error";
        }
      } else {
        this.loggedIn = true;
        // Trigger the browser's password manager using the hidden static login form:
        const hiddenLoginForm = document.getElementById("hidden-login-form");
        const applyHiddenFormInputValue = (value, key) => {
          if (!hiddenLoginForm) {
            return;
          }

          hiddenLoginForm.querySelector(`input[name=${key}]`).value = value;
        };

        const destinationUrl = cookie("destination_url");
        const ssoDestinationUrl = cookie("sso_destination_url");

        applyHiddenFormInputValue(this.loginName, "username");
        applyHiddenFormInputValue(this.loginPassword, "password");

        if (ssoDestinationUrl) {
          removeCookie("sso_destination_url");
          window.location.assign(ssoDestinationUrl);
          return;
        } else if (destinationUrl) {
          // redirect client to the original URL
          removeCookie("destination_url");

          applyHiddenFormInputValue(destinationUrl, "redirect");
        } else {
          applyHiddenFormInputValue(window.location.href, "redirect");
        }

        if (hiddenLoginForm) {
          if (
            navigator.userAgent.match(/(iPad|iPhone|iPod)/g) &&
            navigator.userAgent.match(/Safari/g)
          ) {
            // In case of Safari on iOS do not submit hidden login form
            window.location.href = hiddenLoginForm.querySelector(
              "input[name=redirect]"
            ).value;
          } else {
            hiddenLoginForm.submit();
          }
        }
        return;
      }
    } catch (e) {
      // Failed to login
      if (e.jqXHR && e.jqXHR.status === 429) {
        this.flash = I18n.t("login.rate_limit");
        this.flashType = "error";
      } else if (
        e.jqXHR &&
        e.jqXHR.status === 503 &&
        e.jqXHR.responseJSON.error_type === "read_only"
      ) {
        this.flash = I18n.t("read_only_mode.login_disabled");
        this.flashType = "error";
      } else if (!areCookiesEnabled()) {
        this.flash = I18n.t("login.cookies_error");
        this.flashType = "error";
      } else {
        this.flash = I18n.t("login.error");
        this.flashType = "error";
      }
      this.loggingIn = false;
    }
  }

  async externalLogin(loginMethod, { signup }) {
    try {
      this.loggingIn = true;
      await loginMethod.doLogin({ signup });
      this.args.closeModal();
    } catch {
      this.loggingIn = false;
    }
  }

  @action
  async externalLoginAction(loginMethod) {
    if (this.loginDisabled) {
      return;
    }

    await this.externalLogin(loginMethod, { signup: false });
  }

  @action
  createAccount() {
    let createAccountProps = {};
    if (this.loginName && this.loginName.indexOf("@") > 0) {
      createAccountProps.accountEmail = this.loginName;
      createAccountProps.accountUsername = null;
    } else {
      createAccountProps.accountUsername = this.loginName;
      createAccountProps.accountEmail = null;
    }
    this.args.model.showCreateAccount(createAccountProps);
  }
}
