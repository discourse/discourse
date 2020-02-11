import { isEmpty } from "@ember/utils";
import { notEmpty, or, not } from "@ember/object/computed";
import { inject } from "@ember/controller";
import Controller from "@ember/controller";
import { ajax } from "discourse/lib/ajax";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { setting } from "discourse/lib/computed";
import discourseComputed, {
  observes,
  on
} from "discourse-common/utils/decorators";
import { emailValid } from "discourse/lib/utilities";
import PasswordValidation from "discourse/mixins/password-validation";
import UsernameValidation from "discourse/mixins/username-validation";
import NameValidation from "discourse/mixins/name-validation";
import UserFieldsValidation from "discourse/mixins/user-fields-validation";
import { userPath } from "discourse/lib/url";
import { findAll } from "discourse/models/login-method";
import EmberObject from "@ember/object";
import User from "discourse/models/user";

export default Controller.extend(
  ModalFunctionality,
  PasswordValidation,
  UsernameValidation,
  NameValidation,
  UserFieldsValidation,
  {
    login: inject(),

    complete: false,
    accountChallenge: 0,
    accountHoneypot: 0,
    formSubmitted: false,
    rejectedEmails: Ember.A([]),
    prefilledUsername: null,
    userFields: null,
    isDeveloper: false,

    hasAuthOptions: notEmpty("authOptions"),
    canCreateLocal: setting("enable_local_logins"),
    showCreateForm: or("hasAuthOptions", "canCreateLocal"),

    resetForm() {
      // We wrap the fields in a structure so we can assign a value
      this.setProperties({
        accountName: "",
        accountEmail: "",
        accountUsername: "",
        accountPassword: "",
        authOptions: null,
        complete: false,
        formSubmitted: false,
        rejectedEmails: [],
        rejectedPasswords: [],
        prefilledUsername: null,
        isDeveloper: false
      });
      this._createUserFields();
    },

    @discourseComputed(
      "passwordRequired",
      "nameValidation.failed",
      "emailValidation.failed",
      "usernameValidation.failed",
      "passwordValidation.failed",
      "userFieldsValidation.failed",
      "formSubmitted"
    )
    submitDisabled() {
      if (this.formSubmitted) return true;
      if (this.get("nameValidation.failed")) return true;
      if (this.get("emailValidation.failed")) return true;
      if (this.get("usernameValidation.failed") && this.usernameRequired)
        return true;
      if (this.get("passwordValidation.failed") && this.passwordRequired)
        return true;
      if (this.get("userFieldsValidation.failed")) return true;

      return false;
    },

    usernameRequired: not("authOptions.omit_username"),

    @discourseComputed
    fullnameRequired() {
      return (
        this.get("siteSettings.full_name_required") ||
        this.get("siteSettings.enable_names")
      );
    },

    @discourseComputed("authOptions.auth_provider")
    passwordRequired(authProvider) {
      return isEmpty(authProvider);
    },

    @discourseComputed
    disclaimerHtml() {
      return I18n.t("create_account.disclaimer", {
        tos_link: this.get("siteSettings.tos_url") || Discourse.getURL("/tos"),
        privacy_link:
          this.get("siteSettings.privacy_policy_url") ||
          Discourse.getURL("/privacy")
      });
    },

    // Check the email address
    @discourseComputed("accountEmail", "rejectedEmails.[]")
    emailValidation(email, rejectedEmails) {
      // If blank, fail without a reason
      if (isEmpty(email)) {
        return EmberObject.create({
          failed: true
        });
      }

      if (rejectedEmails.includes(email)) {
        return EmberObject.create({
          failed: true,
          reason: I18n.t("user.email.invalid")
        });
      }

      if (
        this.get("authOptions.email") === email &&
        this.get("authOptions.email_valid")
      ) {
        return EmberObject.create({
          ok: true,
          reason: I18n.t("user.email.authenticated", {
            provider: this.authProviderDisplayName(
              this.get("authOptions.auth_provider")
            )
          })
        });
      }

      if (emailValid(email)) {
        return EmberObject.create({
          ok: true,
          reason: I18n.t("user.email.ok")
        });
      }

      return EmberObject.create({
        failed: true,
        reason: I18n.t("user.email.invalid")
      });
    },

    @discourseComputed(
      "accountEmail",
      "authOptions.email",
      "authOptions.email_valid"
    )
    emailValidated() {
      return (
        this.get("authOptions.email") === this.accountEmail &&
        this.get("authOptions.email_valid")
      );
    },

    authProviderDisplayName(providerName) {
      const matchingProvider = findAll().find(provider => {
        return provider.name === providerName;
      });
      return matchingProvider
        ? matchingProvider.get("prettyName")
        : providerName;
    },

    @observes("emailValidation", "accountEmail")
    prefillUsername: function() {
      if (this.prefilledUsername) {
        // If username field has been filled automatically, and email field just changed,
        // then remove the username.
        if (this.accountUsername === this.prefilledUsername) {
          this.set("accountUsername", "");
        }
        this.set("prefilledUsername", null);
      }
      if (
        this.get("emailValidation.ok") &&
        (isEmpty(this.accountUsername) || this.get("authOptions.email"))
      ) {
        // If email is valid and username has not been entered yet,
        // or email and username were filled automatically by 3rd parth auth,
        // then look for a registered username that matches the email.
        this.fetchExistingUsername();
      }
    },

    // Determines whether at least one login button is enabled
    @discourseComputed
    hasAtLeastOneLoginButton() {
      return findAll().length > 0;
    },

    @on("init")
    fetchConfirmationValue() {
      return ajax(userPath("hp.json")).then(json => {
        this._challengeDate = new Date();
        // remove 30 seconds for jitter, make sure this works for at least
        // 30 seconds so we don't have hard loops
        this._challengeExpiry = parseInt(json.expires_in, 10) - 30;
        if (this._challengeExpiry < 30) {
          this._challengeExpiry = 30;
        }

        this.setProperties({
          accountHoneypot: json.value,
          accountChallenge: json.challenge
            .split("")
            .reverse()
            .join("")
        });
      });
    },

    performAccountCreation() {
      const attrs = this.getProperties(
        "accountName",
        "accountEmail",
        "accountPassword",
        "accountUsername",
        "accountChallenge"
      );

      attrs["accountPasswordConfirm"] = this.accountHoneypot;

      const userFields = this.userFields;
      const destinationUrl = this.get("authOptions.destination_url");

      if (!isEmpty(destinationUrl)) {
        $.cookie("destination_url", destinationUrl, { path: "/" });
      }

      // Add the userfields to the data
      if (!isEmpty(userFields)) {
        attrs.userFields = {};
        userFields.forEach(
          f => (attrs.userFields[f.get("field.id")] = f.get("value"))
        );
      }

      this.set("formSubmitted", true);
      return User.createAccount(attrs).then(
        result => {
          this.set("isDeveloper", false);
          if (result.success) {
            // invalidate honeypot
            this._challengeExpiry = 1;

            // Trigger the browser's password manager using the hidden static login form:
            const $hidden_login_form = $("#hidden-login-form");
            $hidden_login_form
              .find("input[name=username]")
              .val(attrs.accountUsername);
            $hidden_login_form
              .find("input[name=password]")
              .val(attrs.accountPassword);
            $hidden_login_form
              .find("input[name=redirect]")
              .val(userPath("account-created"));
            $hidden_login_form.submit();
          } else {
            this.flash(
              result.message || I18n.t("create_account.failed"),
              "error"
            );
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
            $.removeCookie("destination_url");
          }
        },
        () => {
          this.set("formSubmitted", false);
          $.removeCookie("destination_url");
          return this.flash(I18n.t("create_account.failed"), "error");
        }
      );
    },

    actions: {
      externalLogin(provider) {
        this.login.send("externalLogin", provider);
      },

      createAccount() {
        if (new Date() - this._challengeDate > 1000 * this._challengeExpiry) {
          this.fetchConfirmationValue().then(() =>
            this.performAccountCreation()
          );
        } else {
          this.performAccountCreation();
        }
      }
    }
  }
);
