import { tracked } from "@glimmer/tracking";
import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { isEmpty } from "@ember/utils";
import ForgotPassword from "discourse/components/modal/forgot-password";
import NotActivatedModal from "discourse/components/modal/not-activated";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import cookie, { removeCookie } from "discourse/lib/cookie";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import { areCookiesEnabled } from "discourse/lib/utilities";
import {
  getPasskeyCredential,
  isWebauthnSupported,
} from "discourse/lib/webauthn";
import { findAll } from "discourse/models/login-method";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";
import escape from "discourse-common/lib/escape";
import getURL from "discourse-common/lib/get-url";
import { i18n } from "discourse-i18n";

export default class LoginPageController extends Controller {
  @service siteSettings;
  @service router;
  @service capabilities;
  @service dialog;
  @service site;
  @service login;
  @service modal;

  @controller application;

  @tracked loggingIn = false;
  @tracked loggedIn = false;
  @tracked showLoginButtons = true;
  @tracked showLogin = true;
  @tracked showSecondFactor = false;
  @tracked loginPassword = "";
  @tracked loginName = "";
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
  @tracked flash;
  @tracked flashType;

  get isAwaitingApproval() {
    return (
      this.awaitingApproval &&
      !this.canLoginLocal &&
      !this.canLoginLocalWithEmail
    );
  }

  get loginDisabled() {
    return this.loggingIn || this.loggedIn;
  }

  get bodyClasses() {
    const classes = ["login-body"];
    if (this.isAwaitingApproval) {
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
      this.siteSettings.enable_passkeys &&
      isWebauthnSupported()
    );
  }

  get hasAtLeastOneLoginButton() {
    return findAll().length > 0 || this.canUsePasskeys;
  }

  get hasNoLoginOptions() {
    return !this.hasAtLeastOneLoginButton && !this.canLoginLocal;
  }

  get loginButtonLabel() {
    return this.loggingIn ? "login.logging_in" : "login.title";
  }

  get showSignupLink() {
    return this.canSignUp && !this.showSecondFactor;
  }

  get adminLoginPath() {
    return getURL("/u/admin-login");
  }

  get shouldTriggerRouteAction() {
    return (
      !this.siteSettings.full_page_login ||
      this.siteSettings.enable_discourse_connect
    );
  }

  @action
  showFullPageLogin() {
    this.showLogin = true;
  }

  @action
  async passkeyLogin(mediation = "optional") {
    try {
      const publicKeyCredential = await getPasskeyCredential(
        (e) => this.dialog.alert(e),
        mediation,
        this.capabilities.isFirefox
      );

      if (publicKeyCredential) {
        let authResult;
        try {
          authResult = await ajax("/session/passkey/auth.json", {
            type: "POST",
            data: { publicKeyCredential },
          });
        } catch (e) {
          popupAjaxError(e);
          return;
        }

        if (authResult && !authResult.error) {
          const destinationUrl = cookie("destination_url");
          const ssoDestinationUrl = cookie("sso_destination_url");

          if (ssoDestinationUrl) {
            removeCookie("sso_destination_url");
            window.location.assign(ssoDestinationUrl);
          } else if (destinationUrl) {
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
  showCreateAccount(createAccountProps = {}) {
    if (this.site.isReadOnly) {
      this.dialog.alert(i18n("read_only_mode.login_disabled"));
    } else {
      this.handleShowCreateAccount(createAccountProps);
    }
  }

  handleShowCreateAccount(createAccountProps) {
    if (this.siteSettings.enable_discourse_connect) {
      const returnPath = encodeURIComponent(window.location.pathname);
      window.location = getURL("/session/sso?return_path=" + returnPath);
    } else {
      if (this.isOnlyOneExternalLoginMethod) {
        // we will automatically redirect to the external auth service
        this.login.externalLogin(this.externalLoginMethods[0], {
          signup: true,
        });
      } else {
        this.router.transitionTo("signup").then((signup) => {
          Object.keys(createAccountProps || {}).forEach((key) => {
            signup.controller.set(key, createAccountProps[key]);
          });
        });
      }
    }
  }

  @action
  showNotActivated(props) {
    this.modal.show(NotActivatedModal, { model: props });
  }

  @action
  async triggerLogin() {
    if (this.loginDisabled) {
      return;
    }

    if (isEmpty(this.loginName) || isEmpty(this.loginPassword)) {
      this.flash = i18n("login.blank_username_or_password");
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

          return;
        } else if (result.reason === "not_activated") {
          this.showNotActivated({
            username: this.loginName,
            sentTo: escape(result.sent_to_email),
            currentEmail: escape(result.current_email),
          });
        } else if (result.reason === "suspended") {
          this.dialog.alert(result.error);
        } else if (result.reason === "expired") {
          this.flash = htmlSafe(
            i18n("login.password_expired", {
              reset_url: getURL("/password-reset"),
            })
          );
          this.flashType = "error";
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
        this.flash = i18n("login.rate_limit");
        this.flashType = "error";
      } else if (
        e.jqXHR &&
        e.jqXHR.status === 503 &&
        e.jqXHR.responseJSON.error_type === "read_only"
      ) {
        this.flash = i18n("read_only_mode.login_disabled");
        this.flashType = "error";
      } else if (!areCookiesEnabled()) {
        this.flash = i18n("login.cookies_error");
        this.flashType = "error";
      } else {
        this.flash = i18n("login.error");
        this.flashType = "error";
      }
      this.loggingIn = false;
    }
  }

  @action
  externalLoginAction(loginMethod) {
    if (this.loginDisabled) {
      return;
    }
    this.login.externalLogin(loginMethod, {
      signup: false,
      setLoggingIn: (value) => (this.loggingIn = value),
    });
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
    this.showCreateAccount(createAccountProps);
  }

  @action
  interceptResetLink(event) {
    if (
      !wantsNewWindow(event) &&
      event.target.href &&
      new URL(event.target.href).pathname === getURL("/password-reset")
    ) {
      event.preventDefault();
      event.stopPropagation();
      this.modal.show(ForgotPassword, {
        model: {
          emailOrUsername: this.loginName,
        },
      });
    }
  }
}
