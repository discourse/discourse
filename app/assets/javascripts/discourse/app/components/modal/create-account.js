import { A } from "@ember/array";
import Component from "@ember/component";
import EmberObject, { action } from "@ember/object";
import { alias, notEmpty } from "@ember/object/computed";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { observes } from "@ember-decorators/object";
import { Promise } from "rsvp";
import { ajax } from "discourse/lib/ajax";
import { setting } from "discourse/lib/computed";
import cookie, { removeCookie } from "discourse/lib/cookie";
import { userPath } from "discourse/lib/url";
import { emailValid } from "discourse/lib/utilities";
import NameValidation from "discourse/mixins/name-validation";
import PasswordValidation from "discourse/mixins/password-validation";
import UserFieldsValidation from "discourse/mixins/user-fields-validation";
import UsernameValidation from "discourse/mixins/username-validation";
import { findAll } from "discourse/models/login-method";
import User from "discourse/models/user";
import discourseDebounce from "discourse-common/lib/debounce";
import discourseComputed, { bind } from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";

export default class CreateAccount extends Component.extend(
  PasswordValidation,
  UsernameValidation,
  NameValidation,
  UserFieldsValidation
) {
  @service site;
  @service siteSettings;
  @service login;

  accountChallenge = 0;
  accountHoneypot = 0;
  formSubmitted = false;
  rejectedEmails = A();
  prefilledUsername = null;
  userFields = null;
  isDeveloper = false;
  maskPassword = true;
  passwordValidationVisible = false;
  emailValidationVisible = false;

  @notEmpty("model.authOptions") hasAuthOptions;
  @setting("enable_local_logins") canCreateLocal;
  @setting("require_invite_code") requireInviteCode;

  // For UsernameValidation mixin
  @alias("model.authOptions") authOptions;
  @alias("model.accountEmail") accountEmail;
  @alias("model.accountUsername") accountUsername;
  // For NameValidation mixin
  @alias("model.accountName") accountName;

  init() {
    super.init(...arguments);

    if (cookie("email")) {
      this.set("model.accountEmail", cookie("email"));
    }

    this.fetchConfirmationValue();

    if (this.model.skipConfirmation) {
      this.performAccountCreation().finally(() =>
        this.set("model.skipConfirmation", false)
      );
    }
  }

  @bind
  actionOnEnter(event) {
    if (!this.submitDisabled && event.key === "Enter") {
      event.preventDefault();
      event.stopPropagation();
      this.createAccount();
      return false;
    }
  }

  @bind
  selectKitFocus(event) {
    const target = document.getElementById(event.target.getAttribute("for"));
    if (target?.classList.contains("select-kit")) {
      event.preventDefault();
      target.querySelector(".select-kit-header").click();
    }
  }

  @discourseComputed(
    "hasAuthOptions",
    "canCreateLocal",
    "model.skipConfirmation"
  )
  showCreateForm(hasAuthOptions, canCreateLocal, skipConfirmation) {
    return (hasAuthOptions || canCreateLocal) && !skipConfirmation;
  }

  @discourseComputed("site.desktopView", "hasAuthOptions")
  showExternalLoginButtons(desktopView, hasAuthOptions) {
    return desktopView && !hasAuthOptions;
  }

  @discourseComputed("formSubmitted")
  submitDisabled() {
    return this.formSubmitted;
  }

  @discourseComputed("userFields", "hasAtLeastOneLoginButton", "hasAuthOptions")
  modalBodyClasses(userFields, hasAtLeastOneLoginButton, hasAuthOptions) {
    const classes = [];
    if (userFields) {
      classes.push("has-user-fields");
    }
    if (hasAtLeastOneLoginButton && !hasAuthOptions) {
      classes.push("has-alt-auth");
    }
    if (!this.canCreateLocal) {
      classes.push("no-local-logins");
    }
    return classes.join(" ");
  }

  @discourseComputed("model.authOptions", "model.authOptions.can_edit_username")
  usernameDisabled(authOptions, canEditUsername) {
    return authOptions && !canEditUsername;
  }

  @discourseComputed("model.authOptions", "model.authOptions.can_edit_name")
  nameDisabled(authOptions, canEditName) {
    return authOptions && !canEditName;
  }

  @discourseComputed
  fullnameRequired() {
    return (
      this.siteSettings.full_name_required || this.siteSettings.enable_names
    );
  }

  @discourseComputed("model.authOptions.auth_provider")
  passwordRequired(authProvider) {
    return isEmpty(authProvider);
  }

  @discourseComputed
  disclaimerHtml() {
    if (this.site.tos_url && this.site.privacy_policy_url) {
      return I18n.t("create_account.disclaimer", {
        tos_link: this.site.tos_url,
        privacy_link: this.site.privacy_policy_url,
      });
    }
  }

  // Check the email address
  @discourseComputed(
    "serverAccountEmail",
    "serverEmailValidation",
    "model.accountEmail",
    "rejectedEmails.[]",
    "forceValidationReason"
  )
  emailValidation(
    serverAccountEmail,
    serverEmailValidation,
    email,
    rejectedEmails,
    forceValidationReason
  ) {
    const failedAttrs = {
      failed: true,
      ok: false,
      element: document.querySelector("#new-account-email"),
    };

    if (serverAccountEmail === email && serverEmailValidation) {
      return serverEmailValidation;
    }

    // If blank, fail without a reason
    if (isEmpty(email)) {
      return EmberObject.create(
        Object.assign(failedAttrs, {
          message: I18n.t("user.email.required"),
          reason: forceValidationReason ? I18n.t("user.email.required") : null,
        })
      );
    }

    if (rejectedEmails.includes(email) || !emailValid(email)) {
      return EmberObject.create(
        Object.assign(failedAttrs, {
          reason: I18n.t("user.email.invalid"),
        })
      );
    }

    if (
      this.get("model.authOptions.email") === email &&
      this.get("model.authOptions.email_valid")
    ) {
      return EmberObject.create({
        ok: true,
        reason: I18n.t("user.email.authenticated", {
          provider: this.authProviderDisplayName(
            this.get("model.authOptions.auth_provider")
          ),
        }),
      });
    }

    return EmberObject.create({
      ok: true,
      reason: I18n.t("user.email.ok"),
    });
  }

  @action
  showPasswordValidation() {
    this.set("passwordValidationVisible", Boolean(this.passwordValidation.reason));
  }

  @action
  checkEmailAvailability() {
    if (this.emailValidation.reason) {
      this.set("emailValidationVisible", true);
    } else {
      this.set("emailValidationVisible", false);
    }

    if (
      !this.emailValidation.ok ||
      this.serverAccountEmail === this.model.accountEmail
    ) {
      return;
    }

    return User.checkEmail(this.model.accountEmail)
      .then((result) => {
        if (this.isDestroying || this.isDestroyed) {
          return;
        }

        if (result.failed) {
          this.setProperties({
            serverAccountEmail: this.model.accountEmail,
            serverEmailValidation: EmberObject.create({
              failed: true,
              element: document.querySelector("#new-account-email"),
              reason: result.errors[0],
            }),
          });
        } else {
          this.setProperties({
            serverAccountEmail: this.model.accountEmail,
            serverEmailValidation: EmberObject.create({
              ok: true,
              reason: I18n.t("user.email.ok"),
            }),
          });
        }
      })
      .catch(() => {
        this.setProperties({
          serverAccountEmail: null,
          serverEmailValidation: null,
        });
      });
  }

  @discourseComputed(
    "model.accountEmail",
    "model.authOptions.email",
    "model.authOptions.email_valid"
  )
  emailDisabled() {
    return (
      this.get("model.authOptions.email") === this.model.accountEmail &&
      this.get("model.authOptions.email_valid")
    );
  }

  authProviderDisplayName(providerName) {
    const matchingProvider = findAll().find((provider) => {
      return provider.name === providerName;
    });
    return matchingProvider ? matchingProvider.get("prettyName") : providerName;
  }

  @observes("emailValidation", "model.accountEmail")
  prefillUsername() {
    if (this.prefilledUsername) {
      // If username field has been filled automatically, and email field just changed,
      // then remove the username.
      if (this.model.accountUsername === this.prefilledUsername) {
        this.set("model.accountUsername", "");
      }
      this.set("prefilledUsername", null);
    }
    if (
      this.get("emailValidation.ok") &&
      (isEmpty(this.model.accountUsername) ||
        this.get("model.authOptions.email"))
    ) {
      // If email is valid and username has not been entered yet,
      // or email and username were filled automatically by 3rd party auth,
      // then look for a registered username that matches the email.
      discourseDebounce(this, this.fetchExistingUsername, 500);
    }
  }

  // Determines whether at least one login button is enabled
  @discourseComputed
  hasAtLeastOneLoginButton() {
    return findAll().length > 0;
  }

  fetchConfirmationValue() {
    if (this._challengeDate === undefined && this._hpPromise) {
      // Request already in progress
      return this._hpPromise;
    }

    this._hpPromise = ajax("/session/hp.json")
      .then((json) => {
        if (this.isDestroying || this.isDestroyed) {
          return;
        }

        this._challengeDate = new Date();
        // remove 30 seconds for jitter, make sure this works for at least
        // 30 seconds so we don't have hard loops
        this._challengeExpiry = parseInt(json.expires_in, 10) - 30;
        if (this._challengeExpiry < 30) {
          this._challengeExpiry = 30;
        }

        this.setProperties({
          accountHoneypot: json.value,
          accountChallenge: json.challenge.split("").reverse().join(""),
        });
      })
      .finally(() => (this._hpPromise = undefined));

    return this._hpPromise;
  }

  performAccountCreation() {
    if (
      !this._challengeDate ||
      new Date() - this._challengeDate > 1000 * this._challengeExpiry
    ) {
      return this.fetchConfirmationValue().then(() =>
        this.performAccountCreation()
      );
    }

    const attrs = {
      accountName: this.model.accountName,
      accountEmail: this.model.accountEmail,
      accountPassword: this.accountPassword,
      accountUsername: this.model.accountUsername,
      accountChallenge: this.accountChallenge,
      inviteCode: this.inviteCode,
      accountPasswordConfirm: this.accountHoneypot,
    };

    const destinationUrl = this.get("model.authOptions.destination_url");

    if (!isEmpty(destinationUrl)) {
      cookie("destination_url", destinationUrl, { path: "/" });
    }

    // Add the userFields to the data
    if (!isEmpty(this.userFields)) {
      attrs.userFields = {};
      this.userFields.forEach(
        (f) => (attrs.userFields[f.get("field.id")] = f.get("value"))
      );
    }

    this.set("formSubmitted", true);
    return User.createAccount(attrs).then(
      (result) => {
        if (this.isDestroying || this.isDestroyed) {
          return;
        }

        this.set("isDeveloper", false);
        if (result.success) {
          // invalidate honeypot
          this._challengeExpiry = 1;

          // Trigger the browser's password manager using the hidden static login form:
          const hiddenLoginForm = document.querySelector("#hidden-login-form");
          if (hiddenLoginForm) {
            hiddenLoginForm.querySelector("input[name=username]").value =
              attrs.accountUsername;
            hiddenLoginForm.querySelector("input[name=password]").value =
              attrs.accountPassword;
            hiddenLoginForm.querySelector("input[name=redirect]").value =
              userPath("account-created");
            hiddenLoginForm.submit();
          }
          return new Promise(() => {}); // This will never resolve, the page will reload instead
        } else {
          this.set("flash", result.message || I18n.t("create_account.failed"));
          if (result.is_developer) {
            this.set("isDeveloper", true);
          }
          if (
            result.errors &&
            result.errors.email &&
            result.errors.email.length > 0 &&
            result.values
          ) {
            this.rejectedEmails.pushObject(result.values.email);
          }
          if (
            result.errors &&
            result.errors.password &&
            result.errors.password.length > 0
          ) {
            this.rejectedPasswords.pushObject(attrs.accountPassword);
          }
          this.set("formSubmitted", false);
          removeCookie("destination_url");
        }
      },
      () => {
        this.set("formSubmitted", false);
        removeCookie("destination_url");
        return this.set("flash", I18n.t("create_account.failed"));
      }
    );
  }

  @discourseComputed(
    "model.authOptions.associate_url",
    "model.authOptions.auth_provider"
  )
  associateHtml(url, provider) {
    if (!url) {
      return;
    }
    return I18n.t("create_account.associate", {
      associate_link: url,
      provider: I18n.t(`login.${provider}.name`),
    });
  }

  @action
  scrollInputIntoView(event) {
    event.target.scrollIntoView({
      behavior: "smooth",
      block: "center",
    });
  }

  @action
  togglePasswordMask() {
    this.toggleProperty("maskPassword");
  }

  @action
  externalLogin(provider) {
    // we will automatically redirect to the external auth service
    this.login.externalLogin(provider, { signup: true });
  }

  @action
  createAccount() {
    this.set("flash", "");
    this.set("forceValidationReason", true);
    this.set("emailValidationVisible", true);
    this.set("passwordValidationVisible", true);

    const validation = [
      this.emailValidation,
      this.usernameValidation,
      this.nameValidation,
      this.passwordValidation,
      this.userFieldsValidation,
    ].find((v) => v.failed);

    if (validation) {
      const element = validation.element;
      if (element) {
        if (element.tagName === "DIV") {
          if (element.scrollIntoView) {
            element.scrollIntoView();
          }
          element.click();
        } else {
          element.focus();
        }
      }

      return;
    }

    this.set("forceValidationReason", false);
    this.performAccountCreation();
  }
}
