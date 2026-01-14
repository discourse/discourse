import { htmlSafe } from "@ember/template";
import deprecated from "discourse/lib/deprecated";
import { renderIcon } from "discourse/lib/icon-library";

export function iconHTML(id, params) {
  return renderIcon("string", id, params);
}

export default function faIcon(icon, params) {
  deprecated("Use `{{d-icon}}` instead of `{{fa-icon}}", {
    id: "discourse.fa-icon",
  });
  return htmlSafe(iconHTML(icon, params));
}
