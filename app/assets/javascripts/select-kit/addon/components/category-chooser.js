import { computed, set } from "@ember/object";
import { htmlSafe } from "@ember/template";
import { isNone } from "@ember/utils";
import { classNames } from "@ember-decorators/component";
import { categoryBadgeHTML } from "discourse/helpers/category-link";
import { setting } from "discourse/lib/computed";
import Category from "discourse/models/category";
import PermissionType from "discourse/models/permission-type";
import { i18n } from "discourse-i18n";
import CategoryRow from "select-kit/components/category-row";
import ComboBoxComponent from "select-kit/components/combo-box";
import { pluginApiIdentifiers, selectKitOptions } from "./select-kit";

@classNames("category-chooser")
@selectKitOptions({
  filterable: true,
  allowUncategorized: "allowUncategorized",
  autoInsertNoneItem: false,
  allowSubCategories: true,
  permissionType: PermissionType.FULL,
  excludeCategoryId: null,
  scopedCategoryId: null,
  prioritizedCategoryId: null,
})
@pluginApiIdentifiers(["category-chooser"])
export default class CategoryChooser extends ComboBoxComponent {
  @setting("allow_uncategorized_topics") allowUncategorized;
  @setting("fixed_category_positions_on_create") fixedCategoryPositionsOnCreate;

  init() {
    super.init(...arguments);

    if (
      this.site.lazy_load_categories &&
      this.value &&
      !Category.hasAsyncFoundAll([this.value])
    ) {
      // eslint-disable-next-line no-console
      console.warn("Category selected with category-chooser was not loaded");
      Category.asyncFindByIds([this.value]).then(() => {
        this.notifyPropertyChange("value");
      });
    }
  }

  modifyComponentForRow() {
    return CategoryRow;
  }

  modifyNoSelection() {
    if (!isNone(this.selectKit.options.none)) {
      const none = this.selectKit.options.none;
      const isString = typeof none === "string";
      return this.defaultItem(
        null,
        htmlSafe(i18n(isString ? this.selectKit.options.none : "category.none"))
      );
    } else if (this.selectKit.options.allowUncategorized) {
      return Category.findUncategorized();
    } else {
      const defaultCategoryId = parseInt(
        this.siteSettings.default_composer_category,
        10
      );
      if (!defaultCategoryId || defaultCategoryId < 0) {
        return this.defaultItem(null, htmlSafe(i18n("category.choose")));
      }
    }
  }

  modifySelection(content) {
    if (this.selectKit.hasSelection) {
      const category = Category.findById(this.value);

      set(
        content,
        "label",
        htmlSafe(
          categoryBadgeHTML(category, {
            link: false,
            hideParent: category ? !!category.parent_category_id : true,
            allowUncategorized: true,
            recursive: true,
          })
        )
      );
    }

    return content;
  }

  search(filter) {
    if (this.site.lazy_load_categories) {
      return Category.asyncSearch(this._normalize(filter), {
        includeUncategorized: this.selectKit.options.allowUncategorized,
        rejectCategoryIds: [this.selectKit.options.excludeCategoryId],
        scopedCategoryId: this.selectKit.options.scopedCategoryId,
        prioritizedCategoryId: this.selectKit.options.prioritizedCategoryId,
      });
    }

    if (filter) {
      filter = this._normalize(filter);
      return this.content.filter((item) => {
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
  }

  @computed(
    "selectKit.filter",
    "selectKit.options.scopedCategoryId",
    "selectKit.options.prioritizedCategoryId"
  )
  get content() {
    if (!this.selectKit.filter) {
      let { scopedCategoryId, prioritizedCategoryId } = this.selectKit.options;

      if (scopedCategoryId) {
        return this.categoriesByScope({ scopedCategoryId });
      }

      if (prioritizedCategoryId) {
        return this.categoriesByScope({ prioritizedCategoryId });
      }
    }

    return this.categoriesByScope();
  }

  categoriesByScope({
    scopedCategoryId = null,
    prioritizedCategoryId = null,
  } = {}) {
    const categories = this.fixedCategoryPositionsOnCreate
      ? Category.list()
      : Category.listByActivity();

    if (scopedCategoryId) {
      const scopedCat = Category.findById(scopedCategoryId);
      scopedCategoryId = scopedCat.parent_category_id || scopedCat.id;
    }

    if (prioritizedCategoryId) {
      const category = Category.findById(prioritizedCategoryId);
      prioritizedCategoryId = category.parent_category_id || category.id;
    }

    const excludeCategoryId = this.selectKit.options.excludeCategoryId;

    let scopedCategories = categories.filter((category) => {
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
      if (permissionType && !this.allowRestrictedCategories) {
        return permissionType === category.permission;
      }

      return true;
    });

    if (prioritizedCategoryId) {
      let prioritized = [];
      let other = [];

      for (let category of scopedCategories) {
        const categoryId = this.getValue(category);

        if (
          categoryId === prioritizedCategoryId ||
          category.parent_category_id === prioritizedCategoryId
        ) {
          prioritized.push(category);
        } else {
          other.push(category);
        }
      }

      return prioritized.concat(other);
    } else {
      return scopedCategories;
    }
  }

  _matchCategory(filter, categoryName) {
    return this._normalize(categoryName).includes(filter);
  }

  _onChange(value) {
    this._boundaryActionHandler("onChangeCategory", Category.findById(value));
    return true;
  }
}
