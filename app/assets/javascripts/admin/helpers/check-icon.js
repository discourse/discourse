import { registerUnbound } from "discourse-common/lib/helpers";
import { renderIcon } from "discourse-common/lib/icon-library";
import { htmlSafe } from "@ember/template";

registerUnbound("check-icon", function(value) {
  let icon = value ? "check" : "times";
  return htmlSafe(renderIcon("string", icon));
});
