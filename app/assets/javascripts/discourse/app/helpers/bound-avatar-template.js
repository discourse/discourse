import { avatarImg } from "discourse/lib/utilities";
import { isEmpty } from "@ember/utils";

export default function boundAvatarTemplate(avatarTemplate, size) {
  if (isEmpty(avatarTemplate)) {
    return "<div class='avatar-placeholder'></div>";
  } else {
    return avatarImg({ size, avatarTemplate });
  }
}
