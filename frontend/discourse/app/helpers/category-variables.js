import { htmlSafe } from "@ember/template";

export default function categoryVariables(category) {
  let vars = "";

  if (category.color) {
    vars += `--category-badge-color: #${category.color};`;
  }

  if (category.textColor) {
    vars += `--category-badge-text-color: #${category.textColor};`;
  }

  if (category.parentCategory?.color) {
    vars += `--parent-category-badge-color: #${category.parentCategory.color};`;
  }

  if (category.parentCategory?.textColor) {
    vars += `--parent-category-badge-text-color: #${category.parentCategory.textColor};`;
  }

  return htmlSafe(vars);
}
