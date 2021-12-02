import Component from "@ember/component";
import { alias } from "@ember/object/computed";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend({
  tagName: "td",
  classNames: ["admin-report-table-cell"],
  classNameBindings: ["type", "property"],
  attributeBindings: ["value:title"],
  options: null,

  @discourseComputed("label", "data", "options")
  computedLabel(label, data, options) {
    return label.compute(data, options || {});
  },

  type: alias("label.type"),
  property: alias("label.mainProperty"),
  formatedValue: alias("computedLabel.formatedValue"),
  value: alias("computedLabel.value"),
});
