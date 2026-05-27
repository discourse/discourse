import { isPresent } from "@ember/utils";
import { categoryLinkHTML } from "discourse/ui-kit/helpers/d-category-link";

export default function dCategoryBadge(cat, options = {}) {
  return categoryLinkHTML(cat, {
    hideParent: options.hideParent,
    allowUncategorized: options.allowUncategorized,
    categoryStyle: options.categoryStyle,
    styleType: options.styleType,
    icon: options.icon,
    emoji: options.emoji,
    previewColor: options.previewColor,
    link: isPresent(options.link) ? options.link : false,
  });
}
