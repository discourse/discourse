import { htmlSafe } from "@ember/template";
import { registerRawHelper } from "discourse/lib/helpers";
import renderTag from "discourse/lib/render-tag";

registerRawHelper("discourse-tag", discourseTag);
export default function discourseTag(name, params) {
  return htmlSafe(renderTag(name, params));
}
