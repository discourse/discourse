import { iconHTML } from 'discourse/helpers/fa-icon';

const Safe = Handlebars.SafeString;

export default Ember.Handlebars.makeBoundHelper(function(user, args) {
  if (!user) { return; }

  const name = Discourse.Utilities.escapeExpression(user.get('name'));
  const currentUser = args.hash.currentUser;

  if (currentUser && user.get('admin') && currentUser.get('staff')) {
    return new Safe(iconHTML('shield', { label: I18n.t('user.admin', { user: name }) }));
  }
  if (user.get('moderator')) {
    return new Safe(iconHTML('shield', { label: I18n.t('user.moderator', { user: name }) }));
  }
});
