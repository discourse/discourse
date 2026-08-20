import { convertIconClass } from "discourse/lib/icon-library";

export function grantableBadges(allBadges, userBadges) {
  const granted = new Set(userBadges.map((ub) => ub.badge_id));

  return allBadges
    .filter(
      (badge) =>
        badge.enabled &&
        badge.manually_grantable &&
        (!granted.has(badge.id) || badge.multiple_grant)
    )
    .map((badge) => ({
      id: badge.id,
      name: badge.name,
      icon: badge.icon ? convertIconClass(badge.icon) : null,
    }))
    .sort((a, b) => a.name.localeCompare(b.name));
}

export function isBadgeGrantable(badgeId, availableBadges) {
  return !!(availableBadges && availableBadges.some((b) => b.id === badgeId));
}
