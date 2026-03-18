import { trustHTML } from "@ember/template";
import { isEmpty } from "@ember/utils";
import { addExtraUserClasses } from "discourse/helpers/user-avatar";
import { avatarImg } from "discourse/lib/avatar-utils";

export default function dBoundAvatar(user, size) {
  if (isEmpty(user)) {
    return trustHTML("<div class='avatar-placeholder'></div>");
  }

  return trustHTML(
    avatarImg(
      addExtraUserClasses(user, { size, avatarTemplate: user.avatar_template })
    )
  );
}
