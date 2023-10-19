import { get } from "@ember/object";
import Category from "discourse/models/category";

export default {
  after: "category-color-css-generator",

  /**
   * This generates badge CSS classes for each category,
   * which can be used in themes to render category-specific elements.
   */
  initialize(owner) {
    this.site = owner.lookup("service:site");

    // If the site is login_required and the user is anon there will be no categories preloaded.
    if (!this.site.categories) {
      return;
    }

    const generatedCssClasses = this.site.categories.map((category) => {
      let parentCat = Category.findById(get(category, "parent_category_id"));
      let badgeClass = `.badge-category.badge-category-${category.id} { --category-badge-color: var(--category-${category.id}-color); --category-badge-text-color: #${category.text_color} }`;
      if (parentCat) {
        badgeClass += `.badge-category.badge-subcategory-${parentCat.id} { --parent-category-badge-color: var(--category-${parentCat.id}-color); }`;
      }
      return badgeClass;
    });

    const cssTag = document.createElement("style");
    cssTag.type = "text/css";
    cssTag.id = "category-badge-css-generator";
    cssTag.innerHTML = generatedCssClasses.join("\n");
    document.head.appendChild(cssTag);
  },
};
