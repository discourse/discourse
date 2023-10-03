import { convertIconClass, iconHTML } from "discourse-common/lib/icon-library";
import { isEmpty } from "@ember/utils";
import { htmlSafe } from "@ember/template";

export default function iconOrImage({ icon, image }) {
  if (!isEmpty(image)) {
    return htmlSafe(`<img src='${image}'>`);
  }

  if (isEmpty(icon)) {
    return "";
  }

  return htmlSafe(iconHTML(convertIconClass(icon)));
}
