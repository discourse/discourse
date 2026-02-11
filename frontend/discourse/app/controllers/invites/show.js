import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import EmberObject, { action, computed } from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import { alias, bool, not, readOnly } from "@ember/object/computed";
import { isEmpty } from "@ember/utils";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import getUrl from "discourse/lib/get-url";
import NameValidationHelper from "discourse/lib/name-validation-helper";
import PasswordValidationHelper from "discourse/lib/password-validation-helper";
import { trackedArray } from "discourse/lib/tracked-tools";
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
  @trackedArray rejectedEmails = [];

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
    getUserFields: () =>
      this.site.get("user_fields")?.filter((f) => f.show_on_signup),
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

  @computed
  get discourseConnectEnabled() {
    return this.siteSettings.enable_discourse_connect;
  }

  @computed
  get welcomeTitle() {
    return i18n("invites.welcome_to", {
      site_name: this.siteSettings.title,
    });
  }

  @computed("email")
  get yourEmailMessage() {
    return i18n("invites.your_email", { email: this.email });
  }

  @computed
  get externalAuthsEnabled() {
    return findLoginMethods().length > 0;
  }

  @computed
  get externalAuthsOnly() {
    return (
      !this.siteSettings.enable_local_logins &&
      !this.siteSettings.enable_discourse_connect &&
      this.externalAuthsEnabled
    );
  }

  @computed("existingUserId")
  get showWelcomeHeader() {
    return !this.existingUserId;
  }

  @computed("externalAuthsOnly", "discourseConnectEnabled")
  get showSignupProgressBar() {
    return !(this.externalAuthsOnly || this.discourseConnectEnabled);
  }

  @computed(
    "emailValidation.failed",
    "usernameValidation.failed",
    "passwordValidation.failed",
    "nameValidation.failed",
    "userFieldsValidation.failed",
    "existingUserRedeeming",
    "existingUserCanRedeem"
  )
  get submitDisabled() {
    if (this.existingUserRedeeming) {
      return !this.existingUserCanRedeem;
    }

    return (
      this.emailValidation?.failed ||
      this.usernameValidation?.failed ||
      this.passwordValidation?.failed ||
      this.nameValidation?.failed ||
      this.userFieldsValidation?.failed
    );
  }

  @computed(
    "externalAuthsEnabled",
    "externalAuthsOnly",
    "discourseConnectEnabled"
  )
  get showSocialLoginAvailable() {
    return (
      this.externalAuthsEnabled &&
      !this.externalAuthsOnly &&
      !this.discourseConnectEnabled
    );
  }

  @computed(
    "externalAuthsOnly",
    "authOptions",
    "emailValidation.failed",
    "existingUserRedeeming"
  )
  get shouldDisplayForm() {
    return (
      (this.siteSettings.enable_local_logins ||
        (this.externalAuthsOnly &&
          this.authOptions &&
          !this.emailValidation?.failed)) &&
      !this.siteSettings.enable_discourse_connect &&
      !this.existingUserRedeeming
    );
  }

  @computed
  get showFullname() {
    return this.site.full_name_visible_in_signup;
  }

  @computed
  get fullnameRequired() {
    return this.site.full_name_required_for_signup;
  }

  @computed(
    "email",
    "rejectedEmails.[]",
    "authOptions.email",
    "authOptions.email_valid",
    "hiddenEmail",
    "emailVerifiedByLink",
    "differentExternalEmail"
  )
  get emailValidation() {
    if (this.hiddenEmail && !this.differentExternalEmail) {
      return EmberObject.create({
        ok: true,
        reason: i18n("user.email.ok"),
      });
    }

    // If blank, fail without a reason
    if (isEmpty(this.email)) {
      return EmberObject.create({
        failed: true,
      });
    }

    if (this.rejectedEmails?.includes(this.email)) {
      return EmberObject.create({
        failed: true,
        reason: i18n("user.email.invalid"),
      });
    }

    if (this.authOptions?.email && this.authOptions?.email_valid) {
      const provider = this.authProviderDisplayName(
        this.get("authOptions.auth_provider")
      );

      if (this.authOptions?.email === this.email) {
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

    if (this.emailVerifiedByLink) {
      return EmberObject.create({
        ok: true,
        reason: i18n("user.email.authenticated_by_invite"),
      });
    }

    if (emailValid(this.email)) {
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

  @computed
  get ssoPath() {
    return getUrl("/session/sso");
  }

  @computed
  get disclaimerHtml() {
    if (this.site.tos_url && this.site.privacy_policy_url) {
      return i18n("create_account.disclaimer", {
        tos_link: this.site.tos_url,
        privacy_link: this.site.privacy_policy_url,
      });
    }
  }

  @computed("authOptions.associate_url", "authOptions.auth_provider")
  get associateHtml() {
    if (!this.authOptions?.associate_url) {
      return;
    }
    return i18n("create_account.associate", {
      associate_link: this.authOptions?.associate_url,
      provider: i18n(`login.${this.authOptions?.auth_provider}.name`),
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
            this.rejectedEmails.push(result.values.email);
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
