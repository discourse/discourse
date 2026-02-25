import { tracked } from "@glimmer/tracking";
import Controller, { inject as controller } from "@ember/controller";
import { action, computed, set } from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import { arraySortedByProperties } from "discourse/lib/array-tools";

export default class UserBadgesController extends Controller {
  @controller user;

  @tracked model;
  @tracked
  badgeSortOrder = ["grouping_position", "badge.badge_type_id", "badge.id"];

  @computed("user.model.username_lower")
  get username() {
    return this.user?.model?.username_lower;
  }

  set username(value) {
    set(this, "user.model.username_lower", value);
  }

  @dependentKeyCompat
  get sortedBadges() {
    return arraySortedByProperties(this.model, this.badgeSortOrder);
  }

  @computed("model.@each.is_favorite")
  get favoriteBadges() {
    return this.model?.filter?.((item) => item.is_favorite === true) ?? [];
  }

  @computed("favoriteBadges.length")
  get canFavoriteMoreBadges() {
    return this.favoriteBadges?.length < this.siteSettings.max_favorite_badges;
  }

  @action
  favorite(badge) {
    return badge.favorite();
  }
}
