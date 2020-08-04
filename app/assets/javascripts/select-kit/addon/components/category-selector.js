import { get, computed } from "@ember/object";
import { mapBy } from "@ember/object/computed";
import { makeArray } from "discourse-common/lib/helpers";
import MultiSelectComponent from "select-kit/components/multi-select";
import Category from "discourse/models/category";

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
    selectedNameComponent: "multi-select/selected-category"
  },

  init() {
    this._super(...arguments);

    if (!this.categories) this.set("categories", []);
    if (!this.blockedCategories) this.set("blockedCategories", []);
  },

  content: computed("categories.[]", "blockedCategories.[]", function() {
    const blockedCategories = makeArray(this.blockedCategories);
    return Category.list().filter(category => {
      return (
        this.categories.includes(category) ||
        !blockedCategories.includes(category)
      );
    });
  }),

  value: mapBy("categories", "id"),

  filterComputedContent(computedContent, filter) {
    const regex = new RegExp(filter, "i");
    return computedContent.filter(category =>
      this._normalize(get(category, "name")).match(regex)
    );
  },

  modifyComponentForRow() {
    return "category-row";
  },

  actions: {
    onChange(values) {
      this.attrs.onChange(
        values.map(v => Category.findById(v)).filter(Boolean)
      );
      return false;
    }
  }
});
