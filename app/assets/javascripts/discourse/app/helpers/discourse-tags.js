import { htmlSafe } from "@ember/template";
import renderTags from "discourse/lib/render-tags";
import { registerUnbound } from "discourse-common/lib/helpers";

export default registerUnbound("discourse-tags", function (topic, params) {
  return htmlSafe(renderTags(topic, params));
});
