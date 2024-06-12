import { htmlSafe } from "@ember/template";
import { isEmpty } from "@ember/utils";
import { convertIconClass, iconHTML } from "discourse-common/lib/icon-library";

export default function iconOrImage(badge) {
  const icon = badge.get("icon");
  const image = badge.get("image");

  if (!isEmpty(image)) {
    return htmlSafe(`<img src='${image}'>`);
  }

  if (isEmpty(icon)) {
    return "";
  }

  return htmlSafe(iconHTML(convertIconClass(icon)));
}
