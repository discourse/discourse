import { htmlSafe } from "@ember/template";
import renderTopicFeaturedLink from "discourse/lib/render-topic-featured-link";
import { registerUnbound } from "discourse-common/lib/helpers";

export default registerUnbound("topic-featured-link", function (topic, params) {
  return htmlSafe(renderTopicFeaturedLink(topic, params));
});
