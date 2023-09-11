import Category from "discourse/models/category";
import { get } from "@ember/object";

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

    const generatedCssClasses = [
      this.site.categories.map((category) => {
        let parentCat = Category.findById(get(category, "parent_category_id"));
        let badgeClass = `
          .badge-category.badge-category-${category.id}:before {
            background: var(--category-${category.id}-color);
          }`;
        if (parentCat) {
          badgeClass += `
            .badge-category.badge-subcategory-${parentCat.id}:before {
              background: linear-gradient(90deg, var(--category-${parentCat.id}-color) 50%, var(--category-${category.id}-color) 50%);
            }`;
        }
        return badgeClass;
      }),
    ];

    const cssTag = document.createElement("style");
    cssTag.type = "text/css";
    cssTag.id = "category-badge-css-generator";
    cssTag.innerHTML = generatedCssClasses.join("\n");
    document.head.appendChild(cssTag);
  },
};
