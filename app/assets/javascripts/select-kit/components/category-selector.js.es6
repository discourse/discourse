import MultiSelectComponent from "select-kit/components/multi-select";
import Category from "discourse/models/category";

export default MultiSelectComponent.extend({
  pluginApiIdentifiers: ["category-selector"],
  classNames: "category-selector",
  filterable: true,
  allowAny: false,
  rowComponent: "category-row",
  categories: null,
  blacklist: null,
  allowUncategorized: true,

  init() {
    this._super(...arguments);

    if (!this.categories) this.set("categories", []);
    if (!this.blacklist) this.set("blacklist", []);

    this.headerComponentOptions.setProperties({
      selectedNameComponent: "multi-select/selected-category"
    });

    this.rowComponentOptions.setProperties({
      allowUncategorized: this.allowUncategorized,
      displayCategoryDescription: false
    });
  },

  computeValues() {
    return Ember.makeArray(this.categories).map(c => c.id);
  },

  mutateValues(values) {
    this.set("categories", values.map(v => Category.findById(v)));
  },

  filterComputedContent(computedContent, computedValues, filter) {
    const regex = new RegExp(filter, "i");
    return computedContent.filter(category =>
      this._normalize(Ember.get(category, "name")).match(regex)
    );
  },

  computeContent() {
    const blacklist = Ember.makeArray(this.blacklist);
    return Category.list().filter(category => {
      return (
        this.categories.includes(category) ||
        !blacklist.includes(category)
      );
    });
  }
});
