import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import EmberObject, { action } from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import { alias, bool, not, readOnly } from "@ember/object/computed";
import { isEmpty } from "@ember/utils";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import discourseComputed from "discourse/lib/decorators";
import getUrl from "discourse/lib/get-url";
import NameValidationHelper from "discourse/lib/name-validation-helper";
import PasswordValidationHelper from "discourse/lib/password-validation-helper";
import DiscourseURL from "discourse/lib/url";
import UserFieldsValidationHelper from "discourse/lib/user-fields-validation-helper";
import UsernameValidationHelper from "discourse/lib/username-validation-helper";
import { emailValid } from "discourse/lib/utilities";
import { findAll as findLoginMethods } from "discourse/models/login-method";
import { i18n } from "discourse-i18n";

export default class InvitesShowController extends Controller {
  @tracked accountPassword;
  @tracked accountUsername;
  @tracked isDeveloper;
  queryParams = ["t"];
  nameValidationHelper = new NameValidationHelper(this);
  usernameValidationHelper = new UsernameValidationHelper({
    getAccountEmail: () => this.accountEmail,
    getAccountUsername: () => this.accountUsername,
    getPrefilledUsername: () => this.prefilledUsername,
    getAuthOptionsUsername: () => this.authOptions?.username,
    getForceValidationReason: () => this.forceValidationReason,
    siteSettings: this.siteSettings,
    isInvalid: () => this.isDestroying || this.isDestroyed,
    updateIsDeveloper: (isDeveloper) => (this.isDeveloper = isDeveloper),
    updateUsernames: (username) => {
      this.accountUsername = username;
      this.prefilledUsername = username;
    },
  });
  passwordValidationHelper = new PasswordValidationHelper(this);
  userFieldsValidationHelper = new UserFieldsValidationHelper({
    getUserFields: () => this.site.get("user_fields"),
    getAccountPassword: () => this.accountPassword,
  });
  successMessage = null;
  @readOnly("model.is_invite_link") isInviteLink;
  @readOnly("model.invited_by") invitedBy;
  @alias("model.email") email;
  @alias("email") accountEmail;
  @readOnly("model.existing_user_id") existingUserId;
  @readOnly("model.existing_user_can_redeem") existingUserCanRedeem;
  @readOnly("model.existing_user_can_redeem_error") existingUserCanRedeemError;
  @bool("existingUserId") existingUserRedeeming;
  @alias("model.hidden_email") hiddenEmail;
  @alias("model.email_verified_by_link") emailVerifiedByLink;
  @alias("model.different_external_email") differentExternalEmail;
  @not("externalAuthsOnly") passwordRequired;
  errorMessage = null;
  authOptions = null;
  rejectedEmails = [];
  maskPassword = true;

  get userFields() {
    return this.userFieldsValidationHelper.userFields;
  }

  @dependentKeyCompat
  get userFieldsValidation() {
    return this.userFieldsValidationHelper.userFieldsValidation;
  }

  @action
  setAccountUsername(event) {
    this.accountUsername = event.target.value;
  }

  @dependentKeyCompat
  get usernameValidation() {
    return this.usernameValidationHelper.usernameValidation;
  }

  get nameTitle() {
    return this.nameValidationHelper.nameTitle;
  }

  @dependentKeyCompat
  get nameValidation() {
    return this.nameValidationHelper.nameValidation;
  }

