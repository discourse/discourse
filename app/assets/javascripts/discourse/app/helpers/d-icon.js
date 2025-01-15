import { htmlSafe } from "@ember/template";
import { registerRawHelper } from "discourse/lib/helpers";
import { renderIcon } from "discourse/lib/icon-library";

export default function icon(id, options = {}) {
  return htmlSafe(renderIcon("string", id, options));
}

registerRawHelper("d-icon", icon);
