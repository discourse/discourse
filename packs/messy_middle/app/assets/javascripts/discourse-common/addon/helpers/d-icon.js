import { htmlSafe } from "@ember/template";
import { registerUnbound } from "discourse-common/lib/helpers";
import { renderIcon } from "discourse-common/lib/icon-library";

registerUnbound("d-icon", function (id, params) {
  return htmlSafe(renderIcon("string", id, params));
});
