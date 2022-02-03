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
    queryParams: ["t"],

    createAccount: controller(),

    invitedBy: readOnly("model.invited_by"),
    email: alias("model.email"),
    accountEmail: alias("email"),
    hiddenEmail: alias("model.hidden_email"),
    emailVerifiedByLink: alias("model.email_verified_by_link"),
    differentExternalEmail: alias("model.different_external_email"),
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
    discourseConnectEnabled() {
      return this.siteSettings.enable_discourse_connect;
    },

    @discourseComputed
    welcomeTitle() {
      return I18n.t("invites.welcome_to", {
        site_name: this.siteSettings.title,
      });
    },

    @discourseComputed("email")
    yourEmailMessage(email) {
      return I18n.t("invites.your_email", { email });
    },

    @discourseComputed
    externalAuthsEnabled() {
      return findLoginMethods().length > 0;
    },

    @discourseComputed
    externalAuthsOnly() {
      return (
        !this.siteSettings.enable_local_logins &&
        this.externalAuthsEnabled &&
        !this.siteSettings.enable_discourse_connect
      );
    },

    @discourseComputed(
      "externalAuthsEnabled",
      "externalAuthsOnly",
      "discourseConnectEnabled"
    )
    showSocialLoginAvailable(
      externalAuthsEnabled,
      externalAuthsOnly,
      discourseConnectEnabled
    ) {
      return (
        externalAuthsEnabled && !externalAuthsOnly && !discourseConnectEnabled
      );
    },

    @discourseComputed(
      "externalAuthsOnly",
      "authOptions",
      "emailValidation.failed"
    )
    shouldDisplayForm(externalAuthsOnly, authOptions, emailValidationFailed) {
      return (
        (this.siteSettings.enable_local_logins ||
          (externalAuthsOnly && authOptions && !emailValidationFailed)) &&
        !this.siteSettings.enable_discourse_connect
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
      "authOptions.email_valid",
      "hiddenEmail",
      "emailVerifiedByLink",
      "differentExternalEmail"
    )
    emailValidation(
      email,
      rejectedEmails,
      externalAuthEmail,
      externalAuthEmailValid,
      hiddenEmail,
      emailVerifiedByLink,
      differentExternalEmail
    ) {
      if (hiddenEmail && !differentExternalEmail) {
        return EmberObject.create({
          ok: true,
          reason: I18n.t("user.email.ok"),
        });
      }

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

      if (externalAuthEmail && externalAuthEmailValid) {
        const provider = this.createAccount.authProviderDisplayName(
          this.get("authOptions.auth_provider")
        );

        if (externalAuthEmail === email) {
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

      if (emailVerifiedByLink) {
        return EmberObject.create({
          ok: true,
          reason: I18n.t("user.email.authenticated_by_invite"),
        });
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

    @discourseComputed
    ssoPath: () => getUrl("/session/sso"),

    @discourseComputed("authOptions.associate_url", "authOptions.auth_provider")
    associateHtml(url, provider) {
      if (!url) {
        return;
      }
      return I18n.t("create_account.associate", {
        associate_link: url,
        provider: I18n.t(`login.${provider}.name`),
      });
    },

    actions: {
      submit() {
        const userFields = this.userFields;
        let userCustomFields = {};
        if (!isEmpty(userFields)) {
          userFields.forEach(function (f) {
            userCustomFields[f.get("field.id")] = f.get("value");
          });
        }

        const data = {
          username: this.accountUsername,
          name: this.accountName,
          password: this.accountPassword,
          user_custom_fields: userCustomFields,
          timezone: moment.tz.guess(),
        };

        if (this.isInviteLink) {
          data.email = this.email;
        } else {
          data.email_token = this.t;
        }

        ajax({
          url: `/invites/show/${this.get("model.token")}.json`,
          type: "PUT",
          data,
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
          signup: true,
          params: {
            origin: window.location.href,
          },
        });
      },
    },
  }
);
