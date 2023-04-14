import { htmlSafe } from "@ember/template";
import { registerUnbound } from "discourse-common/lib/helpers";
import renderTopicFeaturedLink from "discourse/lib/render-topic-featured-link";

export default registerUnbound("topic-featured-link", function (topic, params) {
  return htmlSafe(renderTopicFeaturedLink(topic, params));
});
