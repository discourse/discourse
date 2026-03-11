import { trustHTML } from "@ember/template";
import { isEmpty } from "@ember/utils";
import { avatarImg } from "discourse/lib/avatar-utils";

export default function boundAvatarTemplate(avatarTemplate, size, options) {
  if (isEmpty(avatarTemplate)) {
    return trustHTML("<div class='avatar-placeholder'></div>");
  } else {
    return trustHTML(avatarImg({ size, avatarTemplate, ...options }));
  }
}
