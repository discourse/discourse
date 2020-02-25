import { isEmpty } from "@ember/utils";
import { empty, or } from "@ember/object/computed";
import Controller from "@ember/controller";
import discourseComputed, { observes } from "discourse-common/utils/decorators";
import { setting, propertyEqual } from "discourse/lib/computed";
import DiscourseURL from "discourse/lib/url";
import { userPath } from "discourse/lib/url";
import { popupAjaxError } from "discourse/lib/ajax-error";
import User from "discourse/models/user";

export default Controller.extend({
  taken: false,
  saving: false,
  errorMessage: null,
  newUsername: null,

  maxLength: setting("max_username_length"),
  minLength: setting("min_username_length"),
  newUsernameEmpty: empty("newUsername"),
  saveDisabled: or(
    "saving",
    "newUsernameEmpty",
    "taken",
    "unchanged",
    "errorMessage"
  ),
  unchanged: propertyEqual("newUsername", "username"),

  @observes("newUsername")
  checkTaken() {
    let newUsername = this.newUsername;

    if (newUsername && newUsername.length < this.minLength) {
      this.set("errorMessage", I18n.t("user.name.too_short"));
    } else {
      this.set("taken", false);
      this.set("errorMessage", null);

      if (isEmpty(this.newUsername)) return;
      if (this.unchanged) return;

      User.checkUsername(newUsername, undefined, this.get("model.id")).then(
        result => {
          if (result.errors) {
            this.set("errorMessage", result.errors.join(" "));
          } else if (result.available === false) {
            this.set("taken", true);
          }
        }
      );
    }
  },

  @discourseComputed("saving")
  saveButtonText(saving) {
    if (saving) return I18n.t("saving");
    return I18n.t("user.change");
  },

  actions: {
    changeUsername() {
      if (this.saveDisabled) {
        return;
      }

      return bootbox.confirm(
        I18n.t("user.change_username.confirm"),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        result => {
          if (result) {
            this.set("saving", true);
            this.model
              .changeUsername(this.newUsername)
              .then(() => {
                DiscourseURL.redirectTo(
                  userPath(this.newUsername.toLowerCase() + "/preferences")
                );
              })
              .catch(popupAjaxError)
              .finally(() => this.set("saving", false));
          }
        }
      );
    }
  }
});
