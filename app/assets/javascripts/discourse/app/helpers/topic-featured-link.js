import { htmlSafe } from "@ember/template";
import renderTopicFeaturedLink from "discourse/lib/render-topic-featured-link";
import { registerRawHelper } from "discourse-common/lib/helpers";

registerRawHelper("topic-featured-link", topicFeaturedLink);
export default function topicFeaturedLink(topic, params) {
  return htmlSafe(renderTopicFeaturedLink(topic, params));
}
