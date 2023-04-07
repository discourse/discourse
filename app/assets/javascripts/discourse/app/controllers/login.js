import Controller, { inject as controller } from "@ember/controller";
import { alias, not, or, readOnly } from "@ember/object/computed";
import { areCookiesEnabled, escapeExpression } from "discourse/lib/utilities";
import cookie, { removeCookie } from "discourse/lib/cookie";
import { next, schedule } from "@ember/runloop";
import EmberObject, { action } from "@ember/object";
import I18n from "I18n";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";
import { ajax } from "discourse/lib/ajax";
import discourseComputed from "discourse-common/utils/decorators";
import { escape } from "pretty-text/sanitizer";
import { flashAjaxError } from "discourse/lib/ajax-error";
import { findAll } from "discourse/models/login-method";
import getURL from "discourse-common/lib/get-url";
import { getWebauthnCredential } from "discourse/lib/webauthn";
import { isEmpty } from "@ember/utils";
import { setting } from "discourse/lib/computed";
import showModal from "discourse/lib/show-modal";
import { wavingHandURL } from "discourse/lib/waving-hand-url";
import { inject as service } from "@ember/service";

// This is happening outside of the app via popup
const AuthErrors = [
  "requires_invite",
  "awaiting_approval",
  "awaiting_activation",
  "admin_not_allowed_from_ip_address",
  "not_allowed_from_ip_address",
];

