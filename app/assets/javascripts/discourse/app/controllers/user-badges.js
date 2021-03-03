import Controller, { inject as controller } from "@ember/controller";
import { action, computed } from "@ember/object";
import { alias, filterBy, sort } from "@ember/object/computed";

export default Controller.extend({
  user: controller(),
  username: alias("user.model.username_lower"),
  sortedBadges: sort("model", "badgeSortOrder"),
  favoriteBadges: filterBy("model", "is_favorite", true),
  favoriteCount: alias("favoriteBadges.length"),
  maxFavorites: alias("model.meta.max_favorites"),
  canFavorite: computed("favoriteCount", "maxFavorites", function () {
    return this.favoriteCount < this.maxFavorites;
  }),

  init() {
    this._super(...arguments);
    this.badgeSortOrder = ["badge.badge_type.sort_order:desc", "badge.name"];
  },

  @action
  favorite(badge) {
    return badge.favorite();
  },
});
