import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  tagName: "td",
  classNames: ["admin-report-table-cell"],
  classNameBindings: ["type", "property"],
  options: null,

  @computed("label", "data", "options")
  computedLabel(label, data, options) {
    return label.compute(data, options || {});
  },

  type: Ember.computed.alias("label.type"),
  property: Ember.computed.alias("label.mainProperty"),
  formatedValue: Ember.computed.alias("computedLabel.formatedValue"),
  value: Ember.computed.alias("computedLabel.value")
});
