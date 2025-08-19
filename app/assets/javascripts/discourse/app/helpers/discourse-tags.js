import { htmlSafe } from "@ember/template";
import renderTags from "discourse/lib/render-tags";

export default function discourseTags(topic, params) {
  return htmlSafe(renderTags(topic, params));
}
