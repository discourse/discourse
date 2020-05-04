import { categoryLinkHTML } from "discourse/helpers/category-link";
import { registerUnbound } from "discourse-common/lib/helpers";

registerUnbound("category-badge", function(cat, options) {
  return categoryLinkHTML(cat, {
    hideParent: options.hideParent,
    allowUncategorized: options.allowUncategorized,
    categoryStyle: options.categoryStyle,
    link: false
  });
});
