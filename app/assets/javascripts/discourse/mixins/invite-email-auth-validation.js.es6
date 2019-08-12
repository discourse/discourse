import InputValidation from "discourse/models/input-validation";
import { default as computed } from "ember-addons/ember-computed-decorators";

export default Ember.Mixin.create({
  @computed()
  nameInstructions() {
    "";
  },

  // Validate the name.
  @computed(
    "accountEmail",
    "authOptions.email",
    "authOptions.email_valid",
    "authOptions.auth_provider"
  )
  inviteEmailAuthValidation() {
    if (
      !this.siteSettings.enable_invite_only_oauth ||
      (this.siteSettings.enable_invite_only_oauth &&
        this.get("authOptions.email") === this.email &&
        this.get("authOptions.email_valid"))
    ) {
      return InputValidation.create({
        ok: true,
        reason: I18n.t("user.email.authenticated", {
          provider: this.authProviderDisplayName(
            this.get("authOptions.auth_provider")
          )
        })
      });
    }

    return InputValidation.create({
      failed: true,
      reason: I18n.t("user.email.invite_email_auth_invalid", {
        provider: this.authProviderDisplayName(
          this.get("authOptions.auth_provider")
        )
      })
    });
  }
});
