import { convertIconClass, iconHTML } from "discourse-common/lib/icon-library";
import { isEmpty } from "@ember/utils";

export default function iconOrImage({ icon, image }) {
  if (!isEmpty(image)) {
    return `<img src='${image}'>`;
  }

  if (isEmpty(icon)) {
    return "";
  }

  return iconHTML(convertIconClass(icon));
}
