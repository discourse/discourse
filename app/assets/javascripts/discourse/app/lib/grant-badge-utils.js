import { convertIconClass } from "discourse-common/lib/icon-library";

export function grantableBadges(allBadges, userBadges) {
  const granted = userBadges.reduce((map, badge) => {
    map[badge.badge_id] = true;
    return map;
  }, {});

  return allBadges
    .filter((badge) => {
      return (
        badge.enabled &&
        badge.manually_grantable &&
        (!granted[badge.id] || badge.multiple_grant)
      );
    })
    .map((badge) => {
      if (badge.icon) {
        badge.set("icon", convertIconClass(badge.icon));
      }
      return badge;
    })
    .sort((a, b) => a.name.localeCompare(b.name));
}

export function isBadgeGrantable(badgeId, availableBadges) {
  return availableBadges?.some((b) => b.id === badgeId);
}
