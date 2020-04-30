import { registerUnbound } from "discourse-common/lib/helpers";
import renderTag from "discourse/lib/render-tag";
import { htmlSafe } from "@ember/template";

export default registerUnbound("discourse-tag", function(name, params) {
  return htmlSafe(renderTag(name, params));
});
