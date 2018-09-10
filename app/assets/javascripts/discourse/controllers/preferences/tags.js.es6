import PreferencesTabController from "discourse/mixins/preferences-tab-controller";
import { popupAjaxError } from "discourse/lib/ajax-error";
import computed from "ember-addons/ember-computed-decorators";

export default Ember.Controller.extend(PreferencesTabController, {
  saveAttrNames: [
    "muted_tags",
    "tracked_tags",
    "watched_tags",
    "watching_first_post_tags"
  ],

  @computed(
    "model.watched_tags.[]",
    "model.watching_first_post_tags.[]",
    "model.tracked_tags.[]",
    "model.muted_tags.[]"
  )
  selectedTags(watched, watchedFirst, tracked, muted) {
    return [].concat(watched, watchedFirst, tracked, muted).filter(t => t);
  },

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
