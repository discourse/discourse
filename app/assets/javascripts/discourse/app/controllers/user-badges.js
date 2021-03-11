import Controller, { inject as controller } from "@ember/controller";
import { action, computed } from "@ember/object";
import { alias, filterBy, sort } from "@ember/object/computed";

export default Controller.extend({
  user: controller(),
  username: alias("user.model.username_lower"),
  sortedBadges: sort("model", "badgeSortOrder"),
  favoriteBadges: filterBy("model", "is_favorite", true),
  canFavorite: computed(
    "favoriteBadges.length",
    "model.meta.max_favorites",
    function () {
      return this.favoriteBadges.length < this.model.meta.max_favorites;
    }
  ),

  init() {
    this._super(...arguments);
    this.badgeSortOrder = ["badge.badge_type.sort_order:desc", "badge.name"];
  },

  @action
  favorite(badge) {
    return badge.favorite();
  },
});
