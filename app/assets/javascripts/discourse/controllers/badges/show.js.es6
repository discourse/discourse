import { inject } from "@ember/controller";
import EmberObject from "@ember/object";
import Controller from "@ember/controller";
import Badge from "discourse/models/badge";
import UserBadge from "discourse/models/user-badge";
import discourseComputed, { observes } from "discourse-common/utils/decorators";

export default Controller.extend({
  queryParams: ["username"],
  noMoreBadges: false,
  userBadges: null,
  application: inject(),
  hiddenSetTitle: true,

  @discourseComputed("userBadgesAll")
  filteredList(userBadgesAll) {
    return userBadgesAll.filterBy("badge.allow_title", true);
  },

  @discourseComputed("filteredList")
  selectableUserBadges(filteredList) {
    return [
      EmberObject.create({
        badge: Badge.create({ name: I18n.t("badges.none") })
      }),
      ...filteredList.uniqBy("badge.name")
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

  actions: {
    loadMore() {
      if (this.loadingMore) {
        return;
      }
      this.set("loadingMore", true);

      const userBadges = this.userBadges;

      UserBadge.findByBadgeId(this.get("model.id"), {
        offset: userBadges.length,
        username: this.username
      })
        .then(result => {
          userBadges.pushObjects(result);
          if (userBadges.length === 0) {
            this.set("noMoreBadges", true);
          }
        })
        .finally(() => {
          this.set("loadingMore", false);
        });
    },

    toggleSetUserTitle() {
      return this.toggleProperty("hiddenSetTitle");
    }
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

  @observes("canLoadMore")
  _showFooter() {
    this.set("application.showFooter", !this.canLoadMore);
  }
});