export default Controller.extend(ModalFunctionality, {
  createAccount: controller(),
  forgotPassword: controller(),
  application: controller(),
  dialog: service(),

  loggingIn: false,
  loggedIn: false,
  processingEmailLink: false,
  showLoginButtons: true,
  showSecondFactor: false,
  awaitingApproval: false,
  maskPassword: true,

  canLoginLocal: setting("enable_local_logins"),
  canLoginLocalWithEmail: setting("enable_local_logins_via_email"),
  loginRequired: alias("application.loginRequired"),
  secondFactorMethod: SECOND_FACTOR_METHODS.TOTP,

  noLoginLocal: not("canLoginLocal"),

  resetForm() {
    this.setProperties({
      loggingIn: false,
      loggedIn: false,
      secondFactorRequired: false,
      showSecondFactor: false,
      showSecurityKey: false,
      showLoginButtons: true,
      awaitingApproval: false,
      maskPassword: true,
    });
  },

  @discourseComputed("showSecondFactor", "showSecurityKey")
  credentialsClass(showSecondFactor, showSecurityKey) {
    return showSecondFactor || showSecurityKey ? "hidden" : "";
  },

  @discourseComputed()
  wavingHandURL: () => wavingHandURL(),

  @discourseComputed("showSecondFactor", "showSecurityKey")
  secondFactorClass(showSecondFactor, showSecurityKey) {
    return showSecondFactor || showSecurityKey ? "" : "hidden";
  },

  @discourseComputed(
    "awaitingApproval",
    "hasAtLeastOneLoginButton",
    "showSecondFactor",
    "canLoginLocal",
    "showSecurityKey"
  )
  modalBodyClasses(
    awaitingApproval,
    hasAtLeastOneLoginButton,
    showSecondFactor,
    canLoginLocal,
    showSecurityKey
  ) {
    const classes = ["login-modal-body"];
    if (awaitingApproval) {
      classes.push("awaiting-approval");
    }
    if (hasAtLeastOneLoginButton && !showSecondFactor && !showSecurityKey) {
      classes.push("has-alt-auth");
    }
    if (!canLoginLocal) {
      classes.push("no-local-login");
    }
    if (showSecondFactor || showSecurityKey) {
      classes.push("second-factor");
    }
    return classes.join(" ");
  },

  @discourseComputed("showSecondFactor", "showSecurityKey")
  disableLoginFields(showSecondFactor, showSecurityKey) {
    return showSecondFactor || showSecurityKey;
  },

  @discourseComputed()
  hasAtLeastOneLoginButton() {
    return findAll().length > 0;
  },

  @discourseComputed("loggingIn")
  loginButtonLabel(loggingIn) {
    return loggingIn ? "login.logging_in" : "login.title";
  },

  loginDisabled: or("loggingIn", "loggedIn"),

  @discourseComputed("loggingIn", "application.canSignUp")
  showSignupLink(loggingIn, canSignUp) {
    return canSignUp && !loggingIn;
  },

  showSpinner: readOnly("loggingIn"),

  @discourseComputed("canLoginLocalWithEmail")
  showLoginWithEmailLink(canLoginLocalWithEmail) {
    return canLoginLocalWithEmail;
  },

  @action
  emailLogin(event) {
    event?.preventDefault();

    if (this.processingEmailLink) {
      return;
    }

    if (isEmpty(this.loginName)) {
      this.flash(I18n.t("login.blank_username"), "info");
      return;
    }

    this.set("processingEmailLink", true);

    ajax("/u/email-login", {
      data: { login: this.loginName.trim() },
      type: "POST",
    })
      .then((data) => {
        const loginName = escapeExpression(this.loginName);
        const isEmail = loginName.match(/@/);
        let key = `email_login.complete_${isEmail ? "email" : "username"}`;
        if (data.user_found === false) {
          this.flash(
            I18n.t(`${key}_not_found`, {
              email: loginName,
              username: loginName,
            }),
            "error"
          );
        } else {
          let postfix = data.hide_taken ? "" : "_found";
          this.flash(
            I18n.t(`${key}${postfix}`, {
              email: loginName,
              username: loginName,
            })
          );
        }
      })
      .catch(flashAjaxError(this))
      .finally(() => this.set("processingEmailLink", false));
  },

  @action
  handleForgotPassword(event) {
    event?.preventDefault();
    const forgotPasswordController = this.forgotPassword;
    if (forgotPasswordController) {
      forgotPasswordController.set("accountEmailOrUsername", this.loginName);
    }
    this.send("showForgotPassword");
  },

  @action
  togglePasswordMask() {
    this.toggleProperty("maskPassword");
  },

  actions: {
    forgotPassword() {
      this.handleForgotPassword();
    },

    login() {
      if (this.loginDisabled) {
        return;
      }

      if (isEmpty(this.loginName) || isEmpty(this.loginPassword)) {
        this.flash(I18n.t("login.blank_username_or_password"), "error");
        return;
      }

      this.set("loggingIn", true);

      ajax("/session", {
        type: "POST",
        data: {
          login: this.loginName,
          password: this.loginPassword,
          second_factor_token:
            this.securityKeyCredential || this.secondFactorToken,
          second_factor_method: this.secondFactorMethod,
          timezone: moment.tz.guess(),
        },
      }).then(
        (result) => {
          // Successful login
          if (result && result.error) {
            this.set("loggingIn", false);
            this.clearFlash();

            if (
              (result.security_key_enabled || result.totp_enabled) &&
              !this.secondFactorRequired
            ) {
              this.setProperties({
                otherMethodAllowed: result.multiple_second_factor_methods,
                secondFactorRequired: true,
                showLoginButtons: false,
                backupEnabled: result.backup_enabled,
                totpEnabled: result.totp_enabled,
                showSecondFactor: result.totp_enabled,
                showSecurityKey: result.security_key_enabled,
                secondFactorMethod: result.security_key_enabled
                  ? SECOND_FACTOR_METHODS.SECURITY_KEY
                  : SECOND_FACTOR_METHODS.TOTP,
                securityKeyChallenge: result.challenge,
                securityKeyAllowedCredentialIds: result.allowed_credential_ids,
              });

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
              this.send("showNotActivated", {
                username: this.loginName,
                sentTo: escape(result.sent_to_email),
                currentEmail: escape(result.current_email),
              });
            } else if (result.reason === "suspended") {
              this.send("closeModal");
              this.dialog.alert(result.error);
            } else {
              this.flash(result.error, "error");
            }
          } else {
            this.set("loggedIn", true);
            // Trigger the browser's password manager using the hidden static login form:
            const hiddenLoginForm =
              document.getElementById("hidden-login-form");
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
        },
        (e) => {
          // Failed to login
          if (e.jqXHR && e.jqXHR.status === 429) {
            this.flash(I18n.t("login.rate_limit"), "error");
          } else if (
            e.jqXHR &&
            e.jqXHR.status === 503 &&
            e.jqXHR.responseJSON.error_type === "read_only"
          ) {
            this.flash(I18n.t("read_only_mode.login_disabled"), "error");
          } else if (!areCookiesEnabled()) {
            this.flash(I18n.t("login.cookies_error"), "error");
          } else {
            this.flash(I18n.t("login.error"), "error");
          }
          this.set("loggingIn", false);
        }
      );

      return false;
    },

    externalLogin(loginMethod, { signup = false } = {}) {
      if (this.loginDisabled) {
        return;
      }

      this.set("loggingIn", true);
      loginMethod.doLogin({ signup }).catch(() => this.set("loggingIn", false));
    },

    createAccount() {
      const createAccountController = this.createAccount;
      if (createAccountController) {
        createAccountController.resetForm();
        const loginName = this.loginName;
        if (loginName && loginName.indexOf("@") > 0) {
          createAccountController.set("accountEmail", loginName);
        } else {
          createAccountController.set("accountUsername", loginName);
        }
      }
      this.send("showCreateAccount");
    },

    authenticateSecurityKey() {
      getWebauthnCredential(
        this.securityKeyChallenge,
        this.securityKeyAllowedCredentialIds,
        (credentialData) => {
          this.set("securityKeyCredential", credentialData);
          this.send("login");
        },
        (errorMessage) => {
          this.flash(errorMessage, "error");
        }
      );
    },
  },

  authenticationComplete(options) {
    const loginError = (errorMsg, className, callback) => {
      showModal("login");

      next(() => {
        if (callback) {
          callback();
        }
        this.flash(errorMsg, className || "success");
      });
    };

    if (
      options.awaiting_approval &&
      !this.canLoginLocal &&
      !this.canLoginLocalWithEmail
    ) {
      this.set("awaitingApproval", true);
    }

    if (options.omniauth_disallow_totp) {
      return loginError(I18n.t("login.omniauth_disallow_totp"), "error", () => {
        this.setProperties({
          loginName: options.email,
          showLoginButtons: false,
        });

        document.getElementById("login-account-password").focus();
      });
    }

    for (let i = 0; i < AuthErrors.length; i++) {
      const cond = AuthErrors[i];
      if (options[cond]) {
        return loginError(I18n.t(`login.${cond}`));
      }
    }

    if (options.suspended) {
      return loginError(options.suspended_message, "error");
    }

    // Reload the page if we're authenticated
    if (options.authenticated) {
      const destinationUrl =
        cookie("destination_url") || options.destination_url;
      if (destinationUrl) {
        // redirect client to the original URL
        removeCookie("destination_url");
        window.location.href = destinationUrl;
      } else if (window.location.pathname === getURL("/login")) {
        window.location = getURL("/");
      } else {
        window.location.reload();
      }
      return;
    }

    const skipConfirmation = this.siteSettings.auth_skip_create_confirm;
    const createAccountController = this.createAccount;

    createAccountController.setProperties({
      accountEmail: options.email,
      accountUsername: options.username,
      accountName: options.name,
      authOptions: EmberObject.create(options),
      skipConfirmation,
    });

    next(() => {
      showModal("create-account", {
        modalClass: "create-account",
        titleAriaElementId: "create-account-title",
      });
    });
  },
});
