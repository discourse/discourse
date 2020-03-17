import { registerUnbound } from "discourse-common/lib/helpers";
import { renderIcon } from "discourse-common/lib/icon-library";

registerUnbound("check-icon", function(value) {
  let icon = value ? "check" : "times";
  return new Handlebars.SafeString(renderIcon("string", icon));
});
