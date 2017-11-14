import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  layoutName: "select-kit/templates/components/select-kit/select-kit-header",
  classNames: ["select-kit-header", "select-box-kit-header"],
  classNameBindings: ["isFocused"],
  attributeBindings: ["dataName:data-name"],

  name: Ember.computed.alias("computedContent.name"),

  @computed("computedContent.dataName", "computedContent.name")
  dataName(dataName, name) { return dataName || name; },

  click() {
    this.sendAction("onToggle");
  }
});
