import EmberObject from "@ember/object";
import I18n from "I18n";
import Mixin from "@ember/object/mixin";
import User from "discourse/models/user";
import discourseDebounce from "discourse-common/lib/debounce";
import { isEmpty } from "@ember/utils";
import { observes } from "discourse-common/utils/decorators";
import { setting } from "discourse/lib/computed";

function failedResult(attrs) {
  let result = EmberObject.create({
    shouldCheck: false,
    failed: true,
    ok: false,
    element: document.querySelector("#new-account-username"),
  });
  result.setProperties(attrs);
  return result;
}

function validResult(attrs) {
  let result = EmberObject.create({ ok: true });
  result.setProperties(attrs);
  return result;
}

export default Mixin.create({
  uniqueUsernameValidation: null,
  maxUsernameLength: setting("max_username_length"),
  minUsernameLength: setting("min_username_length"),

  fetchExistingUsername() {
    User.checkUsername(null, this.accountEmail).then((result) => {
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
    });
  },

  @observes("accountUsername")
  triggerValidation() {
    let { accountUsername } = this;

    let result = this.basicUsernameValidation(accountUsername);
    if (result.shouldCheck) {
      discourseDebounce(this, this.checkUsernameAvailability, 500);
    }
    this.set("usernameValidation", result);
  },

  basicUsernameValidation(username) {
    if (username && username === this.prefilledUsername) {
      return validResult({ reason: I18n.t("user.username.prefilled") });
    }

    if (isEmpty(username)) {
      return failedResult({
        message: I18n.t("user.username.required"),
        reason: this.forceValidationReason
          ? I18n.t("user.username.required")
          : null,
      });
    }

    if (username.length < this.siteSettings.min_username_length) {
      return failedResult({ reason: I18n.t("user.username.too_short") });
    }

    if (username.length > this.maxUsernameLength) {
      return failedResult({ reason: I18n.t("user.username.too_long") });
    }

    return failedResult({
      shouldCheck: true,
      reason: I18n.t("user.username.checking"),
    });
  },

  checkUsernameAvailability() {
    return User.checkUsername(this.accountUsername, this.accountEmail).then(
      (result) => {
        if (this.isDestroying || this.isDestroyed) {
          return;
        }

        this.set("isDeveloper", false);
        if (result.available) {
          if (result.is_developer) {
            this.set("isDeveloper", true);
          }
          return this.set(
            "usernameValidation",
            validResult({ reason: I18n.t("user.username.available") })
          );
        } else {
          if (result.suggestion) {
            return this.set(
              "usernameValidation",
              failedResult({
                reason: I18n.t("user.username.not_available", result),
              })
            );
          } else {
            return this.set(
              "usernameValidation",
              failedResult({
                reason: result.errors
                  ? result.errors.join(" ")
                  : I18n.t("user.username.not_available_no_suggestion"),
              })
            );
          }
        }
      }
    );
  },
});
