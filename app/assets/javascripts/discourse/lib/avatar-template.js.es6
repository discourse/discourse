import { hashString } from 'discourse/lib/hash';

let _splitAvatars;

function defaultAvatar(username) {
  const defaultAvatars = Discourse.SiteSettings.default_avatars;
  if (defaultAvatars && defaultAvatars.length) {
    _splitAvatars = _splitAvatars || defaultAvatars.split("\n");

    if (_splitAvatars.length) {
      const hash = hashString(username);
      return _splitAvatars[Math.abs(hash) % _splitAvatars.length];
    }
  }

  return Discourse.getURLWithCDN("/letter_avatar/" +
                                 username.toLowerCase() +
                                 "/{size}/" +
                                 Discourse.LetterAvatarVersion + ".png");
}

export default function(username, uploadedAvatarId) {
  if (uploadedAvatarId) {
    return Discourse.getURLWithCDN("/user_avatar/" +
                                   Discourse.BaseUrl +
                                   "/" +
                                   username.toLowerCase() +
                                   "/{size}/" +
                                   uploadedAvatarId + ".png");
  }
  return defaultAvatar(username);
}
