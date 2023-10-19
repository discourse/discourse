import { htmlSafe } from "@ember/template";
import renderTag from "discourse/lib/render-tag";
import { registerUnbound } from "discourse-common/lib/helpers";

export default registerUnbound("discourse-tag", function (name, params) {
  return htmlSafe(renderTag(name, params));
});
