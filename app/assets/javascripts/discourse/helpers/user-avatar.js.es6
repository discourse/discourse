import { registerUnbound } from "discourse-common/lib/helpers";
import { avatarImg, formatUsername } from "discourse/lib/utilities";

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

function renderAvatar(user, options) {
  options = options || {};

  if (user) {
    const username = Em.get(user, options.usernamePath || "username");
    const avatarTemplate = Em.get(
      user,
      options.avatarTemplatePath || "avatar_template"
    );

    if (!username || !avatarTemplate) {
      return "";
    }

    let displayName = Ember.get(user, "name") || formatUsername(username);

    let title = options.title;
    if (!title && !options.ignoreTitle) {
      // first try to get a title
      title = Em.get(user, "title");
      // if there was no title provided
      if (!title) {
        // try to retrieve a description
        const description = Em.get(user, "description");
        // if a description has been provided
        if (description && description.length > 0) {
          // preprend the username before the description
          title = displayName + " - " + description;
        }
      }
    }

    return avatarImg({
      size: options.imageSize,
      extraClasses: Em.get(user, "extras") || options.extraClasses,
      title: title || displayName,
      avatarTemplate: avatarTemplate
    });
  } else {
    return "";
  }
}

registerUnbound("avatar", function(user, params) {
  return new Handlebars.SafeString(renderAvatar.call(this, user, params));
});

export { renderAvatar };
