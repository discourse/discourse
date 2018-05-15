export default Ember.Component.extend({
  classNames: ["conditional-loading-section"],

  classNameBindings: ["isLoading"],

  isLoading: false
});
