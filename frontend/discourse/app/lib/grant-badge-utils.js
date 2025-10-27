import { convertIconClass } from "discourse/lib/icon-library";

export function grantableBadges(allBadges, userBadges) {
  const granted = userBadges.reduce((map, badge) => {
    map[badge.get("badge_id")] = true;
    return map;
  }, {});

  return allBadges
    .filter((badge) => {
      return (
        badge.get("enabled") &&
        badge.get("manually_grantable") &&
        (!granted[badge.get("id")] || badge.get("multiple_grant"))
      );
    })
    .map((badge) => {
      if (badge.get("icon")) {
        badge.set("icon", convertIconClass(badge.icon));
      }
      return badge;
    })
    .sort((a, b) => a.get("name").localeCompare(b.get("name")));
}

export function isBadgeGrantable(badgeId, availableBadges) {
  return !!(
    availableBadges && availableBadges.some((b) => b.get("id") === badgeId)
  );
}
