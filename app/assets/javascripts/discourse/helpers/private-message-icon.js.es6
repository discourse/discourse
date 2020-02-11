import { registerUnbound } from "discourse-common/lib/helpers";
import { iconHTML } from "discourse-common/lib/icon-library";

export default registerUnbound("private-message-icon", function(archetype) {
  if (archetype === "private_message") {
    return new Handlebars.SafeString(iconHTML("envelope"));
  } else {
    return "";
  }
});
