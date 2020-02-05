import discourseComputed from "discourse-common/utils/decorators";
import Controller from "@ember/controller";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Controller.extend({
  userModes: [
    { id: "all", name: I18n.t("admin.api.all_users") },
    { id: "single", name: I18n.t("admin.api.single_user") }
  ],

  @discourseComputed("userMode")
  showUserSelector(mode) {
    return mode === "single";
  },

  @discourseComputed("model.description", "model.username", "userMode")
  saveDisabled(description, username, userMode) {
    if (Ember.isBlank(description)) return true;
    if (userMode === "single" && Ember.isBlank(username)) return true;
    return false;
  },

  actions: {
    changeUserMode(value) {
      if (value === "all") {
        this.model.set("username", null);
      }
      this.set("userMode", value);
    },

    save() {
      this.model.save().catch(popupAjaxError);
    },

    continue() {
      this.transitionToRoute("adminApiKeys.show", this.model.id);
    }
  }
});
