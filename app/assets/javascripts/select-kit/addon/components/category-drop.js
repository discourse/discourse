import Category from "discourse/models/category";
import ComboBoxComponent from "select-kit/components/combo-box";
import DiscourseURL, {
  getCategoryAndTagUrl,
  getEditCategoryUrl,
} from "discourse/lib/url";
import I18n from "I18n";
import { categoryBadgeHTML } from "discourse/helpers/category-link";
import { computed } from "@ember/object";
import { readOnly } from "@ember/object/computed";
import { htmlSafe } from "@ember/template";

export const NO_CATEGORIES_ID = "no-categories";
export const ALL_CATEGORIES_ID = "all-categories";

export default ComboBoxComponent.extend({
  pluginApiIdentifiers: ["category-drop"],
  classNameBindings: ["categoryStyle"],
  classNames: ["category-drop"],
  value: readOnly("category.id"),
  content: readOnly("categoriesWithShortcuts.[]"),
  categoryStyle: readOnly("siteSettings.category_style"),
  noCategoriesLabel: I18n.t("categories.no_subcategory"),
  navigateToEdit: false,
  editingCategory: false,
  editingCategoryTab: null,

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
    countSubcategories: false,
    autoInsertNoneItem: false,
    displayCategoryDescription: "displayCategoryDescription",
    headerComponent: "category-drop/category-drop-header",
    parentCategory: false,
  },

  modifyComponentForRow() {
    return "category-row";
  },

  displayCategoryDescription: computed(function () {
    return !(
      this.get("currentUser.staff") || this.get("currentUser.trust_level") > 0
    );
  }),

  hideParentCategory: computed(function () {
    return this.options.subCategory || false;
  }),

  categoriesWithShortcuts: computed(
    "categories.[]",
    "value",
    "selectKit.options.{subCategory,noSubcategories}",
    function () {
      const shortcuts = [];

      if (
        (this.value && !this.editingCategory) ||
        (this.selectKit.options.noSubcategories &&
          this.selectKit.options.subCategory)
      ) {
        shortcuts.push({
          id: ALL_CATEGORIES_ID,
          name: this.allCategoriesLabel,
        });
      }

      if (
        this.selectKit.options.subCategory &&
        (this.value || !this.selectKit.options.noSubcategories)
      ) {
        shortcuts.push({
          id: NO_CATEGORIES_ID,
          name: this.noCategoriesLabel,
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
      content.label = htmlSafe(
        categoryBadgeHTML(category, {
          link: false,
          allowUncategorized: true,
          hideParent: true,
        })
      );
    }

    return content;
  },

  parentCategoryName: readOnly("selectKit.options.parentCategory.name"),

  allCategoriesLabel: computed(
    "parentCategoryName",
    "selectKit.options.subCategory",
    function () {
      if (this.editingCategory) {
        return this.noCategoriesLabel;
      }
      if (this.selectKit.options.subCategory) {
        return I18n.t("categories.all_subcategories", {
          categoryName: this.parentCategoryName,
        });
      }

      return I18n.t("categories.all");
    }
  ),

  search(filter) {
    if (filter) {
      let opts = {
        parentCategoryId: this.options.parentCategory?.id,
      };
      let results = Category.search(filter, opts);
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
    onChange(categoryId) {
      const category =
        categoryId === ALL_CATEGORIES_ID || categoryId === NO_CATEGORIES_ID
          ? this.selectKit.options.parentCategory
          : Category.findById(parseInt(categoryId, 10));

      const route = this.editingCategory
        ? getEditCategoryUrl(
            category,
            categoryId !== NO_CATEGORIES_ID,
            this.editingCategoryTab
          )
        : getCategoryAndTagUrl(
            category,
            categoryId !== NO_CATEGORIES_ID,
            this.tagId
          );

      DiscourseURL.routeToUrl(route);
    },
  },

  _filterUncategorized(content) {
    if (!this.siteSettings.allow_uncategorized_topics) {
      content = content.filter(
        (c) => c.id !== this.site.uncategorized_category_id
      );
    }

    return content;
  },
});
