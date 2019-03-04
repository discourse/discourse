import PreferencesTabController from "discourse/mixins/preferences-tab-controller";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Ember.Controller.extend(PreferencesTabController, {
  saveAttrNames: [
    "muted_usernames",
    "ignored_usernames"
  ],

  actions: {
    save() {
      this.set("saved", false);
      return this.get("model")
        .save(this.get("saveAttrNames"))
        .then(() => {
          this.set("saved", true);
        })
        .catch(popupAjaxError);
    }
  }
});
