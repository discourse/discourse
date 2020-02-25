import { readOnly } from "@ember/object/computed";
import { computed } from "@ember/object";
import ComboBoxComponent from "select-kit/components/combo-box";
import DiscourseURL from "discourse/lib/url";
import Category from "discourse/models/category";
import { categoryBadgeHTML } from "discourse/helpers/category-link";

export const NO_CATEGORIES_ID = "no-categories";
export const ALL_CATEGORIES_ID = "all-categories";

export default ComboBoxComponent.extend({
  pluginApiIdentifiers: ["category-drop"],
  classNameBindings: ["categoryStyle"],
  classNames: ["category-drop"],
  value: readOnly("category.id"),
  content: readOnly("categoriesWithShortcuts.[]"),
  tagName: "li",
  categoryStyle: readOnly("siteSettings.category_style"),
  noCategoriesLabel: I18n.t("categories.no_subcategory"),

  selectKitOptions: {
    filterable: true,
    none: "category.all",
    caretDownIcon: "caret-right",
    caretUpIcon: "caret-down",
    fullWidthOnMobile: true,
    noSubcategories: false,
    subCategory: false,
    clearable: false,
    hideParentCategory: "hideParentCategory",
    allowUncategorized: true,
    countSubcategories: false,
    autoInsertNoneItem: false,
    displayCategoryDescription: "displayCategoryDescription",
    headerComponent: "category-drop/category-drop-header"
  },

  modifyComponentForRow() {
    return "category-row";
  },

  displayCategoryDescription: computed(function() {
    return !(
      this.get("currentUser.staff") || this.get("currentUser.trust_level") > 0
    );
  }),

  hideParentCategory: computed(function() {
    return this.options.subCategory || false;
  }),

  categoriesWithShortcuts: computed(
    "categories.[]",
    "value",
    "selectKit.options.{subCategory,noSubcategories}",
    function() {
      const shortcuts = [];

      if (
        this.value ||
        (this.selectKit.options.noSubcategories &&
          this.selectKit.options.subCategory)
      ) {
        shortcuts.push({
          id: ALL_CATEGORIES_ID,
          name: this.allCategoriesLabel
        });
      }

      if (
        this.selectKit.options.subCategory &&
        (this.value || !this.selectKit.options.noSubcategories)
      ) {
        shortcuts.push({
          id: NO_CATEGORIES_ID,
          name: this.noCategoriesLabel
        });
      }

      const results = this._filterUncategorized(this.categories || []);
      return shortcuts.concat(results);
    }
  ),

  modifyNoSelection() {
    if (this.selectKit.options.noSubcategories) {
      return this.defaultItem(NO_CATEGORIES_ID, this.noCategoriesLabel);
    } else {
      return this.defaultItem(ALL_CATEGORIES_ID, this.allCategoriesLabel);
    }
  },

  modifySelection(content) {
    if (this.value) {
      const category = Category.findById(this.value);
      content.title = category.title;
      content.label = categoryBadgeHTML(category, {
        link: false,
        allowUncategorized: this.selectKit.options.allowUncategorized,
        hideParent: true
      }).htmlSafe();
    }

    return content;
  },

  parentCategoryName: readOnly("selectKit.options.parentCategory.name"),

  parentCategoryUrl: readOnly("selectKit.options.parentCategory.url"),

  allCategoriesLabel: computed(
    "parentCategoryName",
    "selectKit.options.subCategory",
    function() {
      if (this.selectKit.options.subCategory) {
        return I18n.t("categories.all_subcategories", {
          categoryName: this.parentCategoryName
        });
      }

      return I18n.t("categories.all");
    }
  ),

  allCategoriesUrl: computed(
    "parentCategoryUrl",
    "selectKit.options.subCategory",
    function() {
      return Discourse.getURL(
        this.selectKit.options.subCategory ? this.parentCategoryUrl || "/" : "/"
      );
    }
  ),

  noCategoriesUrl: computed("parentCategoryUrl", function() {
    return Discourse.getURL(`${this.parentCategoryUrl}/none`);
  }),

  search(filter) {
    if (filter) {
      let results = Discourse.Category.search(filter);
      results = this._filterUncategorized(results).sort((a, b) => {
        if (a.parent_category_id && !b.parent_category_id) {
          return 1;
        } else if (!a.parent_category_id && b.parent_category_id) {
          return -1;
        } else {
          return 0;
        }
      });
      return results;
    } else {
      return this._filterUncategorized(this.content);
    }
  },

  actions: {
    onChange(value) {
      let categoryURL;

      if (value === ALL_CATEGORIES_ID) {
        categoryURL = this.allCategoriesUrl;
      } else if (value === NO_CATEGORIES_ID) {
        categoryURL = this.noCategoriesUrl;
      } else {
        const categoryId = parseInt(value, 10);
        const category = Category.findById(categoryId);
        const slug = Discourse.Category.slugFor(category);
        categoryURL = `/c/${slug}`;
      }

      DiscourseURL.routeToUrl(categoryURL);

      return false;
    }
  },

  _filterUncategorized(content) {
    if (
      !this.siteSettings.allow_uncategorized_topics ||
      !this.selectKit.options.allowUncategorized
    ) {
      content = content.filter(
        c => c.id !== this.site.uncategorized_category_id
      );
    }

    return content;
  }
});
