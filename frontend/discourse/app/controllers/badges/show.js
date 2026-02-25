import { tracked } from "@glimmer/tracking";
import Controller, { inject as controller } from "@ember/controller";
import EmberObject, { action, computed } from "@ember/object";
import { uniqueItemsFromArray } from "discourse/lib/array-tools";
import { trackedArray } from "discourse/lib/tracked-tools";
import Badge from "discourse/models/badge";
import UserBadge from "discourse/models/user-badge";
import { i18n } from "discourse-i18n";

export default class ShowController extends Controller {
  @controller application;

  @tracked loadingMore = false;
  @tracked noMoreBadges = false;

  @tracked userBadgesGrantCount;
  @trackedArray userBadges = null;

  queryParams = ["username"];
  hiddenSetTitle = true;

  @computed("userBadgesAll")
  get filteredList() {
    return this.userBadgesAll.filter((item) => item.badge.allow_title);
  }

  @computed("filteredList")
  get selectableUserBadges() {
    return [
      EmberObject.create({
        id: 0,
        badge: Badge.create({ name: i18n("badges.none") }),
      }),
      ...uniqueItemsFromArray(this.filteredList, "badge.name"),
    ];
  }

  @computed("username")
  get user() {
    if (this.username) {
      return this.userBadges[0].get("user");
    }
  }

  get grantCount() {
    return this.username ? this.userBadgesGrantCount : this.model.grant_count;
  }

  @computed("model.grant_count", "userBadgesGrantCount")
  get othersCount() {
    return this.model?.grant_count - this.userBadgesGrantCount;
  }

  @computed("model.allow_title", "model.has_badge", "model")
  get canSelectTitle() {
    return (
      this.siteSettings.enable_badges &&
      this.model?.allow_title &&
      this.model?.has_badge
    );
  }

  get canLoadMore() {
    if (this.noMoreBadges) {
      return false;
    }
    return this.grantCount > (this.userBadges?.length || 0);
  }

  @computed("user", "model.grant_count")
  get canShowOthers() {
    return !!this.user && this.model?.grant_count > 1;
  }

  @action
  async loadMore() {
    if (!this.canLoadMore || this.loadingMore) {
      return;
    }

    this.loadingMore = true;

    try {
      const userBadges = this.userBadges;
      const result = await UserBadge.findByBadgeId(this.get("model.id"), {
        offset: userBadges.length,
        username: this.username,
      });

      userBadges.push(...result);
      if (userBadges.length === 0) {
        this.noMoreBadges = true;
      }
    } finally {
      this.loadingMore = false;
    }
  }

  @action
  toggleSetUserTitle() {
    return this.toggleProperty("hiddenSetTitle");
  }
}
