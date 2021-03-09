import { alias, notEmpty, or, readOnly } from "@ember/object/computed";
import Controller, { inject as controller } from "@ember/controller";
import DiscourseURL from "discourse/lib/url";
import EmberObject from "@ember/object";
import I18n from "I18n";
import NameValidation from "discourse/mixins/name-validation";
import PasswordValidation from "discourse/mixins/password-validation";
import UserFieldsValidation from "discourse/mixins/user-fields-validation";
import UsernameValidation from "discourse/mixins/username-validation";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import discourseComputed from "discourse-common/utils/decorators";
import { emailValid } from "discourse/lib/utilities";
import { findAll as findLoginMethods } from "discourse/models/login-method";
import getUrl from "discourse-common/lib/get-url";
import { isEmpty } from "@ember/utils";
import { wavingHandURL } from "discourse/lib/waving-hand-url";

export default Controller.extend(
  PasswordValidation,
  UsernameValidation,
  NameValidation,
  UserFieldsValidation,
  {
    createAccount: controller(),

    invitedBy: readOnly("model.invited_by"),
    email: alias("model.email"),
    accountUsername: alias("model.username"),
    passwordRequired: notEmpty("accountPassword"),
    successMessage: null,
    errorMessage: null,
    userFields: null,
    authOptions: null,
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

    authenticationComplete(options) {
      const props = {
        accountUsername: options.username,
        accountName: options.name,
        authOptions: EmberObject.create(options),
      };

      if (this.isInviteLink) {
        props.email = options.email;
      }

      this.setProperties(props);
    },

    @discourseComputed
    welcomeTitle() {
      return I18n.t("invites.welcome_to", {
        site_name: this.siteSettings.title,
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
    externalAuthsOnly() {
      return (
        !this.siteSettings.enable_local_logins && this.externalAuthsEnabled
      );
    },

    @discourseComputed(
      "externalAuthsOnly",
      "authOptions",
      "emailValidation.failed"
    )
    shouldDisplayForm(externalAuthsOnly, authOptions, emailValidationFailed) {
      return (
        this.siteSettings.enable_local_logins ||
        (externalAuthsOnly && authOptions && !emailValidationFailed)
      );
    },

    @discourseComputed
    fullnameRequired() {
      return (
        this.siteSettings.full_name_required || this.siteSettings.enable_names
      );
    },

    @discourseComputed(
      "email",
      "rejectedEmails.[]",
      "authOptions.email",
      "authOptions.email_valid"
    )
    emailValidation(
      email,
      rejectedEmails,
      externalAuthEmail,
      externalAuthEmailValid
    ) {
      // If blank, fail without a reason
      if (isEmpty(email)) {
        return EmberObject.create({
          failed: true,
        });
      }

      if (rejectedEmails.includes(email)) {
        return EmberObject.create({
          failed: true,
          reason: I18n.t("user.email.invalid"),
        });
      }

      if (externalAuthEmail) {
        const provider = this.createAccount.authProviderDisplayName(
          this.get("authOptions.auth_provider")
        );

        if (externalAuthEmail === email && externalAuthEmailValid) {
          return EmberObject.create({
            ok: true,
            reason: I18n.t("user.email.authenticated", {
              provider,
            }),
          });
        } else {
          return EmberObject.create({
            failed: true,
            reason: I18n.t("user.email.invite_auth_email_invalid", {
              provider,
            }),
          });
        }
      }

      if (emailValid(email)) {
        return EmberObject.create({
          ok: true,
          reason: I18n.t("user.email.ok"),
        });
      }

      return EmberObject.create({
        failed: true,
        reason: I18n.t("user.email.invalid"),
      });
    },

    @discourseComputed
    wavingHandURL: () => wavingHandURL(),

    actions: {
      submit() {
        const userFields = this.userFields;
        let userCustomFields = {};
        if (!isEmpty(userFields)) {
          userFields.forEach(function (f) {
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
            timezone: moment.tz.guess(),
          },
        })
          .then((result) => {
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
          .catch((error) => {
            this.set("errorMessage", extractError(error));
          });
      },

      externalLogin(provider) {
        provider.doLogin({
          params: {
            origin: window.location.href,
          },
        });
      },
    },
  }
);
