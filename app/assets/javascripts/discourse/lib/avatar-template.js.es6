import { hashString } from 'discourse/lib/hash';

let _splitAvatars;

function defaultAvatar(username, letterAvatarColor) {
  const defaultAvatars = Discourse.SiteSettings.default_avatars,
        version = Discourse.LetterAvatarVersion;

  if (defaultAvatars && defaultAvatars.length) {
    _splitAvatars = _splitAvatars || defaultAvatars.split("\n");

    if (_splitAvatars.length) {
      const hash = hashString(username);
      return _splitAvatars[Math.abs(hash) % _splitAvatars.length];
    }
  }

  if (Discourse.SiteSettings.external_letter_avatars_enabled) {
    const url = Discourse.SiteSettings.external_letter_avatars_url;
    return `${url}/letter/${username[0]}/${letterAvatarColor}/{size}.png`;
  } else {
    return Discourse.getURLWithCDN(`/letter_avatar/${username.toLowerCase()}/{size}/${version}.png`);
  }
}

export default function(username, uploadedAvatarId, letterAvatarColor) {
  if (uploadedAvatarId) {
    return Discourse.getURLWithCDN(`/user_avatar/${Discourse.BaseUrl}/${username.toLowerCase()}/{size}/${uploadedAvatarId}.png`);
  }
  return defaultAvatar(username, letterAvatarColor);
}
