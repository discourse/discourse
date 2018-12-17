export default Ember.Component.extend({
  classNameBindings: [":social-link"],

  actions: {
    share: function(source) {
      this.action(source);
    }
  }
});
