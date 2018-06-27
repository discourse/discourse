import { default as computed } from "ember-addons/ember-computed-decorators";
import getUrl from "discourse-common/lib/get-url";
import DiscourseURL from "discourse/lib/url";
import { ajax } from "discourse/lib/ajax";
import PasswordValidation from "discourse/mixins/password-validation";
import { userPath } from "discourse/lib/url";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";

export default Ember.Controller.extend(PasswordValidation, {
  isDeveloper: Ember.computed.alias("model.is_developer"),
  admin: Ember.computed.alias("model.admin"),
  secondFactorRequired: Ember.computed.alias("model.second_factor_required"),
  backupEnabled: Ember.computed.alias("model.second_factor_backup_enabled"),
  secondFactorMethod: SECOND_FACTOR_METHODS.TOTP,
  passwordRequired: true,
  errorMessage: null,
  successMessage: null,
  requiresApproval: false,
  redirected: false,

  @computed()
  continueButtonText() {
    return I18n.t("password_reset.continue", {
      site_name: this.siteSettings.title
    });
  },

  @computed("redirectTo")
  redirectHref(redirectTo) {
    return Discourse.getURL(redirectTo || "/");
  },

  lockImageUrl: getUrl("/images/lock.svg"),

  actions: {
    submit() {
      ajax({
        url: userPath(`password-reset/${this.get("model.token")}.json`),
        type: "PUT",
        data: {
          password: this.get("accountPassword"),
          second_factor_token: this.get("secondFactor"),
          second_factor_method: this.get("secondFactorMethod")
        }
      })
        .then(result => {
          if (result.success) {
            this.set("successMessage", result.message);
            this.set("redirectTo", result.redirect_to);
            if (result.requires_approval) {
              this.set("requiresApproval", true);
            } else {
              this.set("redirected", true);
              DiscourseURL.redirectTo(result.redirect_to || "/");
            }
          } else {
            if (result.errors && result.errors.user_second_factors) {
              this.setProperties({
                secondFactorRequired: true,
                password: null,
                errorMessage: result.message
              });
            } else if (this.get("secondFactorRequired")) {
              this.setProperties({
                secondFactorRequired: false,
                errorMessage: null
              });
            } else if (
              result.errors &&
              result.errors.password &&
              result.errors.password.length > 0
            ) {
              this.get("rejectedPasswords").pushObject(
                this.get("accountPassword")
              );
              this.get("rejectedPasswordsMessages").set(
                this.get("accountPassword"),
                result.errors.password[0]
              );
            }

            if (result.message) {
              this.set("errorMessage", result.message);
            }
          }
        })
        .catch(error => {
          throw new Error(error);
        });
    },

    done() {
      this.set("redirected", true);
      DiscourseURL.redirectTo(this.get("redirectTo") || "/");
    }
  }
});
