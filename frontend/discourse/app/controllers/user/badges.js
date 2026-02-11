import Controller, { inject as controller } from "@ember/controller";
import { action, computed } from "@ember/object";
import { alias, filterBy, sort } from "@ember/object/computed";

export default class UserBadgesController extends Controller {
  @controller user;

  @alias("user.model.username_lower") username;
  @sort("model", "badgeSortOrder") sortedBadges;
  @filterBy("model", "is_favorite", true) favoriteBadges;

  badgeSortOrder = ["badge.badge_type.sort_order:desc", "badge.name"];

  @computed("favoriteBadges.length")
  get canFavoriteMoreBadges() {
    return this.favoriteBadges?.length < this.siteSettings.max_favorite_badges;
  }

  @action
  favorite(badge) {
    return badge.favorite();
  }
}
