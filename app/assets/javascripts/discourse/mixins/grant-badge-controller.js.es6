import computed from "ember-addons/ember-computed-decorators";
import UserBadge from "discourse/models/user-badge";
import { convertIconClass } from "discourse-common/lib/icon-library";
import Mixin from '@ember/object/mixin';

export default Mixin.create({
  @computed("allBadges.[]", "userBadges.[]")
  grantableBadges(allBadges, userBadges) {
    const granted = userBadges.reduce((map, badge) => {
      map[badge.get("badge_id")] = true;
      return map;
    }, {});

    return allBadges
      .filter(badge => {
        return (
          badge.get("enabled") &&
          badge.get("manually_grantable") &&
          (!granted[badge.get("id")] || badge.get("multiple_grant"))
        );
      })
      .map(badge => {
        if (badge.get("icon")) {
          badge.set("icon", convertIconClass(badge.icon));
        }
        return badge;
      })
      .sort((a, b) => a.get("name").localeCompare(b.get("name")));
  },

  noGrantableBadges: Ember.computed.empty("grantableBadges"),

  @computed("selectedBadgeId", "grantableBadges")
  selectedBadgeGrantable(selectedBadgeId, grantableBadges) {
    return (
      grantableBadges &&
      grantableBadges.find(badge => badge.get("id") === selectedBadgeId)
    );
  },

  grantBadge(selectedBadgeId, username, badgeReason) {
    return UserBadge.grant(selectedBadgeId, username, badgeReason).then(
      newBadge => {
        this.userBadges.pushObject(newBadge);
        return newBadge;
      },
      error => {
        throw error;
      }
    );
  }
});
