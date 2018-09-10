import { registerUnbound } from "discourse-common/lib/helpers";
import { renderIcon } from "discourse-common/lib/icon-library";

registerUnbound("d-icon", function(id, params) {
  return new Handlebars.SafeString(renderIcon("string", id, params));
});
