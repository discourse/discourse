import computed from "ember-addons/ember-computed-decorators";
import UserBadge from "discourse/models/user-badge";
import { convertIconClass } from "discourse-common/lib/icon-library";

export default Ember.Mixin.create({
  @computed("allBadges.[]", "userBadges.[]")
  grantableBadges(allBadges, userBadges) {
    const granted = userBadges.reduce((map, badge) => {
      map[badge.badge_id] = true;
      return map;
    }, {});

    return allBadges
      .filter(badge => {
        return (
          badge.enabled &&
          badge.manually_grantable &&
          (!granted[badge.id] || badge.multiple_grant)
        );
      })
      .map(badge => {
        if (badge.icon) {
          badge.set("icon", convertIconClass(badge.icon));
        }
        return badge;
      })
      .sort((a, b) => a.name.localeCompare(b.name));
  },

  noGrantableBadges: Ember.computed.empty("grantableBadges"),

  @computed("selectedBadgeId", "grantableBadges")
  selectedBadgeGrantable(selectedBadgeId, grantableBadges) {
    return (
      grantableBadges &&
      grantableBadges.find(badge => badge.id === selectedBadgeId)
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
