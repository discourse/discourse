import { isPresent } from "@ember/utils";
import {
  type CategoryBadgeCategory,
  type CategoryBadgeOptions,
  categoryLinkHTML,
} from "discourse/ui-kit/helpers/d-category-link";

/**
 * Renders a category badge, without a link unless one is asked for.
 *
 * @param cat - The category.
 * @param options - The badge options.
 * @returns The badge HTML.
 */
export default function dCategoryBadge(
  cat: CategoryBadgeCategory | null | undefined,
  options: CategoryBadgeOptions & {
    /** Passed on, though `categoryLinkHTML` doesn't read it. */
    categoryStyle?: string;
  } = {}
) {
  // `categoryLinkHTML` ignores `categoryStyle`.
  return categoryLinkHTML(cat, {
    hideParent: options.hideParent,
    ancestors: options.ancestors,
    allowUncategorized: options.allowUncategorized,
    categoryStyle: options.categoryStyle,
    styleType: options.styleType,
    icon: options.icon,
    emoji: options.emoji,
    previewColor: options.previewColor,
    link: isPresent(options.link) ? options.link : false,
  } as CategoryBadgeOptions);
}
