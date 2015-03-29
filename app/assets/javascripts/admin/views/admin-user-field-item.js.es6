export default Ember.View.extend({
  classNameBindings: [':user-field'],

  _focusOnEdit: function() {
    if (this.get('controller.editing')) {
      Ember.run.scheduleOnce('afterRender', this, '_focusName');
    }
  }.observes('controller.editing').on('didInsertElement'),

  _focusName: function() {
    $('.user-field-name').select();
  }
});
