import { htmlSafe } from "@ember/template";
import { renderIcon } from "discourse/lib/icon-library";

export default function icon(id, options = {}) {
  return htmlSafe(renderIcon("string", id, options));
}
