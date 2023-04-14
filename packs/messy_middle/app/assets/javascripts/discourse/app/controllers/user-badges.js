import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import { alias, filterBy, sort } from "@ember/object/computed";
import discourseComputed from "discourse-common/utils/decorators";

export default Controller.extend({
  user: controller(),
  username: alias("user.model.username_lower"),
  sortedBadges: sort("model", "badgeSortOrder"),
  favoriteBadges: filterBy("model", "is_favorite", true),

  @discourseComputed("favoriteBadges.length")
  canFavoriteMoreBadges(favoriteBadgesCount) {
    return favoriteBadgesCount < this.siteSettings.max_favorite_badges;
  },

  init() {
    this._super(...arguments);
    this.badgeSortOrder = ["badge.badge_type.sort_order:desc", "badge.name"];
  },

  @action
  favorite(badge) {
    return badge.favorite();
  },
});
