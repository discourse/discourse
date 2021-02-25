import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import { alias, filterBy, lt, sort } from "@ember/object/computed";

const MAX_FAVORITES = 2;

export default Controller.extend({
  user: controller(),
  username: alias("user.model.username_lower"),
  sortedBadges: sort("model", "badgeSortOrder"),
  favoriteBadges: filterBy("model", "is_favorite", true),
  favoriteCount: alias("favoriteBadges.length"),
  canFavorite: lt("favoriteCount", MAX_FAVORITES),

  init() {
    this._super(...arguments);

    this.maxFavorites = MAX_FAVORITES;
    this.badgeSortOrder = ["badge.badge_type.sort_order:desc", "badge.name"];
  },

  @action
  favorite(badge) {
    return badge.favorite();
  },
});
