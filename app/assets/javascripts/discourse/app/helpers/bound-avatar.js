import { htmlSafe } from "@ember/template";
import { isEmpty } from "@ember/utils";
import { addExtraUserClasses } from "discourse/helpers/user-avatar";
import { avatarImg } from "discourse/lib/avatar-utils";

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
