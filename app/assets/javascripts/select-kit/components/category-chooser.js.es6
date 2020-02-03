import ComboBoxComponent from "select-kit/components/combo-box";
import PermissionType from "discourse/models/permission-type";
import Category from "discourse/models/category";
import { categoryBadgeHTML } from "discourse/helpers/category-link";
import { computed, set } from "@ember/object";
import { isNone } from "@ember/utils";
import { setting } from "discourse/lib/computed";

export default ComboBoxComponent.extend({
  pluginApiIdentifiers: ["category-chooser"],
  classNames: ["category-chooser"],
  allowUncategorizedTopics: setting("allow_uncategorized_topics"),
  fixedCategoryPositionsOnCreate: setting("fixed_category_positions_on_create"),

  selectKitOptions: {
    filterable: true,
    allowUncategorized: false,
    allowSubCategories: true,
    permissionType: PermissionType.FULL,
    excludeCategoryId: null,
    scopedCategoryId: null
  },

  modifyComponentForRow() {
    return "category-row";
  },

  modifyNoSelection() {
    if (!isNone(this.selectKit.options.none)) {
      const none = this.selectKit.options.none;
      const isString = typeof none === "string";
      return this.defaultItem(
        null,
        I18n.t(
          isString ? this.selectKit.options.none : "category.none"
        ).htmlSafe()
      );
    } else if (
      this.allowUncategorizedTopics ||
      this.selectKit.options.allowUncategorized
    ) {
      return Category.findUncategorized();
    } else {
      return this.defaultItem(null, I18n.t("category.choose").htmlSafe());
    }
  },

  modifySelection(content) {
    if (this.selectKit.hasSelection) {
      const category = Category.findById(this.value);

      set(
        content,
        "label",
        categoryBadgeHTML(category, {
          link: false,
          hideParent: !!category.parent_category_id,
          allowUncategorized: true,
          recursive: true
        }).htmlSafe()
      );
    }

    return content;
  },

  search(filter) {
    if (filter) {
      let content = this.content;

      if (this.selectKit.options.scopedCategoryId) {
        content = this.categoriesByScope(
          this.selectKit.options.scopedCategoryId
        );
      }

      return content.filter(item => {
        const category = Category.findById(this.getValue(item));
        const categoryName = this.getName(item);

        if (category && category.parentCategory) {
          const parentCategoryName = this.getName(category.parentCategory);
          return (
            this._matchCategory(filter, categoryName) ||
            this._matchCategory(filter, parentCategoryName)
          );
        } else {
          return this._matchCategory(filter, categoryName);
        }
      });
    } else {
      return this.content;
    }
  },

  content: computed("selectKit.options.scopedCategoryId", function() {
    return this.categoriesByScope(this.selectKit.options.scopedCategoryId);
  }),

  categoriesByScope(scopedCategoryId = null) {
    const categories = this.fixedCategoryPositionsOnCreate
      ? Category.list()
      : Category.listByActivity();

    if (scopedCategoryId) {
      const scopedCat = Category.findById(scopedCategoryId);
      scopedCategoryId = scopedCat.parent_category_id || scopedCat.id;
    }

    const excludeCategoryId = this.selectKit.options.excludeCategoryId;

    return categories.filter(category => {
      const categoryId = this.getValue(category);

      if (
        scopedCategoryId &&
        categoryId !== scopedCategoryId &&
        category.parent_category_id !== scopedCategoryId
      ) {
        return false;
      }

      if (
        this.selectKit.options.allowSubCategories === false &&
        category.parentCategory
      ) {
        return false;
      }

      if (
        (this.selectKit.options.allowUncategorized === false &&
          category.isUncategorizedCategory) ||
        excludeCategoryId === categoryId
      ) {
        return false;
      }

      const permissionType = this.selectKit.options.permissionType;
      if (permissionType) {
        return permissionType === category.permission;
      }

      return true;
    });
  },

  _matchCategory(filter, categoryName) {
    return this._normalize(categoryName).indexOf(filter) > -1;
  }
});
