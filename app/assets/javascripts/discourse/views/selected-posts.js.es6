export default Ember.View.extend({
  classNameBindings: ['controller.multiSelect::hidden', ':selected-posts'],
  templateName: "selected-posts",
});
