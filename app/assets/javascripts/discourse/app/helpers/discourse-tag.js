import { htmlSafe } from "@ember/template";
import renderTag from "discourse/lib/render-tag";

export default function discourseTag(name, params) {
  return htmlSafe(renderTag(name, params));
}
