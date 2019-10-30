import { alias, notEmpty } from "@ember/object/computed";
import Controller from "@ember/controller";
import { default as computed } from "ember-addons/ember-computed-decorators";
import getUrl from "discourse-common/lib/get-url";
import DiscourseURL from "discourse/lib/url";
import { ajax } from "discourse/lib/ajax";
import PasswordValidation from "discourse/mixins/password-validation";
import UsernameValidation from "discourse/mixins/username-validation";
import NameValidation from "discourse/mixins/name-validation";
import UserFieldsValidation from "discourse/mixins/user-fields-validation";
import { findAll as findLoginMethods } from "discourse/models/login-method";

export default Controller.extend(
  PasswordValidation,
  UsernameValidation,
  NameValidation,
  UserFieldsValidation,
  {
    invitedBy: alias("model.invited_by"),
    email: alias("model.email"),
    accountUsername: alias("model.username"),
    passwordRequired: notEmpty("accountPassword"),
    successMessage: null,
    errorMessage: null,
    userFields: null,
    inviteImageUrl: getUrl("/images/envelope.svg"),

    @computed
    welcomeTitle() {
      return I18n.t("invites.welcome_to", {
        site_name: this.siteSettings.title
      });
    },

    @computed("email")
    yourEmailMessage(email) {
      return I18n.t("invites.your_email", { email: email });
    },

    @computed
    externalAuthsEnabled() {
      return findLoginMethods().length > 0;
    },

    @computed(
      "usernameValidation.failed",
      "passwordValidation.failed",
      "nameValidation.failed",
      "userFieldsValidation.failed"
    )
    submitDisabled(
      usernameFailed,
      passwordFailed,
      nameFailed,
      userFieldsFailed
    ) {
      return usernameFailed || passwordFailed || nameFailed || userFieldsFailed;
    },

    @computed
    fullnameRequired() {
      return (
        this.siteSettings.full_name_required || this.siteSettings.enable_names
      );
    },

    actions: {
      submit() {
        const userFields = this.userFields;
        let userCustomFields = {};
        if (!Ember.isEmpty(userFields)) {
          userFields.forEach(function(f) {
            userCustomFields[f.get("field.id")] = f.get("value");
          });
        }

        ajax({
          url: `/invites/show/${this.get("model.token")}.json`,
          type: "PUT",
          data: {
            username: this.accountUsername,
            name: this.accountName,
            password: this.accountPassword,
            user_custom_fields: userCustomFields
          }
        })
          .then(result => {
            if (result.success) {
              this.set(
                "successMessage",
                result.message || I18n.t("invites.success")
              );
              if (result.redirect_to) {
                DiscourseURL.redirectTo(result.redirect_to);
              }
            } else {
              if (
                result.errors &&
                result.errors.password &&
                result.errors.password.length > 0
              ) {
                this.rejectedPasswords.pushObject(this.accountPassword);
                this.rejectedPasswordsMessages.set(
                  this.accountPassword,
                  result.errors.password[0]
                );
              }
              if (result.message) {
                this.set("errorMessage", result.message);
              }
            }
          })
          .catch(error => {
            throw new Error(error);
          });
      }
    }
  }
);
