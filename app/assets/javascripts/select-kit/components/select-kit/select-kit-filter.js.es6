export default Ember.Component.extend({
  layoutName: "select-kit/templates/components/select-kit/select-kit-filter",
  classNames: ["select-kit-filter"],
  classNameBindings: ["isFocused", "isHidden"],
  isHidden: Ember.computed.not("shouldDisplayFilter")
});
