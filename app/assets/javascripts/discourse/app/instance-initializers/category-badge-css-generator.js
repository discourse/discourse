import { get } from "@ember/object";
import Category from "discourse/models/category";

export default {
  after: "category-color-css-generator",

  // This generates badge CSS for each category, which is used to render category-specific elements.
  initialize(owner) {
    this.site = owner.lookup("service:site");

    // If the site is login_required and the user is anon there will be no categories preloaded.
    if (!this.site.categories?.length) {
      return;
    }

    const generatedCss = this.site.categories.map((category) => {
      let parentCategory = Category.findById(
        get(category, "parent_category_id")
      );
      let badgeCss = `.badge-category[data-category-id="${category.id}"] { --category-badge-color: var(--category-${category.id}-color); --category-badge-text-color: #${category.text_color}; }`;
      if (parentCategory) {
        badgeCss += `.badge-category[data-parent-category-id="${parentCategory.id}"] { --parent-category-badge-color: var(--category-${parentCategory.id}-color); }`;
      }
      return badgeCss;
    });

    const cssTag = document.createElement("style");
    cssTag.type = "text/css";
    cssTag.id = "category-badge-css-generator";
    cssTag.innerHTML = generatedCss.join("\n");
    document.head.appendChild(cssTag);
  },
};
