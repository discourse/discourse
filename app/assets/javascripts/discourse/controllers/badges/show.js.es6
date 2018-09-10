import UserBadge from "discourse/models/user-badge";
import {
  default as computed,
  observes
} from "ember-addons/ember-computed-decorators";
import BadgeSelectController from "discourse/mixins/badge-select-controller";

export default Ember.Controller.extend(BadgeSelectController, {
  queryParams: ["username"],
  noMoreBadges: false,
  userBadges: null,
  application: Ember.inject.controller(),
  hiddenSetTitle: true,

  filteredList: function() {
    return this.get("userBadgesAll").filterBy("badge.allow_title", true);
  }.property("userBadgesAll"),

  @computed("username")
  user(username) {
    if (username) {
      return this.get("userBadges")[0].get("user");
    }
  },

  @computed("username", "model.grant_count", "userBadges.grant_count")
  grantCount(username, modelCount, userCount) {
    return username ? userCount : modelCount;
  },

  @computed("model.grant_count", "userBadges.grant_count")
  othersCount(modelCount, userCount) {
    return modelCount - userCount;
  },

  @computed("model.allow_title", "model.has_badge", "model")
  canSelectTitle(hasTitleBadges, hasBadge) {
    return this.siteSettings.enable_badges && hasTitleBadges && hasBadge;
  },

  actions: {
    loadMore() {
      if (this.get("loadingMore")) {
        return;
      }
      this.set("loadingMore", true);

      const userBadges = this.get("userBadges");

      UserBadge.findByBadgeId(this.get("model.id"), {
        offset: userBadges.length,
        username: this.get("username")
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

  @computed("noMoreBadges", "grantCount", "userBadges.length")
  canLoadMore(noMoreBadges, grantCount, userBadgeLength) {
    if (noMoreBadges) {
      return false;
    }
    return grantCount > (userBadgeLength || 0);
  },

  @computed("user", "model.grant_count")
  canShowOthers(user, grantCount) {
    return !!user && grantCount > 1;
  },

  @observes("canLoadMore")
  _showFooter() {
    this.set("application.showFooter", !this.get("canLoadMore"));
  }
});
