import { isPresent } from "@ember/utils";
import { categoryLinkHTML } from "discourse/helpers/category-link";
import { registerRawHelper } from "discourse/lib/helpers";

registerRawHelper("category-badge", categoryBadge);

export default function categoryBadge(cat, options = {}) {
  return categoryLinkHTML(cat, {
    hideParent: options.hideParent,
    allowUncategorized: options.allowUncategorized,
    categoryStyle: options.categoryStyle,
    link: isPresent(options.link) ? options.link : false,
  });
}
