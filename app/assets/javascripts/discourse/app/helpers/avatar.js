import { get } from "@ember/object";
import { htmlSafe } from "@ember/template";
import { avatarImg } from "discourse/lib/avatar-utils";
import { registerRawHelper } from "discourse/lib/helpers";
import { prioritizeNameInUx } from "discourse/lib/settings";
import { formatUsername } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

let _customAvatarHelpers;

export function registerCustomAvatarHelper(fn) {
  _customAvatarHelpers = _customAvatarHelpers || [];
  _customAvatarHelpers.push(fn);
}

export function addExtraUserClasses(u, args) {
  let extraClasses = classesForUser(u).join(" ");
  if (extraClasses && extraClasses.length) {
    args.extraClasses = extraClasses;
  }
  return args;
}

export function classesForUser(u) {
  let result = [];
  if (_customAvatarHelpers) {
    for (let i = 0; i < _customAvatarHelpers.length; i++) {
      result = result.concat(_customAvatarHelpers[i](u));
    }
  }
  return result;
}

export function renderAvatar(user, options) {
  options = options || {};

  if (user) {
    const name = get(user, options.namePath || "name");
    const username = get(user, options.usernamePath || "username");
    const avatarTemplate = get(
      user,
      options.avatarTemplatePath || "avatar_template"
    );

    if (!username || !avatarTemplate) {
      return "";
    }

    let displayName = prioritizeNameInUx(name)
      ? name
      : formatUsername(username);

    let title = options.title;
    if (!title && !options.ignoreTitle) {
      // first try to get a title
      title = get(user, "title");
      // if there was no title provided
      if (!title) {
        // try to retrieve a description
        const description = get(user, "description");
        // if a description has been provided
        if (description && description.length > 0) {
          // prepend the username before the description
          title = i18n("user.avatar.name_and_description", {
            name: displayName,
            description,
          });
        }
      }
    }

    return avatarImg({
      size: options.imageSize,
      extraClasses: get(user, "extras") || options.extraClasses,
      title: title || displayName,
      avatarTemplate,
    });
  } else {
    return "";
  }
}

registerRawHelper("avatar", avatar);
export default function avatar(user, params) {
  return htmlSafe(renderAvatar.call(this, user, params));
}
