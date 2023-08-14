import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { alias, not, or, readOnly } from "@ember/object/computed";
import { inject as service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";
import { ajax } from "discourse/lib/ajax";
import { findAll } from "discourse/models/login-method";
import showModal from "discourse/lib/show-modal";
import getWebauthnCredential from "discourse/lib/webauthn";
import { areCookiesEnabled, escapeExpression } from "discourse/lib/utilities";
import { flashAjaxError } from "discourse/lib/ajax-error";
import { setting } from "discourse/lib/computed";
import { wavingHandURL } from "discourse/lib/waving-hand-url";
import ForgotPassword from "discourse/components/modal/forgot-password";
import { getOwner } from "discourse-common/lib/get-owner";
import { next, schedule } from "@ember/runloop";

// This is happening outside of the app via popup
const AuthErrors = [
  "requires_invite",
  "awaiting_approval",
  "awaiting_activation",
  "admin_not_allowed_from_ip_address",
  "not_allowed_from_ip_address",
];

export default class Login extends Component {
  // createAccount controller(),
  // application controller(),
  @service dialog;

  @tracked loggingIn = false;
  @tracked loggedIn = false;
  @tracked processingEmailLink = false;
  @tracked showLoginButtons = true;
  @tracked showSecondFactor = false;
  @tracked awaitingApproval = false;
  @tracked maskPassword = true;
  @tracked loginPassword = "";
  @tracked loginName = "";

  @tracked canLoginLocal = setting("enable_local_logins");
  @tracked canLoginLocalWithEmail = setting("enable_local_logins_via_email");
  @tracked loginRequired = alias("application.loginRequired");
  @tracked secondFactorMethod = SECOND_FACTOR_METHODS.TOTP;

  constructor() {
    super(...arguments);
    console.log(this.args.isExternalLogin);
    if (this.args.isExternalLogin) {
      this.externalLogin(this.args.externalLoginMethod, {
        signup: this.args.signup,
      });
    }
  }

  get loginDisabled() {
    return this.loggingIn || this.loggedIn;
  }

  get showSpinner() {
    return readOnly("loggingIn");
  }

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
  }

  @action
  doTheThing() {
    const prefillUsername = $("#hidden-login-form input[name=username]").val();
    if (prefillUsername) {
      this.loginName = prefillUsername;
      this.loginPassword = $("#hidden-login-form input[name=password]").val();
    } else if (cookie("email")) {
      this.loginName = cookie("email");
    }

    schedule("afterRender", () => {
      $(
        "#login-account-password, #login-account-name, #login-second-factor"
      ).keydown((e) => {
        if (e.key === "Enter") {
          this.login();
        }
      });
    });
  }

  // get credentialsClass() {
  //   return this.showSecondFactor || this.showSecurityKey ? "hidden" : "";
  // }

  // get secondFactorClass() {
  //   return this.showSecondFactor || this.showSecurityKey ? "" : "hidden";
  // }

  // // @discourseComputed()
  // // wavingHandURL: () => wavingHandURL()

  // get modalBodyClasses() {
  //   const classes = ["login-modal-body"];
  //   if (this.awaitingApproval) {
  //     classes.push("awaiting-approval");
  //   }
  //   if (
  //     this.hasAtLeastOneLoginButton &&
  //     !this.showSecondFactor &&
  //     !this.showSecurityKey
  //   ) {
  //     classes.push("has-alt-auth");
  //   }
  //   if (!this.canLoginLocal) {
  //     classes.push("no-local-login");
  //   }
  //   if (this.showSecondFactor || this.showSecurityKey) {
  //     classes.push("second-factor");
  //   }
  //   return classes.join(" ");
  // }

  // get disableLoginFields() {
  //   return this.showSecondFactor || this.showSecurityKey;
  // }

  // get hasAtLeastOneLoginButton() {
  //   return findAll().length > 0;
  // }

  // get loginButtonLabel() {
  //   return this.loggingIn ? "login.logging_in" : "login.title";
  // }

  // get showSignupLink() {
  //   return (
  //     getOwner(this).lookup("controller:application").canSignUp &&
  //     !this.loggingIn
  //   );
  // }

  // @action
  // emailLogin(event) {
  //   event?.preventDefault();

  //   if (this.processingEmailLink) {
  //     return;
  //   }

  //   if (isEmpty(this.loginName)) {
  //     this.flash(I18n.t("login.blank_username"), "info");
  //     return;
  //   }

  //   this.set("processingEmailLink", true);

  //   ajax("/u/email-login", {
  //     data: { login: this.loginName.trim() },
  //     type: "POST",
  //   })
  //     .then((data) => {
  //       const loginName = escapeExpression(this.loginName);
  //       const isEmail = loginName.match(/@/);
  //       let key = isEmail
  //         ? "email_login.complete_email"
  //         : "email_login.complete_username";
  //       if (data.user_found === false) {
  //         this.flash(
  //           htmlSafe(
  //             I18n.t(`${key}_not_found`, {
  //               email: loginName,
  //               username: loginName,
  //             })
  //           ),
  //           "error"
  //         );
  //       } else {
  //         let postfix = data.hide_taken ? "" : "_found";
  //         this.flash(
  //           htmlSafe(
  //             I18n.t(`${key}${postfix}`, {
  //               email: loginName,
  //               username: loginName,
  //             })
  //           )
  //         );
  //       }
  //     })
  //     .catch(flashAjaxError(this))
  //     .finally(() => this.set("processingEmailLink", false));
  // }

  // @action
  // handleForgotPassword(event) {
  //   event?.preventDefault();

  //   this.modal.show(ForgotPassword, {
  //     model: {
  //       emailOrUsername: this.loginName,
  //     },
  //   });
  // }

  // @action
  // togglePasswordMask() {
  //   this.toggleProperty("maskPassword");
  // }

  // @action
  // forgotPassword() {
  //   this.handleForgotPassword();
  // }

  // @action
  // login() {
  //   if (this.loginDisabled) {
  //     return;
  //   }

  //   if (isEmpty(this.loginName) || isEmpty(this.loginPassword)) {
  //     this.flash(I18n.t("login.blank_username_or_password"), "error");
  //     return;
  //   }

  //   this.loggingIn = true;

  //   ajax("/session", {
  //     type: "POST",
  //     data: {
  //       login: this.loginName,
  //       password: this.loginPassword,
  //       second_factor_token:
  //         this.securityKeyCredential || this.secondFactorToken,
  //       second_factor_method: this.secondFactorMethod,
  //       timezone: moment.tz.guess(),
  //     },
  //   }).then(
  //     (result) => {
  //       // Successful login
  //       if (result && result.error) {
  //         this.set("loggingIn", false);
  //         this.clearFlash();

  //         if (
  //           (result.security_key_enabled || result.totp_enabled) &&
  //           !this.secondFactorRequired
  //         ) {
  //           this.setProperties({
  //             otherMethodAllowed: result.multiple_second_factor_methods,
  //             secondFactorRequired: true,
  //             showLoginButtons: false,
  //             backupEnabled: result.backup_enabled,
  //             totpEnabled: result.totp_enabled,
  //             showSecondFactor: result.totp_enabled,
  //             showSecurityKey: result.security_key_enabled,
  //             secondFactorMethod: result.security_key_enabled
  //               ? SECOND_FACTOR_METHODS.SECURITY_KEY
  //               : SECOND_FACTOR_METHODS.TOTP,
  //             securityKeyChallenge: result.challenge,
  //             securityKeyAllowedCredentialIds: result.allowed_credential_ids,
  //           });

  //           // only need to focus the 2FA input for TOTP
  //           if (!this.showSecurityKey) {
  //             schedule("afterRender", () =>
  //               document
  //                 .getElementById("second-factor")
  //                 .querySelector("input")
  //                 .focus()
  //             );
  //           }

  //           return;
  //         } else if (result.reason === "not_activated") {
  //           this.send("showNotActivated", {
  //             username: this.loginName,
  //             sentTo: escape(result.sent_to_email),
  //             currentEmail: escape(result.current_email),
  //           });
  //         } else if (result.reason === "suspended") {
  //           this.send("closeModal");
  //           this.dialog.alert(result.error);
  //         } else {
  //           this.flash(result.error, "error");
  //         }
  //       } else {
  //         this.set("loggedIn", true);
  //         // Trigger the browser's password manager using the hidden static login form:
  //         const hiddenLoginForm = document.getElementById("hidden-login-form");
  //         const applyHiddenFormInputValue = (value, key) => {
  //           if (!hiddenLoginForm) {
  //             return;
  //           }

  //           hiddenLoginForm.querySelector(`input[name=${key}]`).value = value;
  //         };

  //         const destinationUrl = cookie("destination_url");
  //         const ssoDestinationUrl = cookie("sso_destination_url");

  //         applyHiddenFormInputValue(this.loginName, "username");
  //         applyHiddenFormInputValue(this.loginPassword, "password");

  //         if (ssoDestinationUrl) {
  //           removeCookie("sso_destination_url");
  //           window.location.assign(ssoDestinationUrl);
  //           return;
  //         } else if (destinationUrl) {
  //           // redirect client to the original URL
  //           removeCookie("destination_url");

  //           applyHiddenFormInputValue(destinationUrl, "redirect");
  //         } else {
  //           applyHiddenFormInputValue(window.location.href, "redirect");
  //         }

  //         if (hiddenLoginForm) {
  //           if (
  //             navigator.userAgent.match(/(iPad|iPhone|iPod)/g) &&
  //             navigator.userAgent.match(/Safari/g)
  //           ) {
  //             // In case of Safari on iOS do not submit hidden login form
  //             window.location.href = hiddenLoginForm.querySelector(
  //               "input[name=redirect]"
  //             ).value;
  //           } else {
  //             hiddenLoginForm.submit();
  //           }
  //         }
  //         return;
  //       }
  //     },
  //     (e) => {
  //       // Failed to login
  //       if (e.jqXHR && e.jqXHR.status === 429) {
  //         this.flash(I18n.t("login.rate_limit"), "error");
  //       } else if (
  //         e.jqXHR &&
  //         e.jqXHR.status === 503 &&
  //         e.jqXHR.responseJSON.error_type === "read_only"
  //       ) {
  //         this.flash(I18n.t("read_only_mode.login_disabled"), "error");
  //       } else if (!areCookiesEnabled()) {
  //         this.flash(I18n.t("login.cookies_error"), "error");
  //       } else {
  //         this.flash(I18n.t("login.error"), "error");
  //       }
  //       this.set("loggingIn", false);
  //     }
  //   );

  //   return false;
  // }

  @action
  externalLogin(loginMethod, { signup = false } = {}) {
    if (this.loginDisabled) {
      return;
    }

    this.loggingIn = true;
    loginMethod.doLogin({ signup }).catch(() => this.set("loggingIn", false));
  }

  // @action
  // createAccount() {
  //   const createAccountController = this.createAccount;
  //   if (createAccountController) {
  //     createAccountController.resetForm();
  //     if (this.loginName && this.loginName.indexOf("@") > 0) {
  //       createAccountController.set("accountEmail", this.loginName);
  //     } else {
  //       createAccountController.set("accountUsername", this.loginName);
  //     }
  //   }
  //   this.send("showCreateAccount");
  // }

  // @action
  // authenticateSecurityKey() {
  //   getWebauthnCredential(
  //     this.securityKeyChallenge,
  //     this.securityKeyAllowedCredentialIds,
  //     (credentialData) => {
  //       this.set("securityKeyCredential", credentialData);
  //       this.send("login");
  //     },
  //     (errorMessage) => {
  //       this.flash(errorMessage, "error");
  //     }
  //   );
  // }

  // @action
  // authenticationComplete(options) {
  //   const loginError = (errorMsg, className, callback) => {
  //     showModal("login");

  //     next(() => {
  //       if (callback) {
  //         callback();
  //       }
  //       this.flash(errorMsg, className || "success");
  //     });
  //   };

  //   if (
  //     options.awaiting_approval &&
  //     !this.canLoginLocal &&
  //     !this.canLoginLocalWithEmail
  //   ) {
  //     this.set("awaitingApproval", true);
  //   }

  //   if (options.omniauth_disallow_totp) {
  //     return loginError(I18n.t("login.omniauth_disallow_totp"), "error", () => {
  //       this.setProperties({
  //         loginName: options.email,
  //         showLoginButtons: false,
  //       });

  //       document.getElementById("login-account-password").focus();
  //     });
  //   }

  //   for (let i = 0; i < AuthErrors.length; i++) {
  //     const cond = AuthErrors[i];
  //     if (options[cond]) {
  //       return loginError(I18n.t(`login.${cond}`));
  //     }
  //   }

  //   if (options.suspended) {
  //     return loginError(options.suspended_message, "error");
  //   }

  //   // Reload the page if we're authenticated
  //   if (options.authenticated) {
  //     const destinationUrl =
  //       cookie("destination_url") || options.destination_url;
  //     if (destinationUrl) {
  //       // redirect client to the original URL
  //       removeCookie("destination_url");
  //       window.location.href = destinationUrl;
  //     } else if (window.location.pathname === getURL("/login")) {
  //       window.location = getURL("/");
  //     } else {
  //       window.location.reload();
  //     }
  //     return;
  //   }

  //   const skipConfirmation = this.siteSettings.auth_skip_create_confirm;
  //   const createAccountController = this.createAccount;

  //   createAccountController.setProperties({
  //     accountEmail: options.email,
  //     accountUsername: options.username,
  //     accountName: options.name,
  //     authOptions: EmberObject.create(options),
  //     skipConfirmation,
  //   });

  //   next(() => {
  //     showModal("create-account", {
  //       modalClass: "create-account",
  //       titleAriaElementId: "create-account-title",
  //     });
  //   });
  // }
}
