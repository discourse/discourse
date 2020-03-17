import discourseComputed from "discourse-common/utils/decorators";
import { empty, or } from "@ember/object/computed";
import Controller from "@ember/controller";
import { propertyEqual } from "discourse/lib/computed";
import EmberObject from "@ember/object";
import { emailValid } from "discourse/lib/utilities";

export default Controller.extend({
  taken: false,
  saving: false,
  error: false,
  success: false,
  newEmail: null,

  newEmailEmpty: empty("newEmail"),

  saveDisabled: or(
    "saving",
    "newEmailEmpty",
    "taken",
    "unchanged",
    "invalidEmail"
  ),

  unchanged: propertyEqual("newEmailLower", "currentUser.email"),

  @discourseComputed("newEmail")
  newEmailLower(newEmail) {
    return newEmail.toLowerCase().trim();
  },

  @discourseComputed("saving")
  saveButtonText(saving) {
    if (saving) return I18n.t("saving");
    return I18n.t("user.change");
  },

  @discourseComputed("newEmail")
  invalidEmail(newEmail) {
    return !emailValid(newEmail);
  },

  @discourseComputed("invalidEmail")
  emailValidation(invalidEmail) {
    if (invalidEmail) {
      return EmberObject.create({
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
