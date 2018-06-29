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
    this._super();

    if (!this.get("categories")) this.set("categories", []);
    if (!this.get("blacklist")) this.set("blacklist", []);

    this.get("headerComponentOptions").setProperties({
      selectedNameComponent: "multi-select/selected-category"
    });

    this.get("rowComponentOptions").setProperties({
      allowUncategorized: this.get("allowUncategorized"),
      displayCategoryDescription: false
    });
  },

  computeValues() {
    return Ember.makeArray(this.get("categories")).map(c => c.id);
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
    const blacklist = Ember.makeArray(this.get("blacklist"));
    return Category.list().filter(category => {
      return (
        this.get("categories").includes(category) ||
        !blacklist.includes(category)
      );
    });
  }
});
