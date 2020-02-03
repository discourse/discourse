import { get, computed } from "@ember/object";
import { mapBy } from "@ember/object/computed";
import { makeArray } from "discourse-common/lib/helpers";
import MultiSelectComponent from "select-kit/components/multi-select";
import Category from "discourse/models/category";

export default MultiSelectComponent.extend({
  pluginApiIdentifiers: ["category-selector"],
  classNames: ["category-selector"],
  categories: null,
  blacklist: null,

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
    if (!this.blacklist) this.set("blacklist", []);
  },

  content: computed("categories.[]", "blacklist.[]", function() {
    const blacklist = makeArray(this.blacklist);
    return Category.list().filter(category => {
      return (
        this.categories.includes(category) || !blacklist.includes(category)
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

  actions: {
    onChange(values) {
      this.attrs.onChange(
        values.map(v => Category.findById(v)).filter(Boolean)
      );
      return false;
    }
  }
});
