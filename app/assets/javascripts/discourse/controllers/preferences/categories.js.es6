import discourseComputed from "discourse-common/utils/decorators";
import { or } from "@ember/object/computed";
import Controller from "@ember/controller";
import PreferencesTabController from "discourse/mixins/preferences-tab-controller";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Controller.extend(PreferencesTabController, {
  init() {
    this._super(...arguments);

    this.saveAttrNames = [
      "muted_category_ids",
      "watched_category_ids",
      "tracked_category_ids",
      "watched_first_post_category_ids"
    ];
  },

  @discourseComputed(
    "model.watchedCategories",
    "model.watchedFirstPostCategories",
    "model.trackedCategories",
    "model.mutedCategories"
  )
  selectedCategories(watched, watchedFirst, tracked, muted) {
    return [].concat(watched, watchedFirst, tracked, muted).filter(t => t);
  },

  @discourseComputed
  canSee() {
    return this.get("currentUser.id") === this.get("model.id");
  },

  @discourseComputed("siteSettings.remove_muted_tags_from_latest")
  hideMutedTags() {
    return this.siteSettings.remove_muted_tags_from_latest !== "never";
  },

  canSave: or("canSee", "currentUser.admin"),

  actions: {
    save() {
      this.set("saved", false);
      return this.model
        .save(this.saveAttrNames)
        .then(() => {
          this.set("saved", true);
        })
        .catch(popupAjaxError);
    }
  }
});
