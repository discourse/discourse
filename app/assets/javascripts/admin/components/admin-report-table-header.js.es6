import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  tagName: "th",
  classNames: ["admin-report-table-header"],
  classNameBindings: ["label.property", "isCurrentSort"],
  attributeBindings: ["label.title:title"],

  @computed("currentSortLabel.sort_property", "label.sort_property")
  isCurrentSort(currentSortField, labelSortField) {
    return currentSortField === labelSortField;
  },

  @computed("currentSortDirection")
  sortIcon(currentSortDirection) {
    return currentSortDirection === 1 ? "caret-up" : "caret-down";
  }
});
