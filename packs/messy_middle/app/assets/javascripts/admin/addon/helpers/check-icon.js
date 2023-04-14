import { htmlSafe } from "@ember/template";
import { registerUnbound } from "discourse-common/lib/helpers";
import { renderIcon } from "discourse-common/lib/icon-library";

registerUnbound("check-icon", function (value) {
  let icon = value ? "check" : "times";
  return htmlSafe(renderIcon("string", icon));
});
