import Controller from "@ember/controller";
import PreferencesTabController from "discourse/mixins/preferences-tab-controller";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Controller.extend(PreferencesTabController, {
  ignoredUsernames: Ember.computed.alias("model.ignored_usernames"),
  userIsMemberOrAbove: Ember.computed.gte("model.trust_level", 2),
  ignoredEnabled: Ember.computed.or("userIsMemberOrAbove", "model.staff"),

  init() {
    this._super(...arguments);

    this.saveAttrNames = ["muted_usernames", "ignored_usernames"];
  },

  actions: {
    save() {
      this.set("saved", false);
      return this.model
        .save(this.saveAttrNames)
        .then(() => this.set("saved", true))
        .catch(popupAjaxError);
    }
  }
});
