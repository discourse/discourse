import { htmlHelper } from 'discourse/lib/helpers';
import { avatarImg } from 'discourse/lib/utilities';

export default htmlHelper((user, size) => {
  if (Ember.isEmpty(user)) {
    return "<div class='avatar-placeholder'></div>";
  }

  const avatarTemplate = Em.get(user, 'avatar_template');
  return avatarImg({ size, avatarTemplate });
});
