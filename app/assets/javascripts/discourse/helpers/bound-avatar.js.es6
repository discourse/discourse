import { htmlHelper } from "discourse-common/lib/helpers";
import { avatarImg } from "discourse/lib/utilities";
import { addExtraUserClasses } from "discourse/helpers/user-avatar";

export default htmlHelper((user, size) => {
  if (Ember.isEmpty(user)) {
    return "<div class='avatar-placeholder'></div>";
  }

  const avatarTemplate = Ember.get(user, "avatar_template");
  return avatarImg(addExtraUserClasses(user, { size, avatarTemplate }));
});
