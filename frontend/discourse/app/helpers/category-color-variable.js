import { trustHTML } from "@ember/template";

export default function categoryColorVariable(color) {
  return trustHTML(`--category-badge-color: #${color};`);
}
