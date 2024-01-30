import { htmlSafe } from "@ember/template";
import { isEmpty } from "@ember/utils";
import { convertIconClass, iconHTML } from "discourse-common/lib/icon-library";

export default function iconOrImage({ icon, image }) {
  if (!isEmpty(image)) {
    return htmlSafe(`<img src='${image}'>`);
  }

  if (isEmpty(icon)) {
    return "";
  }

  return htmlSafe(iconHTML(convertIconClass(icon)));
}
