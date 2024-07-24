import { htmlSafe } from "@ember/template";
import deprecated from "discourse-common/lib/deprecated";
import { registerRawHelper } from "discourse-common/lib/helpers";
import { renderIcon } from "discourse-common/lib/icon-library";

export function iconHTML(id, params) {
  return renderIcon("string", id, params);
}

registerRawHelper("fa-icon", faIcon);
export default function faIcon(icon, params) {
  deprecated("Use `{{d-icon}}` instead of `{{fa-icon}}", {
    id: "discourse.fa-icon",
  });
  return htmlSafe(iconHTML(icon, params));
}
