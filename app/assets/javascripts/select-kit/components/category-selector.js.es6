import MultiSelectComponent from "select-kit/components/multi-select";
import Category from "discourse/models/category";

export default MultiSelectComponent.extend({
  pluginApiIdentifiers: ["category-selector"],
  classNames: "category-selector",
  filterable: true,
  allowAny: false,
  rowComponent: "category-row",

  init() {
    this._super();

    this.set("headerComponentOptions", Ember.Object.create({
      selectedNameComponent: "multi-select/selected-category"
    }));

    this.set("rowComponentOptions", Ember.Object.create({
      displayCategoryDescription: false
    }));
  },

  computeValues() {
    return Ember.makeArray(this.get("categories")).map(c => c.id);
  },

  mutateValues(values) {
    this.set("categories", values.map(v => Category.findById(v)));
  },

  filterComputedContent(computedContent, computedValues, filter) {
    const regex = new RegExp(filter.toLowerCase(), 'i');
    return computedContent.filter(category => Ember.get(category, "name").match(regex));
  },

  computeContent() {
    const blacklist = Ember.makeArray(this.get("blacklist"));
    return Category.list().filter(category => !blacklist.includes(category));
  }
});
