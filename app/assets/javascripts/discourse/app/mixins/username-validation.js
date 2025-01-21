import EmberObject, { computed } from "@ember/object";
import Mixin from "@ember/object/mixin";
import { isEmpty } from "@ember/utils";
import { setting } from "discourse/lib/computed";
import discourseDebounce from "discourse/lib/debounce";
import User from "discourse/models/user";
import { i18n } from "discourse-i18n";

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

export default Mixin.create({
  checkedUsername: null,
  usernameValidationResult: null,
  uniqueUsernameValidation: null,
  maxUsernameLength: setting("max_username_length"),
  minUsernameLength: setting("min_username_length"),

  async fetchExistingUsername() {
    const result = await User.checkUsername(null, this.accountEmail);

    if (
      result.suggestion &&
      (isEmpty(this.accountUsername) ||
        this.accountUsername === this.get("authOptions.username"))
    ) {
      this.setProperties({
        accountUsername: result.suggestion,
        prefilledUsername: result.suggestion,
      });
    }
  },

  usernameValidation: computed(
    "usernameValidationResult",
    "accountUsername",
    "forceValidationReason",
    function () {
      if (
        this.usernameValidationResult &&
        this.checkedUsername === this.accountUsername
      ) {
        return this.usernameValidationResult;
      }

      const result = this.basicUsernameValidation(this.accountUsername);

      if (result.shouldCheck) {
        discourseDebounce(this, this.checkUsernameAvailability, 500);
      }

      return result;
    }
  ),

  basicUsernameValidation(username) {
    if (username && username === this.prefilledUsername) {
      return validResult({ reason: i18n("user.username.prefilled") });
    }

    if (isEmpty(username)) {
      return failedResult({
        message: i18n("user.username.required"),
        reason: this.forceValidationReason
          ? i18n("user.username.required")
          : null,
      });
    }

    if (username.length < this.siteSettings.min_username_length) {
      return failedResult({ reason: i18n("user.username.too_short") });
    }

    if (username.length > this.maxUsernameLength) {
      return failedResult({ reason: i18n("user.username.too_long") });
    }

    return failedResult({
      shouldCheck: true,
      reason: i18n("user.username.checking"),
    });
  },

  async checkUsernameAvailability() {
    const result = await User.checkUsername(
      this.accountUsername,
      this.accountEmail
    );

    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    this.set("checkedUsername", this.accountUsername);
    this.set("isDeveloper", !!result.is_developer);

    if (result.available) {
      this.set(
        "usernameValidationResult",
        validResult({ reason: i18n("user.username.available") })
      );
    } else if (result.suggestion) {
      this.set(
        "usernameValidationResult",
        failedResult({
          reason: i18n("user.username.not_available", result),
        })
      );
    } else {
      this.set(
        "usernameValidationResult",
        failedResult({
          reason: result.errors
            ? result.errors.join(" ")
            : i18n("user.username.not_available_no_suggestion"),
        })
      );
    }
  },
});
