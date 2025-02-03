import { cached } from "@glimmer/tracking";
import { isEmpty } from "@ember/utils";
import { TrackedAsyncData } from "ember-async-data";
import { debouncePromise } from "discourse/lib/debounce";
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
  #debounceKey = Symbol();

  constructor(owner) {
    this.owner = owner;
  }

  async fetchExistingUsername() {
    const result = await User.checkUsername(null, this.owner.accountEmail);

    if (
      result.suggestion &&
      (isEmpty(this.owner.accountUsername) ||
        this.owner.accountUsername === this.owner.get("authOptions.username"))
    ) {
      this.owner.accountUsername = result.suggestion;
      this.owner.prefilledUsername = result.suggestion;
    }
  }

  get usernameValidation() {
    const basicCheck = this.basicUsernameValidation(this.owner.accountUsername);

    if (basicCheck.shouldCheck) {
      const remoteCheck = this.checkUsernameAvailabilityPromise;
      if (remoteCheck.isResolved) {
        return remoteCheck.value;
      }
    }

    return basicCheck;
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

  async checkUsernameAvailability() {
    // Accessing these before the debounce, so that they entangle with the tracked state
    const username = this.owner.accountUsername;
    const email = this.owner.accountEmail;

    await debouncePromise(this.#debounceKey, 500);

    const result = await User.checkUsername(username, email);

    if (this.owner.isDestroying || this.owner.isDestroyed) {
      return;
    }

    this.owner.isDeveloper = !!result.is_developer;

    if (result.available) {
      return validResult({
        reason: i18n("user.username.available"),
      });
    } else if (result.suggestion) {
      return failedResult({
        reason: i18n("user.username.not_available", result),
      });
    } else {
      return failedResult({
        reason: result.errors
          ? result.errors.join(" ")
          : i18n("user.username.not_available_no_suggestion"),
      });
    }
  }

  @cached
  get checkUsernameAvailabilityPromise() {
    return new TrackedAsyncData(this.checkUsernameAvailability());
  }
}
