import PreferencesTabController from "discourse/mixins/preferences-tab-controller";
import { popupAjaxError } from "discourse/lib/ajax-error";
import showModal from "discourse/lib/show-modal";
import User from "discourse/models/user";
import { default as computed } from "ember-addons/ember-computed-decorators";

export default Ember.Controller.extend(PreferencesTabController, {
  saveAttrNames: ["muted_usernames", "ignored_usernames"],
  ignoredUsernames: Ember.computed.alias("model.ignored_usernames"),
  previousIgnoredUsernames: null,
  init() {
    this._super(...arguments);
    this.set("previousIgnoredUsernames", this.get("ignoredUsernames"));
  },
  actions: {
    ignoredUsernamesChanged() {
      if (
        (this.get("ignoredUsernames") &&
          !this.get("previousIgnoredUsernames")) ||
        this.get("ignoredUsernames.length") -
          this.get("previousIgnoredUsernames.length") >
          0
      ) {
        const username = this.get("ignoredUsernames")
          .split(",")
          .pop();
        if (username) {
          User.findByUsername(username).then(user => {
            showModal("ignore-duration", {
              model: user
            });
          });
        }
      } else if (
        (!this.get("ignoredUsernames") &&
          this.get("previousIgnoredUsernames")) ||
        this.get("previousIgnoredUsernames.length") -
          this.get("ignoredUsernames.length") >
          0
      ) {
        return this.get("model")
          .save(["ignored_usernames"])
          .catch(popupAjaxError);
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
