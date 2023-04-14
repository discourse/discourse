import { empty, or } from "@ember/object/computed";
import Controller from "@ember/controller";
import EmberObject from "@ember/object";
import I18n from "I18n";
import discourseComputed from "discourse-common/utils/decorators";
import { emailValid } from "discourse/lib/utilities";
import { propertyEqual } from "discourse/lib/computed";

export default Controller.extend({
  queryParams: ["new"],

  taken: false,
  saving: false,
  error: false,
  success: false,
  oldEmail: null,
  newEmail: null,
  successMessage: null,

  newEmailEmpty: empty("newEmail"),

  saveDisabled: or(
    "saving",
    "newEmailEmpty",
    "taken",
    "unchanged",
    "invalidEmail"
  ),

  unchanged: propertyEqual("newEmailLower", "oldEmail"),

  @discourseComputed("newEmail")
  newEmailLower(newEmail) {
    return newEmail.toLowerCase().trim();
  },

  @discourseComputed("saving", "new")
  saveButtonText(saving, isNew) {
    if (saving) {
      return I18n.t("saving");
    }
    if (isNew) {
      return I18n.t("user.add_email.add");
    }
    return I18n.t("user.change");
  },

  @discourseComputed("newEmail")
  invalidEmail(newEmail) {
    return !emailValid(newEmail);
  },

  @discourseComputed("invalidEmail", "oldEmail", "newEmail")
  emailValidation(invalidEmail, oldEmail, newEmail) {
    if (invalidEmail && (oldEmail || newEmail)) {
      return EmberObject.create({
        failed: true,
        reason: I18n.t("user.email.invalid"),
      });
    }
  },

  reset() {
    this.setProperties({
      taken: false,
      saving: false,
      error: false,
      success: false,
      newEmail: null,
    });
  },

  actions: {
    saveEmail() {
      this.set("saving", true);

      return (
        this.new
          ? this.model.addEmail(this.newEmail)
          : this.model.changeEmail(this.newEmail)
      ).then(
        () => {
          this.set("success", true);

          if (this.model.staff) {
            this.set(
              "successMessage",
              I18n.t("user.change_email.success_staff")
            );
          } else {
            if (this.currentUser.admin) {
              this.set(
                "successMessage",
                I18n.t("user.change_email.success_via_admin")
              );
            } else {
              this.set("successMessage", I18n.t("user.change_email.success"));
            }
          }
        },
        (e) => {
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
    },
  },
});
