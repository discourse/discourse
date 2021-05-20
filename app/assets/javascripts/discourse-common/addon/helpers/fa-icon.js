import deprecated from "discourse-common/lib/deprecated";
import { htmlSafe } from "@ember/template";
import { registerUnbound } from "discourse-common/lib/helpers";
import { renderIcon } from "discourse-common/lib/icon-library";

export function iconHTML(id, params) {
  return renderIcon("string", id, params);
}

registerUnbound("fa-icon", function (icon, params) {
  deprecated("Use `{{d-icon}}` instead of `{{fa-icon}}");
  return htmlSafe(iconHTML(icon, params));
});
