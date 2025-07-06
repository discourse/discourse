import { computed } from "@ember/object";
import { service } from "@ember/service";
import Category from "discourse/models/category";
import MultiSelectComponent from "select-kit/components/multi-select";
import { selectKitOptions } from "select-kit/components/select-kit";
import CategoryRow from "select-kit/components/category-row";

@selectKitOptions({
  filterable: true,
  allowUncategorized: "allowUncategorized",
  permissionType: "full",
  excludeCategoryId: null,
  scopedCategoryId: null,
  prioritizedCategoryId: null,
})
export default class MultiCategoryChooser extends MultiSelectComponent {
  @service site;

  modifyComponentForRow() {
    return CategoryRow;
  }

  @computed("selectKit.filter", "selectKit.options.scopedCategoryId", "selectKit.options.prioritizedCategoryId")
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
    const categories = this.site.categories;

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

  search(filter) {
    if (filter) {
      return this.content.filter((c) =>
        c.name.toLowerCase().includes(filter.toLowerCase())
      );
    }
    return this.content;
  }
}
