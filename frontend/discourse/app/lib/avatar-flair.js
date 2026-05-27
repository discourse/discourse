import { AUTO_GROUPS } from "discourse/lib/constants";

let _autoGroupFlair, _noAutoFlair;

// All automatic groups except "everyone" (which doesn't have flair)
const FLAIR_AUTO_GROUP_IDS = Object.values(AUTO_GROUPS)
  .filter((g) => g.id !== AUTO_GROUPS.everyone.id)
  .map((g) => g.id);

export default function autoGroupFlairForUser(site, user) {
  if (!_autoGroupFlair) {
    initializeAutoGroupFlair(site);
  }

  if (_noAutoFlair) {
    // No automatic groups have flair.
    return null;
  }

  if (user.admin && _autoGroupFlair[AUTO_GROUPS.admins.id]) {
    return _autoGroupFlair[AUTO_GROUPS.admins.id];
  }

  if (user.moderator && _autoGroupFlair[AUTO_GROUPS.moderators.id]) {
    return _autoGroupFlair[AUTO_GROUPS.moderators.id];
  }

  if ((user.admin || user.moderator) && _autoGroupFlair[AUTO_GROUPS.staff.id]) {
    return _autoGroupFlair[AUTO_GROUPS.staff.id];
  }

  let trustLevel = user.trust_level || user.trustLevel;

  if (trustLevel) {
    for (let i = trustLevel; i >= 0; i--) {
      const group = AUTO_GROUPS[`trust_level_${i}`];
      if (group && _autoGroupFlair[group.id]) {
        return _autoGroupFlair[group.id];
      }
    }
  }
}

export function resetFlair() {
  _autoGroupFlair = null;
  _noAutoFlair = null;
}

function initializeAutoGroupFlair(site) {
  _autoGroupFlair = {};
  _noAutoFlair = true;

  FLAIR_AUTO_GROUP_IDS.forEach((groupId) => {
    const group = site.groupsById[groupId];
    if (group?.flair_url) {
      _noAutoFlair = false;
      _autoGroupFlair[groupId] = {
        flair_name: group.name.replace(/_/g, " "),
        flair_url: group.flair_url,
        flair_bg_color: group.flair_bg_color,
        flair_color: group.flair_color,
      };
    }
  });
}
