import { htmlHelper } from 'discourse-common/lib/helpers';
import { avatarImg } from 'discourse/lib/utilities';
import { classesForUser } from 'discourse/helpers/user-avatar';

export default htmlHelper((user, size) => {
  if (Ember.isEmpty(user)) {
    return "<div class='avatar-placeholder'></div>";
  }

  const avatarTemplate = Em.get(user, 'avatar_template');
  let args = { size, avatarTemplate };
  let extraClasses = classesForUser(user).join(' ');
  if (extraClasses && extraClasses.length) {
    args.extraClasses = extraClasses;
  }
  return avatarImg(args);
});
