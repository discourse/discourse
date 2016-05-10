import { htmlHelper } from 'discourse/lib/helpers';

export default htmlHelper((user, size) => {
  if (Ember.isEmpty(user)) {
    return "<div class='avatar-placeholder'></div>";
  }

  const avatarTemplate = Em.get(user, 'avatar_template');
  return Discourse.Utilities.avatarImg({ size, avatarTemplate });
});
