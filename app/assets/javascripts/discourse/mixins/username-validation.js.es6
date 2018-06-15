import InputValidation from "discourse/models/input-validation";
import debounce from "discourse/lib/debounce";
import { setting } from "discourse/lib/computed";
import { default as computed } from "ember-addons/ember-computed-decorators";

export default Ember.Mixin.create({
  uniqueUsernameValidation: null,

  maxUsernameLength: setting("max_username_length"),
  minUsernameLength: setting("min_username_length"),

  fetchExistingUsername: debounce(function() {
    const self = this;
    Discourse.User.checkUsername(null, this.get("accountEmail")).then(function(
      result
    ) {
      if (
        result.suggestion &&
        (Ember.isEmpty(self.get("accountUsername")) ||
          self.get("accountUsername") === self.get("authOptions.username"))
      ) {
        self.set("accountUsername", result.suggestion);
        self.set("prefilledUsername", result.suggestion);
      }
    });
  }, 500),

  @computed("accountUsername")
  basicUsernameValidation(accountUsername) {
    this.set("uniqueUsernameValidation", null);

    if (accountUsername && accountUsername === this.get("prefilledUsername")) {
      return InputValidation.create({
        ok: true,
        reason: I18n.t("user.username.prefilled")
      });
    }

    // If blank, fail without a reason
    if (Ember.isEmpty(accountUsername)) {
      return InputValidation.create({
        failed: true
      });
    }

    // If too short
    if (accountUsername.length < this.siteSettings.min_username_length) {
      return InputValidation.create({
        failed: true,
        reason: I18n.t("user.username.too_short")
      });
    }

    // If too long
    if (accountUsername.length > this.get("maxUsernameLength")) {
      return InputValidation.create({
        failed: true,
        reason: I18n.t("user.username.too_long")
      });
    }

    this.checkUsernameAvailability();
    // Let's check it out asynchronously
    return InputValidation.create({
      failed: true,
      reason: I18n.t("user.username.checking")
    });
  },

  shouldCheckUsernameAvailability: function() {
    return (
      !Ember.isEmpty(this.get("accountUsername")) &&
      this.get("accountUsername").length >= this.get("minUsernameLength")
    );
  },

  checkUsernameAvailability: debounce(function() {
    if (this.shouldCheckUsernameAvailability()) {
      return Discourse.User.checkUsername(
        this.get("accountUsername"),
        this.get("accountEmail")
      ).then(result => {
        this.set("isDeveloper", false);
        if (result.available) {
          if (result.is_developer) {
            this.set("isDeveloper", true);
          }
          return this.set(
            "uniqueUsernameValidation",
            InputValidation.create({
              ok: true,
              reason: I18n.t("user.username.available")
            })
          );
        } else {
          if (result.suggestion) {
            return this.set(
              "uniqueUsernameValidation",
              InputValidation.create({
                failed: true,
                reason: I18n.t("user.username.not_available", result)
              })
            );
          } else {
            return this.set(
              "uniqueUsernameValidation",
              InputValidation.create({
                failed: true,
                reason: result.errors
                  ? result.errors.join(" ")
                  : I18n.t("user.username.not_available_no_suggestion")
              })
            );
          }
        }
      });
    }
  }, 500),

  // Actually wait for the async name check before we're 100% sure we're good to go
  @computed("uniqueUsernameValidation", "basicUsernameValidation")
  usernameValidation() {
    const basicValidation = this.get("basicUsernameValidation");
    const uniqueUsername = this.get("uniqueUsernameValidation");
    return uniqueUsername ? uniqueUsername : basicValidation;
  }
});
