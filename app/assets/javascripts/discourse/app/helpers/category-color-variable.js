import { htmlSafe } from "@ember/template";

export default function categoryColorVariable(color) {
  return htmlSafe(`--category-color: #${color};`);
}
