import EmberObject, { computed } from "@ember/object";
import Category from "discourse/models/category";
import I18n from "I18n";
import MultiSelectComponent from "select-kit/components/multi-select";
import { categoryBadgeHTML } from "discourse/helpers/category-link";
import { makeArray } from "discourse-common/lib/helpers";
import { mapBy } from "@ember/object/computed";

export default MultiSelectComponent.extend({
  pluginApiIdentifiers: ["category-selector"],
  classNames: ["category-selector"],
  categories: null,
  blockedCategories: null,

  selectKitOptions: {
    filterable: true,
    allowAny: false,
    allowUncategorized: "allowUncategorized",
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
  },

  content: computed("categories.[]", "blockedCategories.[]", function () {
    const blockedCategories = makeArray(this.blockedCategories);
    return Category.list().filter((category) => {
      return (
        this.categories.includes(category) ||
        !blockedCategories.includes(category)
      );
    });
  }),

  value: mapBy("categories", "id"),

  modifyComponentForRow() {
    return "category-row";
  },

  search(filter) {
    const result = this._super(filter);
    if (result.length === 1) {
      const subcategoryIds = new Set([result[0].id]);
      for (let i = 0; i < this.siteSettings.max_category_nesting; ++i) {
        subcategoryIds.forEach((categoryId) => {
          this.content.forEach((category) => {
            if (category.parent_category_id === categoryId) {
              subcategoryIds.add(category.id);
            }
          });
        });
      }

      if (subcategoryIds.size > 1) {
        result.push(
          EmberObject.create({
            multicategory: [...subcategoryIds],
            category: result[0],
            title: I18n.t("category_row.plus_subcategories_title", {
              name: result[0].name,
              count: subcategoryIds.size - 1,
            }),
            label: categoryBadgeHTML(result[0], {
              link: false,
              recursive: true,
              plusSubcategories: subcategoryIds.size - 1,
            }).htmlSafe(),
          })
        );
      }
    }

    return result;
  },

  select(value, item) {
    if (item.multicategory) {
      const items = item.multicategory.map((id) =>
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
      this.attrs.onChange(
        values.map((v) => Category.findById(v)).filter(Boolean)
      );
      return false;
    },
  },
});
