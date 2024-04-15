import { htmlSafe } from "@ember/template";
import renderTags from "discourse/lib/render-tags";
import { registerRawHelper } from "discourse-common/lib/helpers";

registerRawHelper("discourse-tags", discourseTags);
export default function discourseTags(topic, params) {
  return htmlSafe(renderTags(topic, params));
}
