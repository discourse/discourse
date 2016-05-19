import { iconHTML } from 'discourse/helpers/fa-icon';
import { htmlHelper } from 'discourse/lib/helpers';

export default htmlHelper((user, args) => {
  if (!user) { return; }

  const name = Discourse.Utilities.escapeExpression(user.get('name'));
  const currentUser = args.hash.currentUser;

  if (currentUser && user.get('admin') && currentUser.get('staff')) {
    return iconHTML('shield', { label: I18n.t('user.admin', { user: name }) });
  }
  if (user.get('moderator')) {
    return iconHTML('shield', { label: I18n.t('user.moderator', { user: name }) });
  }
});
