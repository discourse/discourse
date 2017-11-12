export default Ember.Component.extend({
  layoutName: "select-box-kit/templates/components/select-box-kit/select-box-kit-header",
  classNames: "select-box-kit-header",
  classNameBindings: ["isFocused"],

  name: Ember.computed.alias("computedContent.name"),

  click() { this.sendAction("onToggle"); }
});
