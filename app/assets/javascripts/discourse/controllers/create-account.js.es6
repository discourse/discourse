import { ajax } from "discourse/lib/ajax";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { setting } from "discourse/lib/computed";
import {
  default as computed,
  observes,
  on
} from "ember-addons/ember-computed-decorators";
import { emailValid } from "discourse/lib/utilities";
import InputValidation from "discourse/models/input-validation";
import PasswordValidation from "discourse/mixins/password-validation";
import UsernameValidation from "discourse/mixins/username-validation";
import NameValidation from "discourse/mixins/name-validation";
import UserFieldsValidation from "discourse/mixins/user-fields-validation";
import { userPath } from "discourse/lib/url";
import { findAll } from "discourse/models/login-method";

export default Ember.Controller.extend(
  ModalFunctionality,
  PasswordValidation,
  UsernameValidation,
  NameValidation,
  UserFieldsValidation,
  {
    login: Ember.inject.controller(),

    complete: false,
    accountPasswordConfirm: 0,
    accountChallenge: 0,
    formSubmitted: false,
    rejectedEmails: Ember.A([]),
    prefilledUsername: null,
    userFields: null,
    isDeveloper: false,

    hasAuthOptions: Ember.computed.notEmpty("authOptions"),
    canCreateLocal: setting("enable_local_logins"),
    showCreateForm: Ember.computed.or("hasAuthOptions", "canCreateLocal"),

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

    @computed(
      "passwordRequired",
      "nameValidation.failed",
      "emailValidation.failed",
      "usernameValidation.failed",
      "passwordValidation.failed",
      "userFieldsValidation.failed",
      "formSubmitted"
    )
    submitDisabled(
      passwordRequired,
      nameValidationFailed,
      emailValidationFailed,
      usernameValidationFailed,
      passwordValidationFailed,
      userFieldsValidationFailed,
      formSubmitted
    ) {
      // 3rd party auth
      if (!emailValidationFailed && !passwordRequired) return false;

      if (formSubmitted) return true;
      if (nameValidationFailed) return true;
      if (emailValidationFailed) return true;
      if (usernameValidationFailed) return true;
      if (passwordValidationFailed) return true;
      if (userFieldsValidationFailed) return true;

      return false;
    },

    usernameRequired: Ember.computed.not("authOptions.omit_username"),

    @computed
    fullnameRequired() {
      return (
        this.get("siteSettings.full_name_required") ||
        this.get("siteSettings.enable_names")
      );
    },

    passwordRequired: Ember.computed.isEmpty("authOptions.auth_provider"),

    @computed
    disclaimerHtml() {
      return I18n.t("create_account.disclaimer", {
        tos_link: this.get("siteSettings.tos_url") || Discourse.getURL("/tos"),
        privacy_link:
          this.get("siteSettings.privacy_policy_url") ||
          Discourse.getURL("/privacy")
      });
    },

    @computed("accountEmail", "rejectedEmails.[]")
    emailValidation(accountEmail, rejectedEmails) {
      // If blank, fail without a reason
      if (Ember.isEmpty(accountEmail)) {
        return InputValidation.create({ failed: true });
      }

      let email = accountEmail;

      if (rejectedEmails.includes(email)) {
        return InputValidation.create({
          failed: true,
          reason: I18n.t("user.email.invalid")
        });
      }

      if (
        this.get("authOptions.email") === email &&
        this.get("authOptions.email_valid")
      ) {
        return InputValidation.create({
          ok: true,
          reason: I18n.t("user.email.authenticated", {
            provider: this.authProviderDisplayName(
              this.get("authOptions.auth_provider")
            )
          })
        });
      }

      if (emailValid(email)) {
        return InputValidation.create({
          ok: true,
          reason: I18n.t("user.email.ok")
        });
      }

      return InputValidation.create({
        failed: true,
        reason: I18n.t("user.email.invalid")
      });
    },

    @computed("accountEmail", "authOptions.email", "authOptions.email_valid")
    emailValidated(accountEmail, authOptionsEmail, authOptionsEmailValid) {
      return authOptionsEmail === accountEmail && authOptionsEmailValid;
    },

    authProviderDisplayName(providerName) {
      const matchingProvider = findAll().find(
        provider => provider.name === providerName
      );

      return matchingProvider
        ? matchingProvider.get("prettyName")
        : providerName;
    },

    @observes("emailValidation", "accountEmail")
    prefillUsername() {
      if (this.get("prefilledUsername")) {
        // If username field has been filled automatically, and email field just changed,
        // then remove the username.
        if (this.get("accountUsername") === this.get("prefilledUsername")) {
          this.set("accountUsername", "");
        }

        this.set("prefilledUsername", null);
      }

      if (
        this.get("emailValidation.ok") &&
        (Ember.isEmpty(this.get("accountUsername")) ||
          this.get("authOptions.email"))
      ) {
        // If email is valid and username has not been entered yet,
        // or email and username were filled automatically by 3rd parth auth,
        // then look for a registered username that matches the email.
        this.fetchExistingUsername();
      }
    },

    @computed
    hasAtLeastOneLoginButton() {
      return findAll(this.siteSettings).length > 0;
    },

    @on("init")
    fetchConfirmationValue() {
      return ajax(userPath("hp.json")).then(json => {
        this.setProperties({
          accountPasswordConfirm: json.value,
          accountChallenge: json.challenge
            .split("")
            .reverse()
            .join("")
        });
      });
    },

    actions: {
      externalLogin(provider) {
        this.get("login").send("externalLogin", provider);
      },

      createAccount() {
        const attrs = this.getProperties(
          "accountName",
          "accountEmail",
          "accountPassword",
          "accountUsername",
          "accountPasswordConfirm",
          "accountChallenge"
        );
        const userFields = this.get("userFields");
        const destinationUrl = this.get("authOptions.destination_url");

        if (!Ember.isEmpty(destinationUrl)) {
          $.cookie("destination_url", destinationUrl, { path: "/" });
        }

        // Add the userfields to the data
        if (!Ember.isEmpty(userFields)) {
          attrs.userFields = {};
          userFields.forEach(
            f => (attrs.userFields[f.get("field.id")] = f.get("value"))
          );
        }

        this.set("formSubmitted", true);
        return Discourse.User.createAccount(attrs).then(
          result => {
            this.set("isDeveloper", false);
            if (result.success) {
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
                this.get("rejectedEmails").pushObject(result.values.email);
              }
              if (
                result.errors &&
                result.errors.password &&
                result.errors.password.length > 0
              ) {
                this.get("rejectedPasswords").pushObject(attrs.accountPassword);
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
      }
    }
  }
);
