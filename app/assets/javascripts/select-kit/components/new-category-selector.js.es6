import MultiSelectComponent from "select-kit/components/multi-select";
import Category from "discourse/models/category";

export default MultiSelectComponent.extend({
  pluginApiIdentifiers: ["new-category-selector"],
  classNames: "new-category-selector",
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
    return Ember.makeArray(this.get("categories"));
  },

  filterComputedContent(computedContent, computedValues, filter) {
    const blacklist = Ember.makeArray(this.get("blacklist"))
                           .map(b => Ember.get(b, "id"));
    const regex = new RegExp(filter.toLowerCase(), 'i');

    return computedContent.filter(category => {
      return Ember.get(category, "name").match(regex) &&
        !blacklist.includes(Ember.get(category, "value"));
    });
  },

  computeContent() {
    return Category.list();
  }
});
