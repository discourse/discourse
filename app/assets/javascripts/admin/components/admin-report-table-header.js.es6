import Component from "@ember/component";
import computed from "ember-addons/ember-computed-decorators";

export default Component.extend({
  tagName: "th",
  classNames: ["admin-report-table-header"],
  classNameBindings: ["label.mainProperty", "label.type", "isCurrentSort"],
  attributeBindings: ["label.title:title"],

  @computed("currentSortLabel.sortProperty", "label.sortProperty")
  isCurrentSort(currentSortField, labelSortField) {
    return currentSortField === labelSortField;
  },

  @computed("currentSortDirection")
  sortIcon(currentSortDirection) {
    return currentSortDirection === 1 ? "caret-up" : "caret-down";
  }
});
