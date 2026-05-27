import { trustHTML } from "@ember/template";
import { renderIcon } from "discourse/lib/icon-library";

export default function icon(id, options = {}) {
  return trustHTML(renderIcon("string", id, options));
}
