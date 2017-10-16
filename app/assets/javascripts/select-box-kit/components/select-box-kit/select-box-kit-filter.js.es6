import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  layoutName: "select-box-kit/templates/components/select-box-kit/select-box-kit-filter",
  classNames: "select-box-kit-filter",
  classNameBindings: ["isFocused", "isHidden"]
});
