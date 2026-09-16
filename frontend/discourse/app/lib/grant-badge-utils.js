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
    .sort((a, b) => a.name.localeCompare(b.name));
}

// `ComboBox` renders `item.icon` directly, so it needs the converted class.
// Derived rather than assigned back: badge records are shared through the
// store, and everything else converts at render time (`d-icon-or-image`).
export function grantableBadgeOptions(badges) {
  return badges.map((badge) => ({
    id: badge.id,
    name: badge.name,
    icon: badge.icon ? convertIconClass(badge.icon) : null,
  }));
}

export function isBadgeGrantable(badgeId, availableBadges) {
  return !!(availableBadges && availableBadges.some((b) => b.id === badgeId));
}
