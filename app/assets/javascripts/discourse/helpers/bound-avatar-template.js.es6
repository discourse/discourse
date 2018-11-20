import { htmlHelper } from "discourse-common/lib/helpers";
import { avatarImg } from "discourse/lib/utilities";

export default htmlHelper((avatarTemplate, size) => {
  if (Ember.isEmpty(avatarTemplate)) {
    return "<div class='avatar-placeholder'></div>";
  } else {
    return avatarImg({ size, avatarTemplate });
  }
});
