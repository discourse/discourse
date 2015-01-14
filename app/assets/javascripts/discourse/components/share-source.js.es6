export default Ember.Component.extend({
  classNameBindings: [':social-link'],

  actions: {
    share: function(source) {
      this.sendAction('action', source);
    },
  }
});
