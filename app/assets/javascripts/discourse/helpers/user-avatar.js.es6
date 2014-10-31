export function renderAvatar(user, options) {
  options = options || {};

  if (user) {
    var username = Em.get(user, 'username');
    if (!username) {
      if (!options.usernamePath) { return ''; }
      username = Em.get(user, options.usernamePath);
    }

    var title;
    if (!options.ignoreTitle) {
      // first try to get a title
      title = Em.get(user, 'title');
      // if there was no title provided
      if (!title) {
        // try to retrieve a description
        var description = Em.get(user, 'description');
        // if a description has been provided
        if (description && description.length > 0) {
          // preprend the username before the description
          title = username + " - " + description;
        }
      }
    }

    // this is simply done to ensure we cache images correctly
    var uploadedAvatarId = Em.get(user, 'uploaded_avatar_id') || Em.get(user, 'user.uploaded_avatar_id');
    var avatarTemplate = Discourse.User.avatarTemplate(username,uploadedAvatarId);

    return Discourse.Utilities.avatarImg({
      size: options.imageSize,
      extraClasses: Em.get(user, 'extras') || options.extraClasses,
      title: title || username,
      avatarTemplate: avatarTemplate
    });
  } else {
    return '';
  }
}

Handlebars.registerHelper('avatar', function(user, options) {
  if (typeof user === 'string') {
    user = Ember.Handlebars.get(this, user, options);
  }
  return new Handlebars.SafeString(renderAvatar.call(this, user, options.hash));
});
