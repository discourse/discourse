import { get } from "@ember/object";
import { trustHTML } from "@ember/template";
import { isEmpty } from "@ember/utils";
import { convertIconClass, iconHTML } from "discourse/lib/icon-library";

/**
 * Renders a badge's image, or else its icon.
 *
 * @param badge - The badge, or anything with an `icon` class name and an `image` URL.
 * @returns The trusted markup, or `""` when there is neither.
 */
export default function dIconOrImage(badge: {
  icon?: string | null;
  image?: string | null;
}) {
  const icon = get(badge, "icon");
  const image = get(badge, "image");

  if (!isEmpty(image)) {
    return trustHTML(`<img src='${image}' alt=''>`);
  }

  if (isEmpty(icon)) {
    return "";
  }

  // `isEmpty` ruled out a missing icon.
  return trustHTML(iconHTML(convertIconClass(icon as string)));
}
