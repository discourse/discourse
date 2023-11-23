import { computed } from "@ember/object";
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

    if (!this.categories) {
      this.set("categories", []);
    }
    if (!this.blockedCategories) {
      this.set("blockedCategories", []);
    }

    if (this.siteSettings.lazy_load_categories) {
      if (this.categoryIds) {
        if (!Category.hasAsyncFoundAll(this.categoryIds)) {
          Category.asyncFindByIds(this.categoryIds).then(() => {
            this.notifyPropertyChange("categoryIds");
          });
        }
      } else {
        // eslint-disable-next-line no-console
        console.warn(
          "categoryIds is undefined, but lazy_load_categories is enabled"
        );
      }

      if (this.blockedCategoryIds) {
        if (!Category.hasAsyncFoundAll(this.blockedCategoryIds)) {
          Category.asyncFindByIds(this.blockedCategoryIds).then(() => {
            this.notifyPropertyChange("blockedCategoryIds");
          });
        }
      } else {
        // eslint-disable-next-line no-console
        console.warn(
          "blockedCategoryIds is undefined, but lazy_load_categories is enabled"
        );
      }
    }
  },

  content: computed(
    "categories.[]",
    "blockedCategories.[]",
    "categoryIds.[]",
    function () {
      if (this.siteSettings.lazy_load_categories) {
        return Category.findByIds(this.categoryIds);
      }

      const blockedCategories = makeArray(this.blockedCategories);
      return Category.list().filter((category) => {
        if (category.isUncategorizedCategory) {
          if (this.options?.allowUncategorized !== undefined) {
            return this.options.allowUncategorized;
          }

          return this.selectKit.options.allowUncategorized;
        }

        return (
          this.categories.includes(category) ||
          !blockedCategories.includes(category)
        );
      });
    }
  ),

  value: computed("categories.[]", "categoryIds.[]", function () {
    if (this.siteSettings.lazy_load_categories) {
      return this.categoryIds;
    }

    return this.categories.map((c) => c.id);
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
