let _autoGroupFlair, _noAutoFlair;

export default function autoGroupFlairForUser(site, user) {
  if (!_autoGroupFlair) {
    initializeAutoGroupFlair(site);
  }

  if (_noAutoFlair) {
    // No automatic groups have flair.
    return null;
  }

  if (user.admin && _autoGroupFlair.admins) {
    return _autoGroupFlair.admins;
  }

  if (user.moderator && _autoGroupFlair.moderators) {
    return _autoGroupFlair.moderators;
  }

  if (_autoGroupFlair.staff && (user.admin || user.moderator)) {
    return _autoGroupFlair.staff;
  }

  let trustLevel = user.trust_level || user.trustLevel;

  if (trustLevel) {
    for (let i = trustLevel; i >= 0; i--) {
      if (_autoGroupFlair[`trust_level_${i}`]) {
        return _autoGroupFlair[`trust_level_${i}`];
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

  [
    "admins",
    "moderators",
    "staff",
    "trust_level_0",
    "trust_level_1",
    "trust_level_2",
    "trust_level_3",
    "trust_level_4",
  ].forEach((groupName) => {
    const group = site.groups?.findBy("name", groupName);
    if (group && group.flair_url) {
      _noAutoFlair = false;
      _autoGroupFlair[groupName] = {
        flair_name: group.name.replace(/_/g, " "),
        flair_url: group.flair_url,
        flair_bg_color: group.flair_bg_color,
        flair_color: group.flair_color,
      };
    }
  });
}
