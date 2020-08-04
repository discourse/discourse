import I18n from "I18n";
import { isEmpty } from "@ember/utils";
import { alias, notEmpty, or, readOnly } from "@ember/object/computed";
import Controller from "@ember/controller";
import discourseComputed from "discourse-common/utils/decorators";
import getUrl from "discourse-common/lib/get-url";
import DiscourseURL from "discourse/lib/url";
import { ajax } from "discourse/lib/ajax";
import { emailValid } from "discourse/lib/utilities";
import PasswordValidation from "discourse/mixins/password-validation";
import UsernameValidation from "discourse/mixins/username-validation";
import NameValidation from "discourse/mixins/name-validation";
import UserFieldsValidation from "discourse/mixins/user-fields-validation";
import { findAll as findLoginMethods } from "discourse/models/login-method";
import EmberObject from "@ember/object";

export default Controller.extend(
  PasswordValidation,
  UsernameValidation,
  NameValidation,
  UserFieldsValidation,
  {
    invitedBy: readOnly("model.invited_by"),
    email: alias("model.email"),
    accountUsername: alias("model.username"),
    passwordRequired: notEmpty("accountPassword"),
    successMessage: null,
    errorMessage: null,
    userFields: null,
    inviteImageUrl: getUrl("/images/envelope.svg"),
    isInviteLink: readOnly("model.is_invite_link"),
    submitDisabled: or(
      "emailValidation.failed",
      "usernameValidation.failed",
      "passwordValidation.failed",
      "nameValidation.failed",
      "userFieldsValidation.failed"
    ),
    rejectedEmails: null,

    init() {
      this._super(...arguments);

      this.rejectedEmails = [];
    },

    @discourseComputed
    welcomeTitle() {
      return I18n.t("invites.welcome_to", {
        site_name: this.siteSettings.title
      });
    },

    @discourseComputed("email")
    yourEmailMessage(email) {
      return I18n.t("invites.your_email", { email: email });
    },

    @discourseComputed
    externalAuthsEnabled() {
      return findLoginMethods().length > 0;
    },

    @discourseComputed
    fullnameRequired() {
      return (
        this.siteSettings.full_name_required || this.siteSettings.enable_names
      );
    },

    @discourseComputed("email", "rejectedEmails.[]")
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

    actions: {
      submit() {
        const userFields = this.userFields;
        let userCustomFields = {};
        if (!isEmpty(userFields)) {
          userFields.forEach(function(f) {
            userCustomFields[f.get("field.id")] = f.get("value");
          });
        }

        ajax({
          url: `/invites/show/${this.get("model.token")}.json`,
          type: "PUT",
          data: {
            email: this.email,
            username: this.accountUsername,
            name: this.accountName,
            password: this.accountPassword,
            user_custom_fields: userCustomFields,
            timezone: moment.tz.guess()
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