  @dependentKeyCompat
  get passwordValidation() {
    return this.passwordValidationHelper.passwordValidation;
  }

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
  }

  @discourseComputed
  discourseConnectEnabled() {
    return this.siteSettings.enable_discourse_connect;
  }

  @discourseComputed
  welcomeTitle() {
    return i18n("invites.welcome_to", {
      site_name: this.siteSettings.title,
    });
  }

  @discourseComputed("email")
  yourEmailMessage(email) {
    return i18n("invites.your_email", { email });
  }

  @discourseComputed
  externalAuthsEnabled() {
    return findLoginMethods().length > 0;
  }

  @discourseComputed
  externalAuthsOnly() {
    return (
      !this.siteSettings.enable_local_logins &&
      this.externalAuthsEnabled &&
      !this.siteSettings.enable_discourse_connect
    );
  }

  @discourseComputed(
    "emailValidation.failed",
    "usernameValidation.failed",
    "passwordValidation.failed",
    "nameValidation.failed",
    "userFieldsValidation.failed",
    "existingUserRedeeming",
    "existingUserCanRedeem"
  )
  submitDisabled(
    emailValidationFailed,
    usernameValidationFailed,
    passwordValidationFailed,
    nameValidationFailed,
    userFieldsValidationFailed,
    existingUserRedeeming,
    existingUserCanRedeem
  ) {
    if (existingUserRedeeming) {
      return !existingUserCanRedeem;
    }

    return (
      emailValidationFailed ||
      usernameValidationFailed ||
      passwordValidationFailed ||
      nameValidationFailed ||
      userFieldsValidationFailed
    );
  }

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
  }

  @discourseComputed(
    "externalAuthsOnly",
    "authOptions",
    "emailValidation.failed",
    "existingUserRedeeming"
  )
  shouldDisplayForm(
    externalAuthsOnly,
    authOptions,
    emailValidationFailed,
    existingUserRedeeming
  ) {
    return (
      (this.siteSettings.enable_local_logins ||
        (externalAuthsOnly && authOptions && !emailValidationFailed)) &&
      !this.siteSettings.enable_discourse_connect &&
      !existingUserRedeeming
    );
  }

  @discourseComputed
  showFullname() {
    return this.site.full_name_visible_in_signup;
  }

  @discourseComputed
  fullnameRequired() {
    return this.site.full_name_required_for_signup;
  }

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
        reason: i18n("user.email.ok"),
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
        reason: i18n("user.email.invalid"),
      });
    }

    if (externalAuthEmail && externalAuthEmailValid) {
      const provider = this.authProviderDisplayName(
        this.get("authOptions.auth_provider")
      );

      if (externalAuthEmail === email) {
        return EmberObject.create({
          ok: true,
          reason: i18n("user.email.authenticated", {
            provider,
          }),
        });
      } else {
        return EmberObject.create({
          failed: true,
          reason: i18n("user.email.invite_auth_email_invalid", {
            provider,
          }),
        });
      }
    }

    if (emailVerifiedByLink) {
      return EmberObject.create({
        ok: true,
        reason: i18n("user.email.authenticated_by_invite"),
      });
    }

    if (emailValid(email)) {
      return EmberObject.create({
        ok: true,
        reason: i18n("user.email.ok"),
      });
    }

    return EmberObject.create({
      failed: true,
      reason: i18n("user.email.invalid"),
    });
  }

  authProviderDisplayName(providerName) {
    const matchingProvider = findLoginMethods().find((provider) => {
      return provider.name === providerName;
    });
    return matchingProvider ? matchingProvider.get("prettyName") : providerName;
  }

  @discourseComputed
  ssoPath() {
    return getUrl("/session/sso");
  }

  @discourseComputed
  disclaimerHtml() {
    if (this.site.tos_url && this.site.privacy_policy_url) {
      return i18n("create_account.disclaimer", {
        tos_link: this.site.tos_url,
        privacy_link: this.site.privacy_policy_url,
      });
    }
  }

  @discourseComputed("authOptions.associate_url", "authOptions.auth_provider")
  associateHtml(url, provider) {
    if (!url) {
      return;
    }
    return i18n("create_account.associate", {
      associate_link: url,
      provider: i18n(`login.${provider}.name`),
    });
  }

  @action
  togglePasswordMask() {
    this.toggleProperty("maskPassword");
  }

  @action
  scrollInputIntoView(event) {
    event.target.scrollIntoView({
      behavior: "smooth",
      block: "center",
    });
  }

  @action
  submit() {
    let userCustomFields = {};
    if (!isEmpty(this.userFields)) {
      this.userFields.forEach(function (f) {
        userCustomFields[f.field.id] = f.value;
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
          this.set("successMessage", result.message || i18n("invites.success"));
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
          if (result.errors?.["user_password.password"]?.length > 0) {
            this.passwordValidationHelper.rejectedPasswords.push(
              this.accountPassword
            );
            this.passwordValidationHelper.rejectedPasswordsMessages.set(
              this.accountPassword,
              result.errors["user_password.password"][0]
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
  }

  @action
  externalLogin(provider) {
    provider.doLogin({
      signup: true,
      params: {
        origin: window.location.href,
      },
    });
  }
}
