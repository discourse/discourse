import EmberObject from "@ember/object";
import { inject } from "@ember/controller";
import Controller from "@ember/controller";
import { ajax } from "discourse/lib/ajax";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import showModal from "discourse/lib/show-modal";
import { setting } from "discourse/lib/computed";
import { findAll } from "discourse/models/login-method";
import { escape } from "pretty-text/sanitizer";
import { escapeExpression, areCookiesEnabled } from "discourse/lib/utilities";
import { extractError } from "discourse/lib/ajax-error";
import computed from "ember-addons/ember-computed-decorators";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";
import { getWebauthnCredential } from "discourse/lib/webauthn";

// This is happening outside of the app via popup
const AuthErrors = [
  "requires_invite",
  "awaiting_approval",
  "awaiting_activation",
  "admin_not_allowed_from_ip_address",
  "not_allowed_from_ip_address"
];

export default Controller.extend(ModalFunctionality, {
  createAccount: inject(),
  forgotPassword: inject(),
  application: inject(),

  loggingIn: false,
  loggedIn: false,
  processingEmailLink: false,
  showLoginButtons: true,
  showSecondFactor: false,
  awaitingApproval: false,

  canLoginLocal: setting("enable_local_logins"),
  canLoginLocalWithEmail: setting("enable_local_logins_via_email"),
  loginRequired: Ember.computed.alias("application.loginRequired"),
  secondFactorMethod: SECOND_FACTOR_METHODS.TOTP,

  resetForm() {
    this.setProperties({
      loggingIn: false,
      loggedIn: false,
      secondFactorRequired: false,
      showSecondFactor: false,
      showSecurityKey: false,
      showLoginButtons: true,
      awaitingApproval: false
    });
  },

  @computed("showSecondFactor", "showSecurityKey")
  credentialsClass(showSecondFactor, showSecurityKey) {
    return showSecondFactor || showSecurityKey ? "hidden" : "";
  },

  @computed("showSecondFactor", "showSecurityKey")
  secondFactorClass(showSecondFactor, showSecurityKey) {
    return showSecondFactor || showSecurityKey ? "" : "hidden";
  },

  @computed("awaitingApproval", "hasAtLeastOneLoginButton")
  modalBodyClasses(awaitingApproval, hasAtLeastOneLoginButton) {
    const classes = ["login-modal"];
    if (awaitingApproval) classes.push("awaiting-approval");
    if (hasAtLeastOneLoginButton) classes.push("has-alt-auth");
    return classes.join(" ");
  },

  @computed("showSecondFactor", "showSecurityKey")
  disableLoginFields(showSecondFactor, showSecurityKey) {
    return showSecondFactor || showSecurityKey;
  },

  @computed("canLoginLocalWithEmail")
  hasAtLeastOneLoginButton(canLoginLocalWithEmail) {
    return findAll().length > 0 || canLoginLocalWithEmail;
  },

  @computed("loggingIn")
  loginButtonLabel(loggingIn) {
    return loggingIn ? "login.logging_in" : "login.title";
  },

  loginDisabled: Ember.computed.or("loggingIn", "loggedIn"),

  @computed("loggingIn", "application.canSignUp")
  showSignupLink(loggingIn, canSignUp) {
    return canSignUp && !loggingIn;
  },

  showSpinner: Ember.computed.readOnly("loggingIn"),

  @computed("canLoginLocalWithEmail", "processingEmailLink")
  showLoginWithEmailLink(canLoginLocalWithEmail, processingEmailLink) {
    return canLoginLocalWithEmail && !processingEmailLink;
  },

  actions: {
    login() {
      if (this.loginDisabled) {
        return;
      }

      if (Ember.isEmpty(this.loginName) || Ember.isEmpty(this.loginPassword)) {
        this.flash(I18n.t("login.blank_username_or_password"), "error");
        return;
      }

      this.set("loggingIn", true);

      ajax("/session", {
        type: "POST",
        data: {
          login: this.loginName,
          password: this.loginPassword,
          second_factor_token: this.secondFactorToken,
          second_factor_method: this.secondFactorMethod,
          security_key_credential: this.securityKeyCredential
        }
      }).then(
        result => {
          // Successful login
          if (result && result.error) {
            this.set("loggingIn", false);
            const invalidSecurityKey = result.reason === "invalid_security_key";
            const invalidSecondFactor =
              result.reason === "invalid_second_factor";

            if (
              (invalidSecondFactor || invalidSecurityKey) &&
              !this.secondFactorRequired
            ) {
              document.getElementById("modal-alert").style.display = "none";

              this.setProperties({
                secondFactorRequired: true,
                showLoginButtons: false,
                backupEnabled: result.backup_enabled,
                showSecondFactor: invalidSecondFactor,
                showSecurityKey: invalidSecurityKey,
                secondFactorMethod: invalidSecurityKey
                  ? SECOND_FACTOR_METHODS.SECURITY_KEY
                  : SECOND_FACTOR_METHODS.TOTP,
                securityKeyChallenge: result.challenge,
                securityKeyAllowedCredentialIds: result.allowed_credential_ids
              });

              // only need to focus the 2FA input for TOTP
              if (!this.showSecurityKey) {
                Ember.run.scheduleOnce("afterRender", () =>
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
                currentEmail: escape(result.current_email)
              });
            } else if (result.reason === "suspended") {
              this.send("closeModal");
              bootbox.alert(result.error);
            } else {
              this.flash(result.error, "error");
            }
          } else {
            this.set("loggedIn", true);
            // Trigger the browser's password manager using the hidden static login form:
            const hiddenLoginForm = document.getElementById(
              "hidden-login-form"
            );
            const applyHiddenFormInputValue = (value, key) => {
              if (!hiddenLoginForm) return;

              hiddenLoginForm.querySelector(`input[name=${key}]`).value = value;
            };

            const destinationUrl = $.cookie("destination_url");
            const ssoDestinationUrl = $.cookie("sso_destination_url");

            applyHiddenFormInputValue(this.loginName, "username");
            applyHiddenFormInputValue(this.loginPassword, "password");

            if (ssoDestinationUrl) {
              $.removeCookie("sso_destination_url");
              window.location.assign(ssoDestinationUrl);
              return;
            } else if (destinationUrl) {
              // redirect client to the original URL
              $.removeCookie("destination_url");

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
        e => {
          // Failed to login
          if (e.jqXHR && e.jqXHR.status === 429) {
            this.flash(I18n.t("login.rate_limit"), "error");
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

    externalLogin(loginMethod) {
      if (this.loginDisabled) {
        return;
      }

      this.set("loggingIn", true);
      loginMethod.doLogin().catch(() => this.set("loggingIn", false));
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

    forgotPassword() {
      const forgotPasswordController = this.forgotPassword;
      if (forgotPasswordController) {
        forgotPasswordController.set("accountEmailOrUsername", this.loginName);
      }
      this.send("showForgotPassword");
    },

    emailLogin() {
      if (this.processingEmailLink) {
        return;
      }

      if (Ember.isEmpty(this.loginName)) {
        this.flash(I18n.t("login.blank_username"), "error");
        return;
      }

      this.set("processingEmailLink", true);

      ajax("/u/email-login", {
        data: { login: this.loginName.trim() },
        type: "POST"
      })
        .then(data => {
          const loginName = escapeExpression(this.loginName);
          const isEmail = loginName.match(/@/);
          let key = `email_login.complete_${isEmail ? "email" : "username"}`;
          if (data.user_found === false) {
            this.flash(
              I18n.t(`${key}_not_found`, {
                email: loginName,
                username: loginName
              }),
              "error"
            );
          } else {
            this.flash(
              I18n.t(`${key}_found`, { email: loginName, username: loginName })
            );
          }
        })
        .catch(e => this.flash(extractError(e), "error"))
        .finally(() => this.set("processingEmailLink", false));
    },

    authenticateSecurityKey() {
      getWebauthnCredential(
        this.securityKeyChallenge,
        this.securityKeyAllowedCredentialIds,
        credentialData => {
          this.set("securityKeyCredential", credentialData);
          this.send("login");
        },
        errorMessage => {
          this.flash(errorMessage, "error");
        }
      );
    }
  },

  authenticationComplete(options) {
    const loginError = (errorMsg, className, callback) => {
      showModal("login");

      Ember.run.next(() => {
        if (callback) callback();
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
          showLoginButtons: false
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
        $.cookie("destination_url") || options.destination_url;
      if (destinationUrl) {
        // redirect client to the original URL
        $.removeCookie("destination_url");
        window.location.href = destinationUrl;
      } else if (window.location.pathname === Discourse.getURL("/login")) {
        window.location = Discourse.getURL("/");
      } else {
        window.location.reload();
      }
      return;
    }

    const createAccountController = this.createAccount;
    createAccountController.setProperties({
      accountEmail: options.email,
      accountUsername: options.username,
      accountName: options.name,
      authOptions: EmberObject.create(options)
    });

    showModal("createAccount");
  }
});
