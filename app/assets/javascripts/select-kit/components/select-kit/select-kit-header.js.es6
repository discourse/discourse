export default Ember.Component.extend({
  layoutName: "select-kit/templates/components/select-kit/select-kit-header",
  classNames: ["select-kit-header", "select-box-kit-header"],
  classNameBindings: ["isFocused"],
  attributeBindings: ["name:data-name"],

  name: Ember.computed.alias("computedContent.name"),

  click() {
    this.sendAction("onToggle");
  }
});
