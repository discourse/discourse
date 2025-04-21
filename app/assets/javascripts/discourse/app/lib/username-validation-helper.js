import { tracked } from "@glimmer/tracking";
import { isEmpty } from "@ember/utils";
import discourseDebounce from "discourse/lib/debounce";
import User from "discourse/models/user";
import { i18n } from "discourse-i18n";

function failedResult(attrs) {
  return {
    shouldCheck: false,
    failed: true,
    ok: false,
    element: document.querySelector("#new-account-username"),
    ...attrs,
  };
}

function validResult(attrs) {
  return { ok: true, ...attrs };
}

export default class UsernameValidationHelper {
  @tracked usernameValidationResult;
  checkedUsername = null;

  constructor({
    getAccountEmail,
    getAccountUsername,
    getPrefilledUsername,
    getAuthOptionsUsername,
    getForceValidationReason,
    siteSettings,
    isInvalid,
    updateIsDeveloper,
    updateUsernames,
  }) {
    this.getAccountEmail = getAccountEmail;
    this.getAccountUsername = getAccountUsername;
    this.getPrefilledUsername = getPrefilledUsername;
    this.getAuthOptionsUsername = getAuthOptionsUsername;
    this.getForceValidationReason = getForceValidationReason;
    this.siteSettings = siteSettings;
    this.isInvalid = isInvalid;
    this.updateIsDeveloper = updateIsDeveloper;
    this.updateUsernames = updateUsernames;
  }

  async fetchExistingUsername() {
    const accountUsername = this.getAccountUsername();
    const result = await User.checkUsername(null, this.getAccountEmail());

    if (
      result.suggestion &&
      (isEmpty(accountUsername) ||
        accountUsername === this.getAuthOptionsUsername())
    ) {
      this.updateUsernames(result.suggestion);
    }
  }

  get usernameValidation() {
    const accountUsername = this.getAccountUsername();
    if (
      this.usernameValidationResult &&
      this.checkedUsername === accountUsername
    ) {
      return this.usernameValidationResult;
    }

    const result = this.basicUsernameValidation(accountUsername);

    if (result.shouldCheck) {
      discourseDebounce(this, this.checkUsernameAvailability, 500);
    }

    return result;
  }

  basicUsernameValidation(username) {
    if (username && username === this.getPrefilledUsername()) {
      return validResult({ reason: i18n("user.username.prefilled") });
    }

    if (isEmpty(username)) {
      return failedResult({
        message: i18n("user.username.required"),
        reason: this.getForceValidationReason()
          ? i18n("user.username.required")
          : null,
      });
    }

    if (username.length < this.siteSettings.min_username_length) {
      return failedResult({ reason: i18n("user.username.too_short") });
    }

    if (username.length > this.siteSettings.max_username_length) {
      return failedResult({ reason: i18n("user.username.too_long") });
    }

    return failedResult({
      shouldCheck: true,
      reason: i18n("user.username.checking"),
    });
  }

  async checkUsernameAvailability() {
    const accountUsername = this.getAccountUsername();
    const result = await User.checkUsername(
      accountUsername,
      this.getAccountEmail()
    );

    if (this.isInvalid()) {
      return;
    }

    this.checkedUsername = accountUsername;
    this.updateIsDeveloper(!!result.is_developer);

    if (result.available) {
      this.usernameValidationResult = validResult({
        reason: i18n("user.username.available"),
      });
    } else if (result.suggestion) {
      this.usernameValidationResult = failedResult({
        reason: i18n("user.username.not_available", result),
      });
    } else {
      this.usernameValidationResult = failedResult({
        reason: result.errors
          ? result.errors.join(" ")
          : i18n("user.username.not_available_no_suggestion"),
      });
    }
  }
}
