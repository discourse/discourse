import { htmlSafe } from "@ember/template";

export default function categoryColorVariable(color) {
  return htmlSafe(`--category-badge-color: #${color};`);
}
