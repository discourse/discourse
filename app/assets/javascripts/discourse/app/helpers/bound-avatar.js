import { htmlSafe } from "@ember/template";
import { addExtraUserClasses } from "discourse/helpers/user-avatar";
import { avatarImg } from "discourse-common/lib/avatar-utils";
import { isEmpty } from "@ember/utils";

export default function boundAvatar(user, size) {
  if (isEmpty(user)) {
    return htmlSafe("<div class='avatar-placeholder'></div>");
  }

  return htmlSafe(
    avatarImg(
      addExtraUserClasses(user, { size, avatarTemplate: user.avatar_template })
    )
  );
}
