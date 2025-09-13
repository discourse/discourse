import { tracked } from "@glimmer/tracking";
import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { isEmpty } from "@ember/utils";
import NotActivatedModal from "discourse/components/modal/not-activated";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { setting } from "discourse/lib/computed";
import cookie, { removeCookie } from "discourse/lib/cookie";
import escape from "discourse/lib/escape";
import getURL from "discourse/lib/get-url";
import { areCookiesEnabled } from "discourse/lib/utilities";
import {
  getPasskeyCredential,
  isWebauthnSupported,
} from "discourse/lib/webauthn";
import { findAll } from "discourse/models/login-method";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";
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

  @setting("enable_local_logins") canLoginLocal;
  @setting("enable_local_logins_via_email") canLoginLocalWithEmail;

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
    return this.application.canSignUp && !this.showSecondFactor;
  }

  get adminLoginPath() {
    return getURL("/u/admin-login");
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
  loginPasswordChanged(event) {
    this.loginPassword = event.target.value;
  }

  @action
  showNotActivated(props) {
    this.modal.show(NotActivatedModal, { model: props });
  }

  @action
  async localLogin() {
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
      if (result?.error) {
        this.loggingIn = false;
        this.flash = null;
        this.flashType = "error";

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
        } else {
          this.flash = result.error;
        }
      } else {
        this.loggedIn = true;
        // Trigger the browser's password manager using the hidden static login form:
        const _form = document.getElementById("hidden-login-form");
        if (_form) {
          const set = (key, value) => {
            _form.querySelector(`input[name=${key}]`).value = value;
          };

          set("username", this.loginName);
          set("password", this.loginPassword);

          const destinationUrl = cookie("destination_url");

          if (destinationUrl) {
            removeCookie("destination_url");
            set("redirect", destinationUrl);
          } else {
            set("redirect", window.location.href);
          }

          if (this.capabilities.isIOS && this.capabilities.isSafari) {
            // In case of Safari on iOS do not submit hidden login form
            window.location.href = _form.querySelector(
              "input[name=redirect]"
            ).value;
          } else {
            _form.submit();
          }
        }
      }
    } catch (e) {
      // Failed to login
      this.loggingIn = false;
      this.flashType = "error";
      if (e.jqXHR?.status === 429) {
        this.flash = i18n("login.rate_limit");
      } else if (
        e.jqXHR?.status === 503 &&
        e.jqXHR?.responseJSON?.error_type === "read_only"
      ) {
        this.flash = i18n("read_only_mode.login_disabled");
      } else if (!areCookiesEnabled()) {
        this.flash = i18n("login.cookies_error");
      } else {
        this.flash = i18n("login.error");
      }
    }
  }

  @action
  externalLogin(loginMethod) {
    if (!this.loginDisabled) {
      this.login.externalLogin(loginMethod, {
        setLoggingIn: (value) => (this.loggingIn = value),
      });
    }
  }

  @action
  createAccount() {
    // This makes the UX a little bit nicer by auto-filling the email/username when switching from /login to /signup
    if (this.loginName?.indexOf("@") > 0) {
      this.send("showCreateAccount", {
        accountEmail: this.loginName,
        accountUsername: "",
      });
    } else {
      this.send("showCreateAccount", {
        accountEmail: "",
        accountUsername: this.loginName,
      });
    }
  }
}
