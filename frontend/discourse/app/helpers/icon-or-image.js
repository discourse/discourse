import { get } from "@ember/object";
import { trustHTML } from "@ember/template";
import { isEmpty } from "@ember/utils";
import { convertIconClass, iconHTML } from "discourse/lib/icon-library";

export default function iconOrImage(badge) {
  const icon = get(badge, "icon");
  const image = get(badge, "image");

  if (!isEmpty(image)) {
    return trustHTML(`<img src='${image}'>`);
  }

  if (isEmpty(icon)) {
    return "";
  }

  return trustHTML(iconHTML(convertIconClass(icon)));
}
