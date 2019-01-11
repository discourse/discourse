import {
  default as computed,
  observes
} from "ember-addons/ember-computed-decorators";
import { setting, propertyEqual } from "discourse/lib/computed";
import DiscourseURL from "discourse/lib/url";
import { userPath } from "discourse/lib/url";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Ember.Controller.extend({
  taken: false,
  saving: false,
  errorMessage: null,
  newUsername: null,

  maxLength: setting("max_username_length"),
  minLength: setting("min_username_length"),
  newUsernameEmpty: Ember.computed.empty("newUsername"),
  saveDisabled: Ember.computed.or(
    "saving",
    "newUsernameEmpty",
    "taken",
    "unchanged",
    "errorMessage"
  ),
  unchanged: propertyEqual("newUsername", "username"),

  @observes("newUsername")
  checkTaken() {
    let newUsername = this.get("newUsername");

    if (newUsername && newUsername.length < this.get("minLength")) {
      this.set("errorMessage", I18n.t("user.name.too_short"));
    } else {
      this.set("taken", false);
      this.set("errorMessage", null);

      if (Ember.isEmpty(this.get("newUsername"))) return;
      if (this.get("unchanged")) return;

      Discourse.User.checkUsername(
        newUsername,
        undefined,
        this.get("model.id")
      ).then(result => {
        if (result.errors) {
          this.set("errorMessage", result.errors.join(" "));
        } else if (result.available === false) {
          this.set("taken", true);
        }
      });
    }
  },

  @computed("saving")
  saveButtonText(saving) {
    if (saving) return I18n.t("saving");
    return I18n.t("user.change");
  },

  actions: {
    changeUsername() {
      if (this.get("saveDisabled")) {
        return;
      }

      return bootbox.confirm(
        I18n.t("user.change_username.confirm"),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        result => {
          if (result) {
            this.set("saving", true);
            this.get("model")
              .changeUsername(this.get("newUsername"))
              .then(() => {
                DiscourseURL.redirectTo(
                  userPath(
                    this.get("newUsername").toLowerCase() + "/preferences"
                  )
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
