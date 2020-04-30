import { registerUnbound } from "discourse-common/lib/helpers";
import renderTags from "discourse/lib/render-tags";
import { htmlSafe } from "@ember/template";

export default registerUnbound("discourse-tags", function(topic, params) {
  return htmlSafe(renderTags(topic, params));
});
