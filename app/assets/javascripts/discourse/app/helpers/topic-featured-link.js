import { registerUnbound } from "discourse-common/lib/helpers";
import renderTopicFeaturedLink from "discourse/lib/render-topic-featured-link";
import { htmlSafe } from "@ember/template";

export default registerUnbound("topic-featured-link", function(topic, params) {
  return htmlSafe(renderTopicFeaturedLink(topic, params));
});
