import Component from "@ember/component";
import { filter } from "@ember/object/computed";
import { classNameBindings, tagName } from "@ember-decorators/component";
import discourseComputed from "discourse/lib/decorators";
import deprecated from "discourse/lib/deprecated";

//  A breadcrumb including category drop downs
@tagName("ol")
@classNameBindings("hidden:hidden", ":category-breadcrumb")
export default class BreadCrumbs extends Component {
  editingCategory = false;
  editingCategoryTab = null;

  @filter("categories", function (c) {
    deprecated(
      "The parentCategories property of the bread-crumbs component is deprecated",
      { id: "discourse.breadcrumbs.parentCategories" }
    );
    if (
      c.id === this.site.get("uncategorized_category_id") &&
      !this.siteSettings.allow_uncategorized_topics
    ) {
      // Don't show "uncategorized" if allow_uncategorized_topics setting is false.
      return false;
    }

    return !c.get("parentCategory");
  })
  parentCategories;

  @discourseComputed("category", "categories", "noSubcategories")
  categoryBreadcrumbs(category, filteredCategories, noSubcategories) {
    const ancestors = category?.ancestors || [];
    const parentCategories = [undefined, ...ancestors];
    const categories = [...ancestors, undefined];

    return parentCategories
      .map((x, i) => [x, categories[i]])
      .map((record) => {
        const [parentCategory, subCategory] = record;

        const options = filteredCategories.filter(
          (c) =>
            c.get("parentCategory.id") === (parentCategory && parentCategory.id)
        );

        return {
          category: subCategory,
          parentCategory,
          options,
          isSubcategory: !!parentCategory,
          noSubcategories: !subCategory && noSubcategories,
          hasOptions: !parentCategory || parentCategory.has_children,
        };
      });
  }

  @discourseComputed("siteSettings.tagging_enabled", "editingCategory")
  showTagsSection(taggingEnabled, editingCategory) {
    return taggingEnabled && !editingCategory;
  }

  @discourseComputed("category")
  parentCategory(category) {
    deprecated(
      "The parentCategory property of the bread-crumbs component is deprecated",
      { id: "discourse.breadcrumbs.parentCategory" }
    );
    return category && category.parentCategory;
  }

  @discourseComputed("parentCategories")
  parentCategoriesSorted(parentCategories) {
    deprecated(
      "The parentCategoriesSorted property of the bread-crumbs component is deprecated",
      { id: "discourse.breadcrumbs.parentCategoriesSorted" }
    );
    if (this.siteSettings.fixed_category_positions) {
      return parentCategories;
    }

    return parentCategories.sortBy("totalTopicCount").reverse();
  }

  @discourseComputed("category")
  hidden(category) {
    return this.site.mobileView && !category;
  }

  @discourseComputed("category", "parentCategory")
  firstCategory(category, parentCategory) {
    deprecated(
      "The firstCategory property of the bread-crumbs component is deprecated",
      { id: "discourse.breadcrumbs.firstCategory" }
    );
    return parentCategory || category;
  }

  @discourseComputed("category", "parentCategory")
  secondCategory(category, parentCategory) {
    deprecated(
      "The secondCategory property of the bread-crumbs component is deprecated",
      { id: "discourse.breadcrumbs.secondCategory" }
    );
    return parentCategory && category;
  }

  @discourseComputed("firstCategory", "hideSubcategories")
  childCategories(firstCategory, hideSubcategories) {
    deprecated(
      "The childCategories property of the bread-crumbs component is deprecated",
      { id: "discourse.breadcrumbs.childCategories" }
    );
    if (hideSubcategories) {
      return [];
    }

    if (!firstCategory) {
      return [];
    }

    return this.categories.filter(
      (c) => c.get("parentCategory") === firstCategory
    );
  }
}
