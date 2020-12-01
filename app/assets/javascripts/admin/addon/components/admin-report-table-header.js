import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend({
  tagName: "th",
  classNames: ["admin-report-table-header"],
  classNameBindings: ["label.mainProperty", "label.type", "isCurrentSort"],
  attributeBindings: ["label.title:title"],

  @discourseComputed("currentSortLabel.sortProperty", "label.sortProperty")
  isCurrentSort(currentSortField, labelSortField) {
    return currentSortField === labelSortField;
  },

  @discourseComputed("currentSortDirection")
  sortIcon(currentSortDirection) {
    return currentSortDirection === 1 ? "caret-up" : "caret-down";
  },
});
