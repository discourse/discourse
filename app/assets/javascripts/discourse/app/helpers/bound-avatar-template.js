import { htmlSafe } from "@ember/template";
import { avatarImg } from "discourse-common/lib/avatar-utils";
import { isEmpty } from "@ember/utils";

export default function boundAvatarTemplate(avatarTemplate, size) {
  if (isEmpty(avatarTemplate)) {
    return htmlSafe("<div class='avatar-placeholder'></div>");
  } else {
    return htmlSafe(avatarImg({ size, avatarTemplate }));
  }
}
