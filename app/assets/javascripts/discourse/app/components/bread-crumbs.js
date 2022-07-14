import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";

//  A breadcrumb including category drop downs
export default Component.extend({
  classNameBindings: ["hidden:hidden", ":category-breadcrumb"],
  tagName: "ol",
  editingCategory: false,
  editingCategoryTab: null,

  @discourseComputed("categories")
  filteredCategories(categories) {
    return categories.filter(
      (category) =>
        this.siteSettings.allow_uncategorized_topics ||
        category.id !== this.site.uncategorized_category_id
    );
  },

  @discourseComputed(
    "category.ancestors",
    "filteredCategories",
    "noSubcategories"
  )
  categoryBreadcrumbs(categoryAncestors, filteredCategories, noSubcategories) {
    categoryAncestors = categoryAncestors || [];
    const parentCategories = [undefined, ...categoryAncestors];
    const categories = [...categoryAncestors, undefined];
    const zipped = parentCategories.map((x, i) => [x, categories[i]]);

    return zipped.map((record) => {
      const [parentCategory, category] = record;

      const options = filteredCategories.filter(
        (c) =>
          c.get("parentCategory.id") === (parentCategory && parentCategory.id)
      );

      return {
        category,
        parentCategory,
        options,
        isSubcategory: !!parentCategory,
        noSubcategories: !category && noSubcategories,
        hasOptions: options.length !== 0,
      };
    });
  },

  @discourseComputed("siteSettings.tagging_enabled", "editingCategory")
  showTagsSection(taggingEnabled, editingCategory) {
    return taggingEnabled && !editingCategory;
  },

  @discourseComputed("category")
  hidden(category) {
    return this.site.mobileView && !category;
  },
});
