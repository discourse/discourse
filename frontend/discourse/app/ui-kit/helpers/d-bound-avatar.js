import { trustHTML } from "@ember/template";
import { isEmpty } from "@ember/utils";
import { avatarImg } from "discourse/lib/avatar-utils";
import { addExtraUserClasses } from "discourse/ui-kit/helpers/d-user-avatar";

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
