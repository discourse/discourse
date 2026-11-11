import { trustHTML } from "@ember/template";

/**
 * Builds the CSS custom properties that color a category badge.
 *
 * @param category - The category, with its colors and its parent's.
 * @returns The trusted declarations, empty when there are no colors.
 */
export default function categoryVariables(category: {
  /** The badge color, as hex digits without the `#`. */
  color?: string | null;
  /** The badge text color, as hex digits without the `#`. */
  textColor?: string | null;
  /** The parent category, whose colors are set too. */
  parentCategory?: {
    /** The parent's badge color. */
    color?: string | null;
    /** The parent's badge text color. */
    textColor?: string | null;
  } | null;
}) {
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

  return trustHTML(vars);
}
