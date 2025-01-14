import { htmlSafe } from "@ember/template";
import { registerRawHelper } from "discourse/lib/helpers";
import renderTags from "discourse/lib/render-tags";

registerRawHelper("discourse-tags", discourseTags);
export default function discourseTags(topic, params) {
  return htmlSafe(renderTags(topic, params));
}
