import { registerUnbound } from "discourse-common/lib/helpers";
import { renderIcon } from "discourse-common/lib/icon-library";
import deprecated from "discourse-common/lib/deprecated";

export function iconHTML(id, params) {
  return renderIcon("string", id, params);
}

registerUnbound("fa-icon", function(icon, params) {
  deprecated("Use `{{d-icon}}` instead of `{{fa-icon}}");
  return new Handlebars.SafeString(iconHTML(icon, params));
});
