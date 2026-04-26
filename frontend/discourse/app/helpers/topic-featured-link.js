import { trustHTML } from "@ember/template";
import renderTopicFeaturedLink from "discourse/lib/render-topic-featured-link";

export default function topicFeaturedLink(topic, params) {
  return trustHTML(renderTopicFeaturedLink(topic, params));
}
