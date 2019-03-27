import PreferencesTabController from "discourse/mixins/preferences-tab-controller";
import { popupAjaxError } from "discourse/lib/ajax-error";
import showModal from "discourse/lib/show-modal";
import User from "discourse/models/user";

export default Ember.Controller.extend(PreferencesTabController, {
  saveAttrNames: ["muted_usernames"],
  ignoredUsernames: null,
  previousIgnoredUsernames: null,
  actions: {
    ignoredUsernamesChanged() {
      if (
        this.get("ignoredUsernames") &&
        (!this.get("previousIgnoredUsernames") ||
          this.get("ignoredUsernames.length") -
            this.get("previousIgnoredUsernames.length") >
            0)
      ) {
        const username = this.get("ignoredUsernames")
          .split(",")
          .pop();
        if (username) {
          User.findByUsername(username).then(user => {
            const controller = showModal("ignore-duration", {
              model: user
            });
            controller.setProperties({
              refreshHeaderContent: () => {}
            });
          });
        }
      }

      this.set("previousIgnoredUsernames", this.get("ignoredUsernames"));
    },
    save() {
      this.set("saved", false);
      return this.get("model")
        .save(this.get("saveAttrNames"))
        .then(() => this.set("saved", true))
        .catch(popupAjaxError);
    }
  }
});
