import EmberObject, { computed } from "@ember/object";
import { mapBy } from "@ember/object/computed";
import { categoryBadgeHTML } from "discourse/helpers/category-link";
import Category from "discourse/models/category";
import htmlSafe from "discourse-common/helpers/html-safe";
import { makeArray } from "discourse-common/lib/helpers";
import CategoryRow from "select-kit/components/category-row";
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

    if (!this.blockedCategories) {
      this.set("blockedCategories", []);
    }
  },

  content: computed("categories.[]", "blockedCategories.[]", function () {
    return Category.list().filter((category) => {
      if (category.isUncategorizedCategory) {
        if (this.options?.allowUncategorized !== undefined) {
          return this.options.allowUncategorized;
        }

        return this.selectKit.options.allowUncategorized;
      }

      return (
        this.categories.includes(category) ||
        !this.blockedCategories.includes(category)
      );
    });
  }),

  value: mapBy("categories", "id"),

  modifyComponentForRow() {
    return CategoryRow;
  },

  async search(filter) {
    let categories;
    if (this.site.lazy_load_categories) {
      const rejectCategoryIds = new Set([
        ...this.categories.map((c) => c.id),
        ...this.blockedCategories.map((c) => c.id),
      ]);

      categories = await Category.asyncSearch(filter, {
        includeUncategorized:
          this.options?.allowUncategorized !== undefined
            ? this.options.allowUncategorized
            : this.selectKit.options.allowUncategorized,
        rejectCategoryIds: Array.from(rejectCategoryIds),
      });
    } else {
      categories = this._super(filter);
    }

    // If there is a single match and it has subcategories, add a row for
    // selecting all
    if (categories.length === 1) {
      const descendants = categories[0].descendants;
      if (descendants.length > 1) {
        categories.push(
          EmberObject.create({
            label: htmlSafe(
              categoryBadgeHTML(descendants[0], {
                link: false,
                recursive: true,
                subcategoryCount: descendants.length - 1,
              })
            ),
            categories: [...descendants],
          })
        );
      }
    }

    return categories;
  },

  select(value, item) {
    if (item.categories) {
      this.selectKit.change(
        makeArray(this.value).concat(item.categories.mapBy("id")),
        makeArray(this.selectedContent).concat(item.categories)
      );
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
