import { computed, defineProperty } from "@ember/object";
import Category from "discourse/models/category";
import { makeArray } from "discourse-common/lib/helpers";
import MultiSelectComponent from "select-kit/components/multi-select";

export default MultiSelectComponent.extend({
  pluginApiIdentifiers: ["category-selector"],
  classNames: ["category-selector"],
  categories: null,
  blockedCategories: null,

  selectKitOptions: {
    filterable: true,
    allowAny: false,
    allowUncategorized: true,
    displayCategoryDescription: false,
    selectedChoiceComponent: "selected-choice-category",
  },

  init() {
    this._super(...arguments);

    if (this.categories && !this.categoryIds) {
      defineProperty(
        this,
        "categoryIds",
        computed("categories.[]", function () {
          return this.categories.map((c) => c.id);
        })
      );
    }

    if (this.blockedCategories && !this.blockedCategoryIds) {
      defineProperty(
        this,
        "blockedCategoryIds",
        computed("blockedCategories.[]", function () {
          return this.blockedCategories.map((c) => c.id);
        })
      );
    } else if (!this.blockedCategoryIds) {
      this.set("blockedCategoryIds", []);
    }

    if (this.siteSettings.lazy_load_categories) {
      const allCategoryIds = [
        ...new Set([...this.categoryIds, ...this.blockedCategoryIds]),
      ];

      if (!Category.hasAsyncFoundAll(allCategoryIds)) {
        Category.asyncFindByIds(allCategoryIds).then(() => {
          this.notifyPropertyChange("categoryIds");
          this.notifyPropertyChange("blockedCategoryIds");
        });
      }
    }
  },

  content: computed("categoryIds.[]", "blockedCategoryIds.[]", function () {
    if (this.siteSettings.lazy_load_categories) {
      return Category.findByIds(this.categoryIds);
    }

    return Category.list().filter((category) => {
      if (category.isUncategorizedCategory) {
        if (this.options?.allowUncategorized !== undefined) {
          return this.options.allowUncategorized;
        }

        return this.selectKit.options.allowUncategorized;
      }

      return (
        this.categoryIds.includes(category.id) ||
        !this.blockedCategoryIds.includes(category.id)
      );
    });
  }),

  value: computed("categoryIds.[]", function () {
    return this.categoryIds;
  }),

  modifyComponentForRow() {
    return "category-row";
  },

  async search(filter) {
    if (!this.siteSettings.lazy_load_categories) {
      return this._super(filter);
    }

    const rejectCategoryIds = new Set([
      ...(this.categoryIds || []),
      ...(this.blockedCategoryIds || []),
    ]);

    return await Category.asyncSearch(filter, {
      includeUncategorized:
        this.options?.allowUncategorized !== undefined
          ? this.options.allowUncategorized
          : this.selectKit.options.allowUncategorized,
      rejectCategoryIds: Array.from(rejectCategoryIds),
    });
  },

  select(value, item) {
    if (item.multiCategory) {
      const items = item.multiCategory.map((id) =>
        Category.findById(parseInt(id, 10))
      );

      const newValues = makeArray(this.value).concat(items.map((i) => i.id));
      const newContent = makeArray(this.selectedContent).concat(items);

      this.selectKit.change(newValues, newContent);
    } else {
      this._super(value, item);
    }
  },

  actions: {
    onChange(values) {
      this.onChange(values.map((v) => Category.findById(v)).filter(Boolean));
      return false;
    },
  },
});
