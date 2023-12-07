import Controller from "@ember/controller";
import { or } from "@ember/object/computed";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed from "discourse-common/utils/decorators";

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
    "model.watched_categoriy_ids",
    "model.watched_first_post_categoriy_ids",
    "model.tracked_categoriy_ids",
    "model.muted_categoriy_ids",
    "model.regular_category_ids",
    "siteSettings.mute_all_categories_by_default"
  )
  selectedCategoryIds(
    watched,
    watchedFirst,
    tracked,
    muted,
    regular,
    muteAllCategoriesByDefault
  ) {
    return [].concat(
      watched,
      watchedFirst,
      tracked,
      muteAllCategoriesByDefault ? regular : muted
    );
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
