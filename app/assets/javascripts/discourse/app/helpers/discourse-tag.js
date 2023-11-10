import { htmlSafe } from "@ember/template";
import renderTag from "discourse/lib/render-tag";
import { registerRawHelper } from "discourse-common/lib/helpers";

registerRawHelper("discourse-tag", discourseTag);
export default function discourseTag(name, params) {
  return htmlSafe(renderTag(name, params));
}
