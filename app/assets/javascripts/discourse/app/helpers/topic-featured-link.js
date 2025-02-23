import { htmlSafe } from "@ember/template";
import { registerRawHelper } from "discourse/lib/helpers";
import renderTopicFeaturedLink from "discourse/lib/render-topic-featured-link";

registerRawHelper("topic-featured-link", topicFeaturedLink);
export default function topicFeaturedLink(topic, params) {
  return htmlSafe(renderTopicFeaturedLink(topic, params));
}
