import { trustHTML } from "@ember/template";
import renderTags from "discourse/lib/render-tags";

export default function dDiscourseTags(topic, params) {
  return trustHTML(renderTags(topic, params));
}
