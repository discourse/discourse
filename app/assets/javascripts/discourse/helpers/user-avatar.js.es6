import registerUnbound from 'discourse/helpers/register-unbound';
import avatarTemplate from 'discourse/lib/avatar-template';

function renderAvatar(user, options) {
  options = options || {};

  if (user) {
    let username = Em.get(user, 'username');
    if (!username) {
      if (!options.usernamePath) { return ''; }
      username = Em.get(user, options.usernamePath);
    }

    let title;
    if (!options.ignoreTitle) {
      // first try to get a title
      title = Em.get(user, 'title');
      // if there was no title provided
      if (!title) {
        // try to retrieve a description
        const description = Em.get(user, 'description');
        // if a description has been provided
        if (description && description.length > 0) {
          // preprend the username before the description
          title = username + " - " + description;
        }
      }
    }

    // this is simply done to ensure we cache images correctly
    const uploadedAvatarId = Em.get(user, 'uploaded_avatar_id') || Em.get(user, 'user.uploaded_avatar_id'),
          letterAvatarColor = Em.get(user, 'letter_avatar_color') || Em.get(user, 'user.letter_avatar_color');

    return Discourse.Utilities.avatarImg({
      size: options.imageSize,
      extraClasses: Em.get(user, 'extras') || options.extraClasses,
      title: title || username,
      avatarTemplate: Em.get("avatar_template") || avatarTemplate(username, uploadedAvatarId, letterAvatarColor)
    });
  } else {
    return '';
  }
}

registerUnbound('avatar', function(user, params) {
  return new Handlebars.SafeString(renderAvatar.call(this, user, params));
});

export { renderAvatar };
