import { addExtraUserClasses } from "discourse/helpers/user-avatar";
import { avatarImg } from "discourse-common/lib/avatar-utils";
import { get } from "@ember/object";
import { htmlHelper } from "discourse-common/lib/helpers";
import { isEmpty } from "@ember/utils";

export default htmlHelper((user, size) => {
  if (isEmpty(user)) {
    return "<div class='avatar-placeholder'></div>";
  }

  const avatarTemplate = get(user, "avatar_template");
  return avatarImg(addExtraUserClasses(user, { size, avatarTemplate }));
});
