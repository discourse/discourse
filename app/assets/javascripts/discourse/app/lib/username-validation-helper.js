import { tracked } from "@glimmer/tracking";
import EmberObject from "@ember/object";
import { isEmpty } from "@ember/utils";
import { task, timeout } from "ember-concurrency";
import User from "discourse/models/user";
import { i18n } from "discourse-i18n";

const DEBOUNCE_MS = 500;

function failedResult(attrs) {
  return EmberObject.create({
    shouldCheck: false,
    failed: true,
    ok: false,
    element: document.querySelector("#new-account-username"),
    ...attrs,
  });
}

function validResult(attrs) {
  return EmberObject.create({ ok: true, ...attrs });
}

export default class UsernameValidationHelper {
  @tracked usernameValidationResult;
  checkedUsername = null;

  constructor(owner) {
    this.owner = owner;
  }

  @task({ restartable: true })
  *fetchExistingUsername() {
    yield timeout(DEBOUNCE_MS);

    const result = yield User.checkUsername(null, this.owner.accountEmail);

    if (
      result.suggestion &&
      (isEmpty(this.owner.accountUsername) ||
        this.owner.accountUsername === this.owner.get("authOptions.username"))
    ) {
      this.owner.accountUsername = result.suggestion;
      this.owner.prefilledUsername = result.suggestion;
    }
  }

  @task({ restartable: true })
  *_checkUsernameAvailability() {
    yield timeout(DEBOUNCE_MS);

    const result = yield User.checkUsername(
      this.owner.accountUsername,
      this.owner.accountEmail
    );

    this.checkedUsername = this.owner.accountUsername;
    this.owner.isDeveloper = !!result.is_developer;

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

  get usernameValidation() {
    if (
      this.usernameValidationResult &&
      this.checkedUsername === this.owner.accountUsername
    ) {
      return this.usernameValidationResult;
    }

    const result = this.basicUsernameValidation(this.owner.accountUsername);

    if (result.shouldCheck) {
      this._checkUsernameAvailability.perform();
    }

    return result;
  }

  basicUsernameValidation(username) {
    if (username && username === this.owner.prefilledUsername) {
      return validResult({ reason: i18n("user.username.prefilled") });
    }

    if (isEmpty(username)) {
      return failedResult({
        message: i18n("user.username.required"),
        reason: this.owner.forceValidationReason
          ? i18n("user.username.required")
          : null,
      });
    }

    if (username.length < this.owner.siteSettings.min_username_length) {
      return failedResult({ reason: i18n("user.username.too_short") });
    }

    if (username.length > this.owner.siteSettings.max_username_length) {
      return failedResult({ reason: i18n("user.username.too_long") });
    }

    return failedResult({
      shouldCheck: true,
      reason: i18n("user.username.checking"),
    });
  }
}
