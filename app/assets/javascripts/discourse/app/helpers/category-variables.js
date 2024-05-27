import { htmlSafe } from "@ember/template";

export default function categoryVariables(category) {
  let vars = "";

  if (category.color) {
    vars += `--category-badge-color: #${category.color};`;
  }

  if (category.text_color) {
    vars += `--category-badge-text-color: #${category.text_color};`;
  }

  if (category.parentCategory?.color) {
    vars += `--parent-category-badge-color: #${category.parentCategory.color};`;
  }

  if (category.parentCategory?.text_color) {
    vars += `--parent-category-badge-text-color: #${category.parentCategory.text_color};`;
  }

  return htmlSafe(vars);
}
