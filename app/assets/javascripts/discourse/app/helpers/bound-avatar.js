import { addExtraUserClasses } from "discourse/helpers/user-avatar";
import { avatarImg } from "discourse/lib/utilities";
import { isEmpty } from "@ember/utils";

export default function boundAvatar(user, size) {
  if (isEmpty(user)) {
    return "<div class='avatar-placeholder'></div>";
  }

  return avatarImg(
    addExtraUserClasses(user, { size, avatarTemplate: user.avatar_template })
  );
}
