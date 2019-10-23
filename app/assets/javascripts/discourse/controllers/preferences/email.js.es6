import Controller from "@ember/controller";
import { propertyEqual } from "discourse/lib/computed";
import InputValidation from "discourse/models/input-validation";
import { emailValid } from "discourse/lib/utilities";
import computed from "ember-addons/ember-computed-decorators";

export default Controller.extend({
  taken: false,
  saving: false,
  error: false,
  success: false,
  newEmail: null,

  newEmailEmpty: Ember.computed.empty("newEmail"),

  saveDisabled: Ember.computed.or(
    "saving",
    "newEmailEmpty",
    "taken",
    "unchanged",
    "invalidEmail"
  ),

  unchanged: propertyEqual("newEmailLower", "currentUser.email"),

  @computed("newEmail")
  newEmailLower(newEmail) {
    return newEmail.toLowerCase().trim();
  },

  @computed("saving")
  saveButtonText(saving) {
    if (saving) return I18n.t("saving");
    return I18n.t("user.change");
  },

  @computed("newEmail")
  invalidEmail(newEmail) {
    return !emailValid(newEmail);
  },

  @computed("invalidEmail")
  emailValidation(invalidEmail) {
    if (invalidEmail) {
      return InputValidation.create({
        failed: true,
        reason: I18n.t("user.email.invalid")
      });
    }
  },

  reset() {
    this.setProperties({
      taken: false,
      saving: false,
      error: false,
      success: false,
      newEmail: null
    });
  },

  actions: {
    changeEmail() {
      this.set("saving", true);

      return this.model.changeEmail(this.newEmail).then(
        () => this.set("success", true),
        e => {
          this.setProperties({ error: true, saving: false });
          if (
            e.jqXHR.responseJSON &&
            e.jqXHR.responseJSON.errors &&
            e.jqXHR.responseJSON.errors[0]
          ) {
            this.set("errorMessage", e.jqXHR.responseJSON.errors[0]);
          } else {
            this.set("errorMessage", I18n.t("user.change_email.error"));
          }
        }
      );
    }
  }
});
