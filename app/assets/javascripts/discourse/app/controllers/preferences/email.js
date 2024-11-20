import Controller from "@ember/controller";
import EmberObject, { action } from "@ember/object";
import { empty, or } from "@ember/object/computed";
import { propertyEqual } from "discourse/lib/computed";
import { emailValid } from "discourse/lib/utilities";
import discourseComputed from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";

export default class EmailController extends Controller {
  queryParams = ["new"];
  taken = false;
  saving = false;
  error = false;
  success = false;
  oldEmail = null;
  newEmail = null;
  successMessage = null;

  @empty("newEmail") newEmailEmpty;

  @or("saving", "newEmailEmpty", "taken", "unchanged", "invalidEmail")
  saveDisabled;

  @propertyEqual("newEmailLower", "oldEmail") unchanged;

  @discourseComputed("newEmail")
  newEmailLower(newEmail) {
    return newEmail.toLowerCase().trim();
  }

  @discourseComputed("saving", "new")
  saveButtonText(saving, isNew) {
    if (saving) {
      return i18n("saving");
    }
    if (isNew) {
      return i18n("user.add_email.add");
    }
    return i18n("user.change");
  }

  @discourseComputed("newEmail")
  invalidEmail(newEmail) {
    return !emailValid(newEmail);
  }

  @discourseComputed("invalidEmail", "oldEmail", "newEmail")
  emailValidation(invalidEmail, oldEmail, newEmail) {
    if (invalidEmail && (oldEmail || newEmail)) {
      return EmberObject.create({
        failed: true,
        reason: i18n("user.email.invalid"),
      });
    }
  }

  reset() {
    this.setProperties({
      taken: false,
      saving: false,
      error: false,
      success: false,
      newEmail: null,
    });
  }

  @action
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
          this.set("successMessage", i18n("user.change_email.success_staff"));
        } else {
          if (this.currentUser.admin) {
            this.set(
              "successMessage",
              i18n("user.change_email.success_via_admin")
            );
          } else {
            this.set("successMessage", i18n("user.change_email.success"));
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
          this.set("errorMessage", i18n("user.change_email.error"));
        }
      }
    );
  }
}
