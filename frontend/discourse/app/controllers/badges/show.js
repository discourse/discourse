import { tracked } from "@glimmer/tracking";
import Controller, { inject as controller } from "@ember/controller";
import EmberObject, { action } from "@ember/object";
import { uniqueItemsFromArray } from "discourse/lib/array-tools";
import discourseComputed from "discourse/lib/decorators";
import { trackedArray } from "discourse/lib/tracked-tools";
import Badge from "discourse/models/badge";
import UserBadge from "discourse/models/user-badge";
import { i18n } from "discourse-i18n";

export default class ShowController extends Controller {
  @controller application;

  @tracked loadingMore = false;
  @tracked noMoreBadges = false;
  @tracked userBadgesInfo = null;
  @trackedArray userBadges = null;

  queryParams = ["username"];
  hiddenSetTitle = true;

  @discourseComputed("userBadgesAll")
  filteredList(userBadgesAll) {
    return userBadgesAll.filter((item) => item.badge.allow_title);
  }

  @discourseComputed("filteredList")
  selectableUserBadges(filteredList) {
    return [
      EmberObject.create({
        id: 0,
        badge: Badge.create({ name: i18n("badges.none") }),
      }),
      ...uniqueItemsFromArray(filteredList, "badge.name"),
    ];
  }

  @discourseComputed("username")
  user(username) {
    if (username) {
      return this.userBadges[0].get("user");
    }
  }

  @discourseComputed(
    "username",
    "model.grant_count",
    "userBadgesInfo.grant_count"
  )
  grantCount(username, modelCount, userCount) {
    return username ? userCount : modelCount;
  }

  @discourseComputed("model.grant_count", "userBadgesInfo.grant_count")
  othersCount(modelCount, userCount) {
    return modelCount - userCount;
  }

  @discourseComputed("model.allow_title", "model.has_badge", "model")
  canSelectTitle(hasTitleBadges, hasBadge) {
    return this.siteSettings.enable_badges && hasTitleBadges && hasBadge;
  }

  @discourseComputed("noMoreBadges", "grantCount", "userBadges.length")
  canLoadMore(noMoreBadges, grantCount, userBadgeLength) {
    if (noMoreBadges) {
      return false;
    }
    return grantCount > (userBadgeLength || 0);
  }

  @discourseComputed("user", "model.grant_count")
  canShowOthers(user, grantCount) {
    return !!user && grantCount > 1;
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
