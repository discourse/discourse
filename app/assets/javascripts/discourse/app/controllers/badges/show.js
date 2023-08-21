import EmberObject, { action } from "@ember/object";
import Controller, { inject as controller } from "@ember/controller";
import discourseComputed from "discourse-common/utils/decorators";
import Badge from "discourse/models/badge";
import I18n from "I18n";
import UserBadge from "discourse/models/user-badge";

export default Controller.extend({
  application: controller(),
  queryParams: ["username"],
  noMoreBadges: false,
  userBadges: null,
  hiddenSetTitle: true,

  @discourseComputed("userBadgesAll")
  filteredList(userBadgesAll) {
    return userBadgesAll.filterBy("badge.allow_title", true);
  },

  @discourseComputed("filteredList")
  selectableUserBadges(filteredList) {
    return [
      EmberObject.create({
        id: 0,
        badge: Badge.create({ name: I18n.t("badges.none") }),
      }),
      ...filteredList.uniqBy("badge.name"),
    ];
  },

  @discourseComputed("username")
  user(username) {
    if (username) {
      return this.userBadges[0].get("user");
    }
  },

  @discourseComputed("username", "model.grant_count", "userBadges.grant_count")
  grantCount(username, modelCount, userCount) {
    return username ? userCount : modelCount;
  },

  @discourseComputed("model.grant_count", "userBadges.grant_count")
  othersCount(modelCount, userCount) {
    return modelCount - userCount;
  },

  @discourseComputed("model.allow_title", "model.has_badge", "model")
  canSelectTitle(hasTitleBadges, hasBadge) {
    return this.siteSettings.enable_badges && hasTitleBadges && hasBadge;
  },

  @discourseComputed("noMoreBadges", "grantCount", "userBadges.length")
  canLoadMore(noMoreBadges, grantCount, userBadgeLength) {
    if (noMoreBadges) {
      return false;
    }
    return grantCount > (userBadgeLength || 0);
  },

  @discourseComputed("user", "model.grant_count")
  canShowOthers(user, grantCount) {
    return !!user && grantCount > 1;
  },

  @action
  loadMore() {
    if (!this.canLoadMore) {
      return;
    }

    if (this.loadingMore) {
      return;
    }
    this.set("loadingMore", true);

    const userBadges = this.userBadges;

    UserBadge.findByBadgeId(this.get("model.id"), {
      offset: userBadges.length,
      username: this.username,
    })
      .then((result) => {
        userBadges.pushObjects(result);
        if (userBadges.length === 0) {
          this.set("noMoreBadges", true);
        }
      })
      .finally(() => {
        this.set("loadingMore", false);
      });
  },

  @action
  toggleSetUserTitle() {
    return this.toggleProperty("hiddenSetTitle");
  },
});
