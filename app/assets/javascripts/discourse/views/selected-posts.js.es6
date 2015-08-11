export default Ember.View.extend({
  elementId: 'selected-posts',
  classNameBindings: ['customVisibility'],
  templateName: "selected-posts",

  customVisibility: function() {
    if (!this.get('controller.multiSelect')) return 'hidden';
  }.property('controller.multiSelect')
});
