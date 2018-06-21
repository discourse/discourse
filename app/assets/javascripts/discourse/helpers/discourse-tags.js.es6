import { registerUnbound } from "discourse-common/lib/helpers";
import renderTags from "discourse/lib/render-tags";

export default registerUnbound("discourse-tags", function(topic, params) {
  return new Handlebars.SafeString(renderTags(topic, params));
});
