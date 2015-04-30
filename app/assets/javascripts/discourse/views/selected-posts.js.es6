export default Discourse.View.extend({
  elementId: 'selected-posts',
  topic: Ember.computed.alias('controller.model'),
  classNameBindings: ['customVisibility'],

  customVisibility: function() {
    if (!this.get('controller.multiSelect')) return 'hidden';
  }.property('controller.multiSelect')
});
