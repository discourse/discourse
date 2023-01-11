import Controller from "@ember/controller";
import discourseComputed from "discourse-common/utils/decorators";
import { or } from "@ember/object/computed";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Controller.extend({
  @discourseComputed("siteSettings.mute_all_categories_by_default")
  saveAttrNames(muteAllCategoriesByDefault) {
    return [
      "watched_category_ids",
      "tracked_category_ids",
      "watched_first_post_category_ids",
      muteAllCategoriesByDefault
        ? "regular_category_ids"
        : "muted_category_ids",
    ];
  },

  @discourseComputed(
    "siteSettings.mute_all_categories_by_default",
    "model.watchedCategories",
    "model.watchedFirstPostCategories",
    "model.trackedCategories",
    "model.mutedCategories",
    "model.regularCategories"
  )
  selectedCategories(
    muteAllCategoriesByDefault,
    watched,
    watchedFirst,
    tracked,
    muted,
    regular
  ) {
    let categories = [].concat(watched, watchedFirst, tracked);

    categories = categories.concat(
      muteAllCategoriesByDefault ? regular : muted
    );

    return categories.filter((t) => t);
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
    },
  },
});
